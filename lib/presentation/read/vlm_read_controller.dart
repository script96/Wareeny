import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/presentation/read/speech_queue.dart';
import 'package:wareeny/shared/vlm/vlm_assistant.dart';
import 'package:wareeny/shared/vlm/vlm_models.dart';
import 'package:wareeny/shared/vlm/vlm_task.dart';

/// Drives capture → VLM → streamed speech through the shared [VlmAssistant].
/// Replaces the old ML Kit `OcrController`. Serves two screens:
///   - Scan: [scan] runs the one-shot `scan` task (no playback controls).
///   - Read: [startReading] runs the full document `read` task (stop / repeat /
///     skip / cancel controls).
/// A short "thinking" cue covers first-token latency.
class VlmReadController extends ChangeNotifier {
  VlmReadController({
    required VlmAssistant assistant,
    required AudioHapticsBridge audioHaptics,
    required String unavailableMessage,
  })  : _assistant = assistant,
        _audioHaptics = audioHaptics,
        _unavailableMessage = unavailableMessage {
    // Reading is "active" until generation finishes AND the queued audio has
    // actually been spoken — generation outruns playback, so the controls must
    // outlive the stream. The queue tells us when it has drained.
    _speech.onIdle = _onSpeechIdle;
  }

  final VlmAssistant _assistant;
  final AudioHapticsBridge _audioHaptics;
  final SpeechQueue _speech = SpeechQueue();
  final String _unavailableMessage;

  bool isThinking = false;
  bool isReadingActive = false;
  bool isUnavailable = false;
  String streamedText = '';

  StreamSubscription<VlmEvent>? _sub;
  final StringBuffer _sentenceBuffer = StringBuffer();
  // True while tokens are still streaming. Read controls stay up until this is
  // false and the speech queue is idle.
  bool _generating = false;

  /// One-shot scan: identify the thing, speak one sentence (no controls).
  Future<void> scan(String imagePath) => _start(imagePath, withControls: false);

  /// Full reading with playback controls.
  Future<void> startReading(String imagePath) =>
      _start(imagePath, withControls: true);

  Future<void> _start(String imagePath, {required bool withControls}) async {
    if (isThinking) return;
    cancel();
    isThinking = true;
    isUnavailable = false;
    streamedText = '';
    _generating = withControls;
    notifyListeners();

    // Tactile "thinking" cue while we wait for the first token. (A dedicated
    // audio earcon is a native TODO; the haptic pulse is the non-visual stand-in.)
    unawaited(_audioHaptics.playHaptic(HapticSignal.confirmation).catchError((_) {}));

    // Scan = quick identification; Read = full document read. Tuned prompts.
    final task = withControls ? VlmTask.read : VlmTask.scan;
    final request = VlmRequest(imagePath: imagePath, task: task);
    _sub = _assistant.run(request).listen(
      (event) => _onEvent(event, withControls: withControls),
      onError: (Object e) {
        debugPrint('VlmReadController stream error: $e');
        _finishUnavailable();
      },
    );
  }

  void _onEvent(VlmEvent event, {required bool withControls}) {
    switch (event) {
      case VlmTokenEvent(:final chunk):
        if (chunk.isFirst) {
          isThinking = false;
          if (withControls) isReadingActive = true;
          notifyListeners();
        }
        streamedText += chunk.textDelta;
        _sentenceBuffer.write(chunk.textDelta);
        _flushSentences();
        notifyListeners();
      case VlmCompleteEvent(:final response):
        _flushSentences(force: true);
        _generating = false;
        isThinking = false;
        if (!response.isAvailable) {
          _finishUnavailable();
        } else {
          if (response.spokenText.trim().isEmpty) {
            _speech.enqueue("I couldn't get a reading. Try again.");
          }
          // Don't drop the controls yet — the queued audio is still playing.
          // _onSpeechIdle finishes the read once it has actually been spoken.
          _maybeFinishReading();
          notifyListeners();
        }
    }
  }

  /// Fires when the speech queue drains. Mid-stream lulls between sentences fire
  /// this too, so only finish once generation is also done.
  void _onSpeechIdle() {
    if (!_generating) _maybeFinishReading();
  }

  /// Clear the active-reading state only when generation is done and all queued
  /// audio has been spoken. Keeps Stop/Repeat/Skip available for the whole read.
  void _maybeFinishReading() {
    if (_generating || _speech.isBusy || !isReadingActive) return;
    isReadingActive = false;
    notifyListeners();
  }

  /// Cut complete sentences out of the buffer and queue them for speech so audio
  /// starts mid-stream. With [force], flush whatever remains at end of stream.
  void _flushSentences({bool force = false}) {
    final text = _sentenceBuffer.toString();
    final matches = RegExp(r'[^.!?؟،\n]*[.!?؟،\n]').allMatches(text);
    var consumed = 0;
    for (final m in matches) {
      _speech.enqueue(m.group(0)!);
      consumed = m.end;
    }
    final remainder = text.substring(consumed);
    _sentenceBuffer
      ..clear()
      ..write(force ? '' : remainder);
    if (force && remainder.trim().isNotEmpty) _speech.enqueue(remainder);
  }

  void stopReading() {
    // Halt generation too — otherwise streaming tokens keep refilling the queue
    // and speech resumes after Stop.
    _sub?.cancel();
    _sub = null;
    _sentenceBuffer.clear();
    _speech.clear();
    _generating = false;
    isReadingActive = false;
    notifyListeners();
  }

  void repeatChunk() => _speech.repeatLast();

  void skipChunk() => _speech.skipCurrent();

  void cancel() {
    _sub?.cancel();
    _sub = null;
    _sentenceBuffer.clear();
    _speech.clear();
    _generating = false;
    isThinking = false;
    isReadingActive = false;
    isUnavailable = false;
    streamedText = '';
    notifyListeners();
  }

  void _finishUnavailable() {
    isThinking = false;
    isReadingActive = false;
    isUnavailable = true;
    streamedText = '';
    _speech.enqueue(_unavailableMessage);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _speech.dispose();
    super.dispose();
  }
}
