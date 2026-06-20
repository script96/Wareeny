import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

enum CameraRuntimeMode { indoor, outdoor, read, ask, scan }

class CameraBridge {
  const CameraBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.camera);

  final MethodChannel _channel;

  static const startStreamMethod = 'camera.startStream';
  static const stopStreamMethod = 'camera.stopStream';
  static const captureStillMethod = 'camera.captureStill';
  static const setModeMethod = 'camera.setMode';

  Future<void> startStream(CameraRuntimeMode mode) {
    return _channel.invokeMethod<void>(startStreamMethod, {'mode': mode.name});
  }

  Future<void> stopStream() {
    return _channel.invokeMethod<void>(stopStreamMethod);
  }

  Future<String?> captureStill() {
    return _channel.invokeMethod<String>(captureStillMethod);
  }

  Future<void> setMode(CameraRuntimeMode mode) {
    return _channel.invokeMethod<void>(setModeMethod, {'mode': mode.name});
  }
}
