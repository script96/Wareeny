import 'package:wareeny/shared/vlm/vlm_task.dart';

/// Which tier answered a request.
enum VlmSource {
  /// On-device VLM (MediaPipe / Gemma). Private, offline.
  localDevice,

  /// Hosted cloud VLM.
  cloud,

  /// No model and no network — the accepted gap. The caller tells the user to
  /// install a model or connect.
  unavailable,
}

/// Image + task → spoken result. `userQuestion` is only set for [VlmTask.askImage].
class VlmRequest {
  const VlmRequest({
    required this.imagePath,
    required this.task,
    this.userQuestion,
    this.answerInArabic = false,
  });

  final String imagePath;
  final VlmTask task;
  final String? userQuestion;

  /// True when the app is in Arabic mode — the answer should be spoken in Arabic
  /// regardless of the language of any text in the frame. Ignored for
  /// [VlmTask.read], which mirrors the document's own language.
  final bool answerInArabic;
}

/// One streamed piece of a VLM answer. Providers emit a sequence of these so
/// speech can start before generation finishes.
class VlmChunk {
  const VlmChunk({required this.textDelta, this.isFirst = false});

  /// Newly generated text since the previous chunk (token or short run).
  final String textDelta;

  /// True for the first chunk of a stream — used to stop the "thinking" cue and
  /// log first-token latency.
  final bool isFirst;
}

/// Terminal summary of a completed (or unavailable) request. Emitted/returned
/// after the stream finishes so the caller can log and react.
class VlmResponse {
  const VlmResponse({
    required this.spokenText,
    required this.source,
    required this.latency,
    this.firstTokenLatency,
  });

  /// The full assembled answer that was spoken.
  final String spokenText;

  /// Which tier produced this answer.
  final VlmSource source;

  /// Wall-clock time from request start to stream completion.
  final Duration latency;

  /// Time from request start to the first streamed chunk, when known.
  final Duration? firstTokenLatency;

  bool get isAvailable => source != VlmSource.unavailable;

  factory VlmResponse.unavailable({required Duration latency}) {
    return VlmResponse(
      spokenText: '',
      source: VlmSource.unavailable,
      latency: latency,
    );
  }
}
