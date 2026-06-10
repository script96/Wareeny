import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';

abstract interface class NavigationFeedback {
  Future<void> speak(String message);

  Future<void> playCautionHaptic();

  Future<void> playDangerHaptic();

  Future<void> stopSpeech();
}

class BridgeNavigationFeedback implements NavigationFeedback {
  const BridgeNavigationFeedback(this._bridge);

  final AudioHapticsBridge _bridge;

  @override
  Future<void> speak(String message) {
    return _bridge.speak(message);
  }

  @override
  Future<void> playCautionHaptic() {
    return _bridge.playHaptic(HapticSignal.navigationCue);
  }

  @override
  Future<void> playDangerHaptic() {
    return _bridge.playHaptic(HapticSignal.danger);
  }

  @override
  Future<void> stopSpeech() {
    return _bridge.stopSpeech();
  }
}
