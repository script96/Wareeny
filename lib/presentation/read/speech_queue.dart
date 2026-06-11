import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks queued text sequentially so streamed VLM tokens can be spoken as they
/// arrive without utterances overlapping. Feed it sentences as they form; it
/// drains them one at a time. Auto-detects Arabic vs English per item.
///
/// Shared by the scan and reading controllers, and reusable by the other VLM
/// tasks (ask-image, scene describe) later.
class SpeechQueue {
  SpeechQueue() {
    _tts.awaitSpeakCompletion(true);
    _configure();
  }

  final FlutterTts _tts = FlutterTts();
  final List<String> _pending = [];
  bool _draining = false;
  String? _last;

  /// Called when the queue finishes draining with nothing left pending — i.e.
  /// everything queued so far has been spoken. May fire repeatedly (once per
  /// lull); the caller decides whether the work is truly done. Mid-stream lulls
  /// between sentences will fire this, so guard accordingly.
  VoidCallback? onIdle;

  Future<void> _configure() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  /// Whether anything is currently queued or being spoken.
  bool get isBusy => _draining || _pending.isNotEmpty;

  /// Queue [text] to be spoken after anything already queued.
  void enqueue(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _pending.add(trimmed);
    _last = trimmed;
    _drain();
  }

  Future<void> _drain() async {
    if (_draining) return;
    _draining = true;
    while (_pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      await _tts.setLanguage(_isArabic(next) ? 'ar-SA' : 'en-US');
      await _tts.speak(next);
    }
    _draining = false;
    onIdle?.call();
  }

  /// Re-speak the most recent utterance.
  void repeatLast() {
    final last = _last;
    if (last != null) enqueue(last);
  }

  /// Cut the current utterance; the queue keeps draining with the next item.
  Future<void> skipCurrent() => _tts.stop();

  /// Stop speaking and drop everything queued.
  Future<void> clear() async {
    _pending.clear();
    _draining = false;
    await _tts.stop();
  }

  Future<void> dispose() async {
    _pending.clear();
    await _tts.stop();
  }

  bool _isArabic(String text) {
    final arabic =
        text.codeUnits.where((c) => c >= 0x0600 && c <= 0x06FF).length;
    return arabic > text.length * 0.3;
  }
}
