import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';
import 'dart:io';

class SpeechService {
  static const List<String> _preferredAndroidEngineHints = [
    'google',
    'speech services',
    'tts',
  ];
  static const List<String> _preferredArabicVoiceHints = [
    'female',
    'woman',
    'siri',
    'enhanced',
    'premium',
    'natural',
    'network',
    'egypt',
    'egyptian',
    'ar-eg',
  ];

  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final FlutterTts _tts = FlutterTts();
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.now();
  bool _isInitialized = false;
  Future<void>? _initFuture;
  String _activeLanguage = '';

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

      await _configurePreferredEngine();
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.46);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _setBestLanguage('ar-EG');
      _isInitialized = true;
    } catch (_) {
      _isInitialized = false;
    }
  }

  /// Speak text with optional language override.
  ///
  /// [force] if true, interrupts current speech.
  /// [throttle] if true, won't repeat the same message within 3 seconds.
  Future<void> speak(
    String text, {
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
      if (!completer.isCompleted) completer.complete();
    });

    _tts.setCancelHandler(() {
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
  }

  void dispose() {
    _tts.stop();
  }

  Future<void> _configurePreferredEngine() async {
    if (!Platform.isAndroid) return;

    try {
      final dynamic engines = await _tts.getEngines;
      if (engines is! List || engines.isEmpty) return;

      String? bestEngine;
      var bestScore = -1;

      for (final engine in engines) {
        final name = engine.toString();
        final normalized = name.toLowerCase();
        var score = 0;

        if (normalized.contains('google')) score += 100;
        if (normalized.contains('speech')) score += 30;
        if (normalized.contains('services')) score += 20;
        if (normalized.contains('samsung')) score -= 20;

        if (score > bestScore) {
          bestScore = score;
          bestEngine = name;
        }
      }

      if (bestEngine != null &&
          _preferredAndroidEngineHints.any(
            (hint) => bestEngine!.toLowerCase().contains(hint),
          )) {
        await _tts.setEngine(bestEngine);
      }
    } catch (_) {
      // Engine selection is best-effort only.
    }
  }

  Future<void> _setBestLanguage(String requestedLanguage) async {
    if (_activeLanguage == requestedLanguage) return;

    final candidates = <String>{
      requestedLanguage,
      if (requestedLanguage.startsWith('ar')) 'ar-EG',
      if (requestedLanguage.startsWith('ar')) 'ar-001',
      if (requestedLanguage.startsWith('ar')) 'ar-XA',
      if (requestedLanguage.startsWith('ar')) 'ar-SA',
      if (requestedLanguage.startsWith('ar')) 'ar',
      if (requestedLanguage.startsWith('en')) 'en-US',
      'en-US',
    };

    for (final language in candidates) {
      try {
        await _tts.setLanguage(language);
        await _setPreferredVoice(language);
        _activeLanguage = language;
        return;
      } catch (_) {
        // Try the next fallback.
      }
    }
  }

  Future<void> _setPreferredVoice(String language) async {
    try {
      final dynamic voices = await _tts.getVoices;
      if (voices is! List) return;

      final targetPrefix = _normalizeLocale(language);
      Map<String, String>? bestVoice;
      int bestScore = -1;

      for (final voice in voices) {
        if (voice is! Map) continue;

        final normalizedVoice = <String, String>{};
        voice.forEach((key, value) {
          if (value != null) {
            normalizedVoice[key.toString()] = value.toString();
          }
        });
        final locale = normalizedVoice['locale']?.toString();
        if (locale == null || locale.isEmpty) continue;

        final normalizedLocale = _normalizeLocale(locale);
        if (normalizedLocale == targetPrefix) {
          final exactScore = _scoreVoice(
            voice: voice,
            normalizedVoice: normalizedVoice,
            normalizedLocale: normalizedLocale,
            targetLocale: targetPrefix,
          );
          if (exactScore > bestScore) {
            bestVoice = normalizedVoice;
            bestScore = exactScore;
          }
          continue;
        }

        if (normalizedLocale.startsWith(targetPrefix.split('-').first)) {
          final score = _scoreVoice(
            voice: voice,
            normalizedVoice: normalizedVoice,
            normalizedLocale: normalizedLocale,
            targetLocale: targetPrefix,
          );
          if (score > bestScore) {
            bestVoice = normalizedVoice;
            bestScore = score;
          }
        }
      }

      if (bestVoice != null) {
        await _tts.setVoice(bestVoice);
      }
    } catch (_) {
      // Voice lookup is best-effort only.
    }
  }

  int _scoreVoice({
    required Map voice,
    required Map<String, String> normalizedVoice,
    required String normalizedLocale,
    required String targetLocale,
  }) {
    var score = 0;

    if (normalizedLocale == targetLocale) {
      score += 100;
    } else if (normalizedLocale.startsWith(targetLocale.split('-').first)) {
      score += 60;
    }

    final descriptor = [
      normalizedVoice['name'],
      normalizedVoice['identifier'],
      normalizedVoice['gender'],
      normalizedVoice['locale'],
    ].whereType<String>().join(' ').toLowerCase();

    if (targetLocale.startsWith('ar')) {
      for (final hint in _preferredArabicVoiceHints) {
        if (descriptor.contains(hint)) {
          score += 18;
        }
      }
      if (descriptor.contains('egypt')) score += 40;
      if (descriptor.contains('eg')) score += 25;
      if (descriptor.contains('arab')) score += 25;
      if (descriptor.contains('female')) score += 35;
      if (descriptor.contains('woman')) score += 25;
      if (descriptor.contains('siri')) score += 25;
      if (descriptor.contains('compact')) score -= 10;
      if (descriptor.contains('male')) score -= 20;
    }

    if (descriptor.contains('premium') ||
        descriptor.contains('enhanced') ||
        descriptor.contains('natural')) {
      score += 20;
    }

    final quality = int.tryParse(voice['quality']?.toString() ?? '');
    if (quality != null) {
      score += quality ~/ 100;
    }

    final latency = int.tryParse(voice['latency']?.toString() ?? '');
    if (latency != null) {
      score -= latency ~/ 100;
    }

    final networkRequired =
        voice['network_required']?.toString().toLowerCase() == 'true';
    if (networkRequired) {
      score += 15;
    }

    final features = voice['features']?.toString().toLowerCase() ?? '';
    if (features.contains('network')) score += 15;
    if (features.contains('female')) score += 20;
    if (features.contains('natural')) score += 20;

    if (descriptor.contains('novelty')) {
      score -= 20;
    }

    return score;
  }

  String _normalizeLocale(String locale) {
    return locale.replaceAll('_', '-').toLowerCase();
  }
}
