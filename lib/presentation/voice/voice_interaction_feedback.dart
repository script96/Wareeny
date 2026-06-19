import 'dart:async';

import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';

abstract interface class VoiceInteractionFeedback {
  Future<void> stopSpeech();

  Future<void> speakAndWait(String message);

  Future<void> playListeningStartedHaptic();

  Future<void> playListeningStoppedHaptic();
}

class BridgeVoiceInteractionFeedback implements VoiceInteractionFeedback {
  BridgeVoiceInteractionFeedback(this._bridge, this._speechRate);

  final AudioHapticsBridge _bridge;
  final double Function() _speechRate;

  @override
  Future<void> stopSpeech() => _bridge.stopSpeech();

  @override
  Future<void> speakAndWait(String message) {
    return _bridge.speakAndWait(
      message,
      languageCode: 'ar-EG',
      speechRate: _speechRate(),
    );
  }

  @override
  Future<void> playListeningStartedHaptic() {
    // Audible "ding" the instant listening begins, so the user knows to speak
    // even without a screen. Fire-and-forget; the haptic still plays in sync.
    unawaited(SystemSound.play(SystemSoundType.alert));
    return _bridge.playHaptic(HapticSignal.obstacle);
  }

  @override
  Future<void> playListeningStoppedHaptic() {
    return _bridge.playHaptic(HapticSignal.confirmation);
  }
}
