import 'dart:convert';
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

enum HapticSignal { danger, obstacle, navigationCue, confirmation }

enum TtsPriority { normal, critical }

class AudioHapticsBridge {
  AudioHapticsBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.audioHaptics),
      _player = AudioPlayer(),
      _tts = FlutterTts();

  final MethodChannel _channel;
  final AudioPlayer _player;
  final FlutterTts _tts;
  bool _ttsReady = false;
  bool _phraseAudioReady = false;
  String _arabicLanguage = 'ar';
  Map<String, String>? _selectedArabicVoice;
  Map<String, String> _phraseAssetByText = const <String, String>{};
  Map<String, String> _normalizedPhraseAssetByText = const <String, String>{};
  VoidCallback? _currentCompletionHandler;
  TtsPriority? _currentPriority;
  DateTime? _normalSpeechSuppressedUntil;
  StreamSubscription<void>? _playerCompleteSubscription;

  static const playHapticMethod = 'haptics.play';
  static const criticalSpeechSuppression = Duration(seconds: 2);
  static const phraseIndexAsset = 'assets/audio/tts/egyptian_phrase_index.json';

  /// Call once at app startup to eagerly configure TTS for Arabic.
  Future<void> init() async {
    if (_ttsReady) return;
    try {
      await _initializePhraseAudio();

      // Configure global callbacks
      _tts.setCompletionHandler(() {
        debugPrint('[TTS] Speech completed');
        _completeCurrentSpeech();
      });
      _tts.setCancelHandler(() {
        debugPrint('[TTS] Speech cancelled');
        _completeCurrentSpeech();
      });
      _tts.setErrorHandler((message) {
        debugPrint('[TTS] Speech error: $message');
        _completeCurrentSpeech();
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

          final arEgVoices = voices
              .where((v) => v['locale']?.contains('ar-EG') ?? false)
              .toList();
          final arVoices = voices
              .where((v) => v['locale']?.startsWith('ar') ?? false)
              .toList();

          debugPrint(
            '[TTS] Found ${arEgVoices.length} local ar-EG voices and ${arVoices.length} total Arabic voices',
          );

          Map<String, String>? findBestVoice(
            List<Map<String, String>> voiceList,
          ) {
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

          _selectedArabicVoice =
              findBestVoice(arEgVoices) ?? findBestVoice(arVoices);
          if (_selectedArabicVoice != null) {
            debugPrint(
              '[TTS] Selected high-quality local Arabic voice: ${_selectedArabicVoice!['name']} (${_selectedArabicVoice!['locale']})',
            );
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

  Future<void> _initializePhraseAudio() async {
    if (_phraseAudioReady) return;
    try {
      final raw = await rootBundle.loadString(phraseIndexAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final phrases =
          (decoded['phrases'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>();
      _phraseAssetByText = {
        for (final phrase in phrases)
          (phrase['text'] as String).trim(): (phrase['asset'] as String).trim(),
      };
      _normalizedPhraseAssetByText = {
        for (final entry in _phraseAssetByText.entries)
          _normalizePhraseKey(entry.key): entry.value,
      };
      await _player.setReleaseMode(ReleaseMode.stop);
      _playerCompleteSubscription ??= _player.onPlayerComplete.listen((_) {
        debugPrint('[Audio] Phrase playback completed');
        _completeCurrentSpeech();
      });
      _phraseAudioReady = true;
      debugPrint(
        '[Audio] Loaded ${_phraseAssetByText.length} Egyptian phrase assets',
      );
    } catch (error) {
      debugPrint('[Audio] Phrase asset index unavailable: $error');
      _phraseAssetByText = const <String, String>{};
      _normalizedPhraseAssetByText = const <String, String>{};
      _phraseAudioReady = true;
    }
  }

  void _resetCurrentSpeech() {
    _currentCompletionHandler = null;
    _currentPriority = null;
  }

  void _completeCurrentSpeech() {
    final handler = _currentCompletionHandler;
    _resetCurrentSpeech();
    handler?.call();
  }

  VoidCallback? _takeCurrentSpeechHandler() {
    final handler = _currentCompletionHandler;
    _resetCurrentSpeech();
    return handler;
  }

  String _normalizePhraseKey(String text) {
    const tashkeel = [
      '\u064B',
      '\u064C',
      '\u064D',
      '\u064E',
      '\u064F',
      '\u0650',
      '\u0651',
      '\u0652',
      '\u0670',
    ];
    var normalized = text.trim().toLowerCase();
    for (final mark in tashkeel) {
      normalized = normalized.replaceAll(mark, '');
    }
    normalized = normalized
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ٱ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.replaceAll(' ...', '...');
    normalized = normalized.replaceAll(' ،', '،');
    return normalized;
  }

  String? _phraseAssetFor(String text, String? languageCode) {
    final normalizedLanguage = (languageCode ?? _arabicLanguage).toLowerCase();
    if (!normalizedLanguage.startsWith('ar')) return null;
    final trimmed = text.trim();
    return _phraseAssetByText[trimmed] ??
        _normalizedPhraseAssetByText[_normalizePhraseKey(trimmed)];
  }

  Future<void> speak(
    String text, {
    bool interrupt = true,
    String? languageCode,
    double? speechRate,
    TtsPriority priority = TtsPriority.normal,
    VoidCallback? onComplete,
  }) async {
    if (!_ttsReady) await init();
    try {
      final now = DateTime.now();
      if (priority == TtsPriority.normal) {
        final suppressedUntil = _normalSpeechSuppressedUntil;
        if (_currentPriority == TtsPriority.critical ||
            (suppressedUntil != null && now.isBefore(suppressedUntil))) {
          debugPrint('[TTS] normal speech suppressed text="$text"');
          onComplete?.call();
          return;
        }
      } else {
        interrupt = true;
        _normalSpeechSuppressedUntil = now.add(criticalSpeechSuppression);
      }

      if (interrupt) {
        final interruptedHandler = _takeCurrentSpeechHandler();
        try {
          await _player.stop();
          await _tts.stop();
        } finally {
          interruptedHandler?.call();
        }
      }

      _currentCompletionHandler = onComplete;
      _currentPriority = priority;
      await _tts.setSpeechRate(speechRate ?? 0.45);

      final phraseAsset = _phraseAssetFor(text, languageCode);
      if (phraseAsset != null) {
        try {
          await _player.play(AssetSource(phraseAsset));
          debugPrint(
            '[Audio] play asset="$phraseAsset" priority=${priority.name} text="$text"',
          );
          return;
        } catch (assetError) {
          debugPrint(
            '[Audio] asset playback failed for "$phraseAsset": $assetError',
          );
        }
      }

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
      debugPrint(
        '[TTS] speak result=$result priority=${priority.name} text="$text"',
      );
    } catch (error) {
      debugPrint('[TTS] speak failed: $error');
      _currentCompletionHandler = null;
      _currentPriority = null;
      onComplete?.call();
    }
  }

  Future<void> speakAndWait(
    String text, {
    String? languageCode,
    double? speechRate,
  }) async {
    final completer = Completer<void>();
    await speak(
      text,
      languageCode: languageCode,
      speechRate: speechRate,
      onComplete: () {
        if (!completer.isCompleted) completer.complete();
      },
    );
    final timeout = Duration(seconds: (text.length / 8).ceil().clamp(2, 15));
    await completer.future.timeout(
      timeout,
      onTimeout: () {
        debugPrint('[TTS] Completion timeout for text="$text"');
      },
    );
  }

  Future<void> stopSpeech() async {
    final interruptedHandler = _takeCurrentSpeechHandler();
    try {
      await _player.stop();
      await _tts.stop();
    } catch (error) {
      debugPrint('[TTS] stop failed: $error');
    } finally {
      interruptedHandler?.call();
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
