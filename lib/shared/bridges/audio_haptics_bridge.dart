import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

enum HapticSignal { danger, obstacle, navigationCue, confirmation }

class AudioHapticsBridge {
  const AudioHapticsBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.audioHaptics);

  final MethodChannel _channel;

  static const speakMethod = 'audio.speak';
  static const stopSpeechMethod = 'audio.stopSpeech';
  static const playHapticMethod = 'haptics.play';

  Future<void> speak(String text, {bool interrupt = true}) {
    return _channel.invokeMethod<void>(speakMethod, {
      'text': text,
      'interrupt': interrupt,
    });
  }

  Future<void> stopSpeech() {
    return _channel.invokeMethod<void>(stopSpeechMethod);
  }

  Future<void> playHaptic(HapticSignal signal) {
    return _channel.invokeMethod<void>(playHapticMethod, {
      'signal': signal.name,
    });
  }
}
