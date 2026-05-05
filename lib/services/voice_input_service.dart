// Voice Input Service — Speech-to-text singleton for QA questions.
//
// Wraps `speech_to_text` package. Responsibilities:
//   - Initialize STT once
//   - Select locale based on OCR language (Arabic → ar_EG, English → en_US)
//   - Expose listenOnce() with timeout
//   - Return typed success/failure

import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../ocr_service.dart';

enum VoiceInputFailure {
  /// User denied microphone permission.
  permissionDenied,

  /// Speech recognition service not available on device.
  unavailable,

  /// Listen timed out without any final result.
  timeout,

  /// User didn't say anything before timeout.
  noSpeech,

  /// Generic STT error.
  error,
}

/// Result from a single voice-listen attempt.
class VoiceInputResult {
  final String? text;
  final VoiceInputFailure? failure;

  const VoiceInputResult.success(this.text) : failure = null;
  const VoiceInputResult.failed(this.failure) : text = null;

  bool get isSuccess => text != null && text!.isNotEmpty;

  @override
  String toString() => isSuccess
      ? 'VoiceInputResult.success("$text")'
      : 'VoiceInputResult.failed(${failure?.name})';
}

class VoiceInputService {
  static final VoiceInputService _instance = VoiceInputService._internal();
  factory VoiceInputService() => _instance;
  VoiceInputService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  bool _isAvailable = false;
  bool _isListening = false;
  String? _lastError;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  /// Available locales cached after init.
  List<stt.LocaleName> _locales = [];

  /// Initialize speech recognition. Call once at app startup.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          print('🎤 STT error: ${error.errorMsg}');
          _isListening = false;
          _lastError = error.errorMsg;
        },
        onStatus: (status) {
          print('🎤 STT status: $status');
          if (status == 'notListening' || status == 'done') {
            _isListening = false;
          }
        },
      );

      if (_isAvailable) {
        _locales = await _speech.locales();
        print('🎤 STT initialized. ${_locales.length} locales available.');
      } else {
        print('⚠️ STT not available on this device.');
      }

      _isInitialized = true;
    } catch (e) {
      print('⚠️ STT init error: $e');
      _isAvailable = false;
      _isInitialized = true; // Don't retry — mark as tried
    }
  }

  /// Listen once for speech input. Returns recognized text or failure.
  ///
  /// Selects STT locale based on [language]:
  ///   - Arabic OCR → prefer ar_EG, fallback to any ar_*
  ///   - English OCR → prefer en_US, fallback to any en_*
  ///
  /// Listens for up to 7 seconds, then returns what was captured.
  Future<VoiceInputResult> listenOnce({
    required OCRLanguage language,
  }) async {
    if (!_isInitialized) await init();

    if (!_isAvailable) {
      return const VoiceInputResult.failed(VoiceInputFailure.unavailable);
    }

    _lastError = null;

    // If already listening, stop first
    if (_isListening) {
      await stopListening();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    final localeId = _selectLocale(language);
    print('🎤 Listening with locale: $localeId');

    final completer = Completer<VoiceInputResult>();
    String lastRecognized = '';
    bool completed = false;

    void complete(VoiceInputResult result) {
      if (!completed) {
        completed = true;
        if (!completer.isCompleted) completer.complete(result);
      }
    }

    try {
      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          lastRecognized = result.recognizedWords;
          print('🎤 Partial: "$lastRecognized" (final: ${result.finalResult})');

          if (result.finalResult) {
            _isListening = false;
            if (lastRecognized.trim().isNotEmpty) {
              complete(VoiceInputResult.success(lastRecognized.trim()));
            } else {
              complete(const VoiceInputResult.failed(VoiceInputFailure.noSpeech));
            }
          }
        },
        listenFor: const Duration(seconds: 7),
        pauseFor: const Duration(seconds: 3),
        localeId: localeId,
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: true,
        ),
      );

      // Safety timeout — if onResult never fires final
      Future.delayed(const Duration(seconds: 10), () {
        if (!completed) {
          _isListening = false;
          _speech.stop();
          if (lastRecognized.trim().isNotEmpty) {
            complete(VoiceInputResult.success(lastRecognized.trim()));
          } else {
            if (_lastError != null && _lastError!.contains('error_permission')) {
               complete(const VoiceInputResult.failed(VoiceInputFailure.permissionDenied));
            } else {
               complete(const VoiceInputResult.failed(VoiceInputFailure.timeout));
            }
          }
        }
      });

      return completer.future;
    } catch (e) {
      print('⚠️ STT listen error: $e');
      _isListening = false;
      if (e.toString().toLowerCase().contains('permission')) {
        return const VoiceInputResult.failed(VoiceInputFailure.permissionDenied);
      }
      return const VoiceInputResult.failed(VoiceInputFailure.error);
    }
  }

  /// Stop any active listening.
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    }
  }

  /// Select the best locale ID for the given OCR language.
  String? _selectLocale(OCRLanguage language) {
    if (_locales.isEmpty) return null;

    String preferredId;
    String prefix;

    if (language == OCRLanguage.arabic) {
      preferredId = 'ar_EG';
      prefix = 'ar';
    } else {
      preferredId = 'en_US';
      prefix = 'en';
    }

    // Try exact match first
    for (final locale in _locales) {
      if (locale.localeId == preferredId) {
        print('🎤 Selected exact locale match: ${locale.localeId}');
        return locale.localeId;
      }
    }

    // Fallback to any locale with matching prefix
    for (final locale in _locales) {
      if (locale.localeId.startsWith(prefix)) {
        print('🎤 Selected fallback locale match: ${locale.localeId} (preferred: $preferredId)');
        return locale.localeId;
      }
    }

    // No match — return null (uses device default)
    print('⚠️ No $prefix locale found, using device default. Preferred was $preferredId.');
    return null;
  }
}
