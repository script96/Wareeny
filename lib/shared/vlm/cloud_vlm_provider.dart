// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'package:wareeny/shared/vlm/vlm_models.dart';
import 'package:wareeny/shared/vlm/vlm_prompts.dart';
import 'package:wareeny/shared/vlm/vlm_provider.dart';

/// Longest edge (px) we send to the model. Camera captures ~12 MP; that bloats
/// the vision prefill and dominated first-token latency. Downscaling to this is
/// still legible for signs/labels but far cheaper to encode and process.
const int _kMaxImageEdge = 1024;
const int _kJpegQuality = 80;

/// Decode → downscale → re-encode JPEG. Top-level so it can run in an isolate
/// (`compute`) and not jank the UI while the "thinking" pill is up. Returns the
/// original bytes unchanged if decoding fails or the image is already small.
Uint8List _downscaleForUpload(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final longest = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longest <= _kMaxImageEdge) {
    return img.encodeJpg(decoded, quality: _kJpegQuality);
  }
  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? _kMaxImageEdge : null,
    height: decoded.height > decoded.width ? _kMaxImageEdge : null,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(resized, quality: _kJpegQuality);
}

/// Cloud VLM tier. Talks to the self-hosted Gemma backend over HTTP with
/// Server-Sent Events so tokens arrive as they are generated.
///
/// Contract (see `backend/`):
///   POST {apiBaseUrl}/vlm/generate
///   body: { "task", "prompt", "model", "image" (base64), "question"? }
///   response: text/event-stream of `data: {"delta": "..."}` lines, ending with
///   `data: [DONE]`.
class CloudVlmProvider implements VlmProvider {
  CloudVlmProvider({
    required String Function() apiBaseUrlResolver,
    required String modelId,
    HttpClient? client,
  }) : _apiBaseUrlResolver = apiBaseUrlResolver,
       _modelId = modelId,
       _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 8);
  }

  final String Function() _apiBaseUrlResolver;
  final String _modelId;
  final HttpClient _client;

  String get _baseUrl => _apiBaseUrlResolver();

  @override
  VlmSource get source => VlmSource.cloud;

  @override
  Future<bool> isAvailable() async {
    try {
      final request = await _client
          .getUrl(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      final response = await request.close().timeout(
        const Duration(seconds: 4),
      );
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<VlmChunk> generate(VlmRequest request) async* {
    final HttpClientResponse response;
    try {
      final raw = await File(request.imagePath).readAsBytes();
      final bytes = await compute(_downscaleForUpload, raw);
      final httpRequest = await _client.postUrl(
        Uri.parse('$_baseUrl/vlm/generate'),
      );
      httpRequest.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.acceptHeader, 'text/event-stream');
      httpRequest.write(
        jsonEncode({
          'task': request.task.name,
          'model': _modelId,
          'prompt': VlmPrompts.build(request),
          'image': base64Encode(bytes),
          if (request.userQuestion != null) 'question': request.userQuestion,
        }),
      );
      response = await httpRequest.close();
    } catch (e) {
      debugPrint('CloudVlmProvider request failed: $e');
      throw VlmProviderUnavailable('cloud request failed: $e');
    }

    if (response.statusCode != 200) {
      await response.drain<void>();
      throw VlmProviderUnavailable('cloud returned ${response.statusCode}');
    }

    var first = true;
    final lines = response
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final payload = line.substring(5).trim();
      if (payload.isEmpty) continue;
      if (payload == '[DONE]') break;

      String? delta;
      try {
        final map = jsonDecode(payload) as Map<String, dynamic>;
        // Backend streams `{"error": "..."}` when the model call fails (e.g.
        // wrong model id, image rejected). Surface it so the assistant can fall
        // back / report properly instead of looking like an empty reading.
        final error = map['error'] as String?;
        if (error != null && error.isNotEmpty) {
          throw VlmProviderUnavailable('cloud model error: $error');
        }
        delta = map['delta'] as String?;
      } on VlmProviderUnavailable {
        rethrow;
      } catch (_) {
        delta = payload; // tolerate raw-text SSE payloads
      }
      if (delta == null || delta.isEmpty) continue;

      yield VlmChunk(textDelta: delta, isFirst: first);
      first = false;
    }
  }
}
