import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

enum HapticSignal { danger, obstacle, navigationCue, confirmation }

class AudioHapticsBridge {
  AudioHapticsBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.audioHaptics),
      _tts = FlutterTts();

  final MethodChannel _channel;
  final FlutterTts _tts;
  bool _ttsReady = false;
  String _arabicLanguage = 'ar';
  Map<String, String>? _selectedArabicVoice;
  VoidCallback? _currentCompletionHandler;

  static const playHapticMethod = 'haptics.play';

  /// Call once at app startup to eagerly configure TTS for Arabic.
  Future<void> init() async {
    if (_ttsReady) return;
    try {
      // Configure global callbacks
      _tts.setCompletionHandler(() {
        debugPrint('[TTS] Speech completed');
        final handler = _currentCompletionHandler;
        _currentCompletionHandler = null;
        handler?.call();
      });
      _tts.setCancelHandler(() {
        debugPrint('[TTS] Speech cancelled');
        _currentCompletionHandler = null;
      });
      _tts.setErrorHandler((message) {
        debugPrint('[TTS] Speech error: $message');
        final handler = _currentCompletionHandler;
        _currentCompletionHandler = null;
        handler?.call();
      });

      // Try Egyptian Arabic first, fall back to generic Arabic.
      final languages = await _tts.getLanguages;
      final available = (languages as List?)?.cast<String>() ?? <String>[];
      debugPrint('[TTS] available languages: $available');

      if (available.any((l) => l.contains('ar-EG'))) {
        _arabicLanguage = 'ar-EG';
      } else if (available.any((l) => l.startsWith('ar'))) {
        _arabicLanguage = available.firstWhere((l) => l.startsWith('ar'));
      } else {
        _arabicLanguage = 'ar';
      }

      // Query available voices to find a premium/enhanced offline ar-EG voice
      try {
        final dynamic voicesResult = await _tts.getVoices;
        if (voicesResult is List) {
          final voices = voicesResult
              .map((v) => Map<String, String>.from(v as Map))
              .toList();

          final arEgVoices = voices.where((v) => v['locale']?.contains('ar-EG') ?? false).toList();
          final arVoices = voices.where((v) => v['locale']?.startsWith('ar') ?? false).toList();

          debugPrint('[TTS] Found ${arEgVoices.length} local ar-EG voices and ${arVoices.length} total Arabic voices');

          Map<String, String>? findBestVoice(List<Map<String, String>> voiceList) {
            if (voiceList.isEmpty) return null;

            bool isPremium(String name) {
              final lower = name.toLowerCase();
              return lower.contains('premium') ||
                     lower.contains('enhanced') ||
                     lower.contains('wavenet') ||
                     lower.contains('neural') ||
                     lower.contains('google');
            }

            bool isOffline(String name) {
              final lower = name.toLowerCase();
              return lower.contains('local') || !lower.contains('network');
            }

            // Tier 1: Premium + Offline
            for (final voice in voiceList) {
              final name = voice['name'] ?? '';
              if (isPremium(name) && isOffline(name)) return voice;
            }

            // Tier 2: Offline (standard)
            for (final voice in voiceList) {
              final name = voice['name'] ?? '';
              if (isOffline(name)) return voice;
            }

            // Tier 3: Premium + Online (network)
            for (final voice in voiceList) {
              final name = voice['name'] ?? '';
              if (isPremium(name)) return voice;
            }

            // Tier 4: Fallback
            return voiceList.first;
          }

          _selectedArabicVoice = findBestVoice(arEgVoices) ?? findBestVoice(arVoices);
          if (_selectedArabicVoice != null) {
            debugPrint('[TTS] Selected high-quality local Arabic voice: ${_selectedArabicVoice!['name']} (${_selectedArabicVoice!['locale']})');
          }
        }
      } catch (voiceError) {
        debugPrint('[TTS] Failed to scan specific voices: $voiceError');
      }

      if (_selectedArabicVoice != null) {
        await _tts.setVoice(_selectedArabicVoice!);
      } else {
        await _tts.setLanguage(_arabicLanguage);
      }

      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _ttsReady = true;
      debugPrint('[TTS] Arabic TTS initialized successfully');
    } catch (error) {
      debugPrint('[TTS] initialization failed: $error');
    }
  }

  Future<void> speak(
    String text, {
    bool interrupt = true,
    String? languageCode,
    double? speechRate,
    VoidCallback? onComplete,
  }) async {
    if (!_ttsReady) await init();
    try {
      if (interrupt) {
        _currentCompletionHandler = null;
        await _tts.stop();
      }

      _currentCompletionHandler = onComplete;
      await _tts.setSpeechRate(speechRate ?? 0.45);

      if (languageCode == null || languageCode.startsWith('ar')) {
        if (_selectedArabicVoice != null) {
          await _tts.setVoice(_selectedArabicVoice!);
        } else {
          await _tts.setLanguage(_arabicLanguage);
        }
      } else {
        await _tts.setLanguage(languageCode);
      }

      final result = await _tts.speak(text);
      debugPrint('[TTS] speak result=$result text="$text"');
    } catch (error) {
      debugPrint('[TTS] speak failed: $error');
      _currentCompletionHandler = null;
    }
  }

  Future<void> stopSpeech() async {
    try {
      _currentCompletionHandler = null;
      await _tts.stop();
    } catch (error) {
      debugPrint('[TTS] stop failed: $error');
    }
  }

  Future<void> playHaptic(HapticSignal signal) async {
    try {
      await _channel.invokeMethod<void>(playHapticMethod, {
        'signal': signal.name,
      });
    } on MissingPluginException {
      await switch (signal) {
        HapticSignal.danger => HapticFeedback.heavyImpact(),
        HapticSignal.obstacle => HapticFeedback.mediumImpact(),
        HapticSignal.navigationCue => HapticFeedback.lightImpact(),
        HapticSignal.confirmation => HapticFeedback.selectionClick(),
      };
    }
  }
}
