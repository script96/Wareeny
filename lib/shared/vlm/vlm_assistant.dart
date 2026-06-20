// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/vlm/model_router.dart';
import 'package:wareeny/shared/vlm/vlm_models.dart';
import 'package:wareeny/shared/vlm/vlm_provider.dart';

/// One streamed event from a running VLM request.
sealed class VlmEvent {
  const VlmEvent();
}

/// A token / text delta arrived. Speak it as it flows.
class VlmTokenEvent extends VlmEvent {
  const VlmTokenEvent(this.chunk);
  final VlmChunk chunk;
}

/// The request finished (or was unavailable). Carries the terminal summary.
class VlmCompleteEvent extends VlmEvent {
  const VlmCompleteEvent(this.response);
  final VlmResponse response;
}

/// The single entry point for *image + task → spoken result*. Replaces the
/// ad-hoc OCR controller logic. Screens and controllers talk to this, never to a
/// provider directly (see `RULES.MD`).
///
/// It walks the router's preferred providers for the task, streaming tokens from
/// the first that can serve the request and falling back to the next tier when a
/// provider is unavailable before producing anything. If none can serve it, the
/// terminal event is `unavailable`.
class VlmAssistant {
  const VlmAssistant({required ModelRouter router}) : _router = router;

  final ModelRouter _router;

  Stream<VlmEvent> run(VlmRequest request) async* {
    final stopwatch = Stopwatch()..start();
    final providers = _router.providersFor(request.task);

    for (final provider in providers) {
      final buffer = StringBuffer();
      Duration? firstTokenLatency;
      try {
        await for (final chunk in provider.generate(request)) {
          firstTokenLatency ??= stopwatch.elapsed;
          buffer.write(chunk.textDelta);
          yield VlmTokenEvent(chunk);
        }
        yield _complete(
          request,
          provider.source,
          buffer.toString(),
          stopwatch,
          firstTokenLatency,
        );
        return;
      } on VlmProviderUnavailable catch (e) {
        if (buffer.isNotEmpty) {
          // Stream aborted after partial output — surface what we have rather
          // than restarting on another tier mid-sentence.
          debugPrint(
            'VlmAssistant: ${provider.source.name} aborted: ${e.reason}',
          );
          yield _complete(
            request,
            provider.source,
            buffer.toString(),
            stopwatch,
            firstTokenLatency,
          );
          return;
        }
        debugPrint(
          'VlmAssistant: ${provider.source.name} unavailable '
          '(${e.reason}); trying next tier',
        );
      }
    }

    final response = VlmResponse.unavailable(latency: stopwatch.elapsed);
    _log(request, response, null);
    yield VlmCompleteEvent(response);
  }

  VlmCompleteEvent _complete(
    VlmRequest request,
    VlmSource source,
    String text,
    Stopwatch stopwatch,
    Duration? firstTokenLatency,
  ) {
    final response = VlmResponse(
      spokenText: text,
      source: source,
      latency: stopwatch.elapsed,
      firstTokenLatency: firstTokenLatency,
    );
    _log(request, response, firstTokenLatency);
    return VlmCompleteEvent(response);
  }

  void _log(VlmRequest request, VlmResponse response, Duration? firstToken) {
    debugPrint(
      'VLM ${request.task.name} → source=${response.source.name} '
      'latency=${response.latency.inMilliseconds}ms '
      'firstToken=${firstToken?.inMilliseconds ?? '-'}ms '
      'chars=${response.spokenText.length}',
    );
  }
}
