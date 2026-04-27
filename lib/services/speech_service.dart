import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final FlutterTts _tts = FlutterTts();
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.now();
  bool _isSpeaking = false;

  Future<void> init() async {
    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    
    _tts.setStartHandler(() => _isSpeaking = true);
    _tts.setCompletionHandler(() => _isSpeaking = false);
    _tts.setErrorHandler((msg) => _isSpeaking = false);
  }

  /// Speak text with optional language override.
  /// 
  /// [force] if true, interrupts current speech.
  /// [throttle] if true, won't repeat the same message within 3 seconds.
  Future<void> speak(String text, {
    String? language,
    bool force = false,
    bool throttle = true,
  }) async {
    if (throttle) {
      final now = DateTime.now();
      if (text == _lastSpoken && now.difference(_lastSpeakTime).inSeconds < 3) {
        return;
      }
    }

    if (force) {
      await _tts.stop();
    }

    if (language != null) {
      await _tts.setLanguage(language);
    } else {
      await _tts.setLanguage('ar-EG'); // Default to Egyptian Arabic
    }

    _lastSpoken = text;
    _lastSpeakTime = DateTime.now();
    await _tts.speak(text);
  }

  /// Speak and wait for completion.
  Future<void> speakAndWait(String text, {String? language}) async {
    final completer = Completer<void>();
    
    if (language != null) {
      await _tts.setLanguage(language);
    }

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      if (!completer.isCompleted) completer.complete();
    });

    await _tts.speak(text);
    
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _tts.stop();
  }
}
