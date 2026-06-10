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

  static const playHapticMethod = 'haptics.play';

  /// Call once at app startup to eagerly configure TTS for Arabic.
  Future<void> init() async {
    if (_ttsReady) return;
    try {
      // Try Egyptian Arabic first, fall back to generic Arabic.
      final languages = await _tts.getLanguages;
      final available = (languages as List?)?.cast<String>() ?? <String>[];
      debugPrint('[TTS] available languages: $available');

      if (available.any((l) => l.contains('ar-EG'))) {
        await _tts.setLanguage('ar-EG');
      } else if (available.any((l) => l.startsWith('ar'))) {
        final arabic = available.firstWhere((l) => l.startsWith('ar'));
        await _tts.setLanguage(arabic);
      } else {
        // Force ar even if not listed — the engine may still support it.
        await _tts.setLanguage('ar');
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

  Future<void> speak(String text, {bool interrupt = true}) async {
    if (!_ttsReady) await init();
    try {
      if (interrupt) await _tts.stop();
      final result = await _tts.speak(text);
      debugPrint('[TTS] speak result=$result text="$text"');
    } catch (error) {
      debugPrint('[TTS] speak failed: $error');
    }
  }

  Future<void> stopSpeech() async {
    try {
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

