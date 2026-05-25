import 'package:flutter/services.dart';

import 'package:wareny/shared/bridges/native_bridge_channels.dart';

enum HapticSignal { danger, obstacle, navigationCue, confirmation }

class AudioHapticsBridge {
  const AudioHapticsBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.audioHaptics);

  final MethodChannel _channel;

  static const playHapticMethod = 'haptics.play';

  Future<void> playHaptic(HapticSignal signal) {
    return _channel.invokeMethod<void>(playHapticMethod, {
      'signal': signal.name,
    });
  }
}
