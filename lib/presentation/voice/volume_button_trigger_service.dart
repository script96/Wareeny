import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

class VolumeButtonTriggerService {
  const VolumeButtonTriggerService([
    this._channel = const EventChannel(
      NativeBridgeChannels.volumeButtonTrigger,
    ),
  ]);

  final EventChannel _channel;

  Stream<void> get triggers {
    return _channel
        .receiveBroadcastStream()
        .map((event) {
          debugPrint('[VoiceTrigger] Native event: $event');
        })
        .handleError((Object error) {
          debugPrint('[VoiceTrigger] Hardware trigger unavailable: $error');
        });
  }
}
