import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final FlutterTts _tts = FlutterTts();
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.now();
  bool _isSpeaking = false;
  bool _isInitialized = false;
  Future<void>? _initFuture;
  String _activeLanguage = 'ar-EG';

  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _initInternal();
    try {
      await _initFuture;
    } finally {
      _initFuture = null;
    }
  }

  Future<void> _initInternal() async {
    try {
      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _setBestLanguage('ar-EG');

      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setCancelHandler(() => _isSpeaking = false);
      _tts.setErrorHandler((msg) => _isSpeaking = false);
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
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
    await init();
    if (!_isInitialized) return;

    if (throttle) {
      final now = DateTime.now();
      if (text == _lastSpoken && now.difference(_lastSpeakTime).inSeconds < 3) {
        return;
      }
    }

    if (force) {
      await _tts.stop();
    }

    await _setBestLanguage(language ?? 'ar-EG');

    _lastSpoken = text;
    _lastSpeakTime = DateTime.now();
    await _tts.speak(text);
  }

  /// Speak and wait for completion.
  Future<void> speakAndWait(String text, {String? language}) async {
    await init();
    if (!_isInitialized) return;

    final completer = Completer<void>();
    await _setBestLanguage(language ?? 'ar-EG');

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
    if (!_isInitialized) return;
    await _tts.stop();
    _isSpeaking = false;
  }

  void dispose() {
    _tts.stop();
  }

  Future<void> _setBestLanguage(String requestedLanguage) async {
    if (_activeLanguage == requestedLanguage) return;

    final candidates = <String>[
      requestedLanguage,
      if (requestedLanguage.startsWith('ar')) 'ar-SA',
      if (requestedLanguage.startsWith('ar')) 'ar-EG',
      if (requestedLanguage.startsWith('en')) 'en-US',
      'en-US',
    ].toSet();

    for (final language in candidates) {
      try {
        await _tts.setLanguage(language);
        _activeLanguage = language;
        return;
      } catch (_) {
        // Try the next fallback.
      }
    }
  }
}
