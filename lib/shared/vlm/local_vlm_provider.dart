import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/bridges/local_ai_runtime_bridge.dart';
import 'package:wareeny/shared/vlm/vlm_models.dart';
import 'package:wareeny/shared/vlm/vlm_prompts.dart';
import 'package:wareeny/shared/vlm/vlm_provider.dart';

/// On-device VLM tier (MediaPipe LLM Inference / Gemma). Private and
/// offline-capable. This is the main path for reading and the capture-and-
/// identify tasks once a local model is installed.
///
/// The native runtime is wired in Phase F. Until a model is installed and the
/// native handler exists, [isAvailable] returns false and [generate] throws
/// [VlmProviderUnavailable] — the router then falls back to cloud.
class LocalVlmProvider implements VlmProvider {
  const LocalVlmProvider({
    required LocalAiRuntimeBridge runtime,
    required String modelId,
  })  : _runtime = runtime,
        _modelId = modelId;

  final LocalAiRuntimeBridge _runtime;
  final String _modelId;

  @override
  VlmSource get source => VlmSource.localDevice;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _runtime.isModelInstalled(_modelId);
    } catch (_) {
      // Native runtime not present yet (no handler) → treat as unavailable.
      return false;
    }
  }

  @override
  Stream<VlmChunk> generate(VlmRequest request) async* {
    if (!await isAvailable()) {
      throw const VlmProviderUnavailable('on-device model not installed');
    }

    final prompt = VlmPrompts.build(request);
    var first = true;
    try {
      await for (final delta in _runtime.generateStream(
        modelId: _modelId,
        prompt: prompt,
        imagePath: request.imagePath,
      )) {
        if (delta.isEmpty) continue;
        yield VlmChunk(textDelta: delta, isFirst: first);
        first = false;
      }
    } catch (e) {
      debugPrint('LocalVlmProvider stream failed: $e');
      throw VlmProviderUnavailable('on-device generation failed: $e');
    }
  }
}
