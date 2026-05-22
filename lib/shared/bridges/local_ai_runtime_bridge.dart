import 'package:flutter/services.dart';

import 'package:wareny/shared/bridges/native_bridge_channels.dart';

class LocalAiRuntimeBridge {
  const LocalAiRuntimeBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.localAiRuntime);

  final MethodChannel _channel;

  static const isModelInstalledMethod = 'localAi.isModelInstalled';
  static const warmupModelMethod = 'localAi.warmupModel';
  static const generateMethod = 'localAi.generate';
  static const unloadModelMethod = 'localAi.unloadModel';

  Future<bool> isModelInstalled(String modelId) async {
    final result = await _channel.invokeMethod<bool>(isModelInstalledMethod, {
      'modelId': modelId,
    });

    return result ?? false;
  }

  Future<void> warmupModel(String modelId) {
    return _channel.invokeMethod<void>(warmupModelMethod, {'modelId': modelId});
  }

  Future<String?> generate({required String modelId, required String prompt}) {
    return _channel.invokeMethod<String>(generateMethod, {
      'modelId': modelId,
      'prompt': prompt,
    });
  }

  Future<void> unloadModel(String modelId) {
    return _channel.invokeMethod<void>(unloadModelMethod, {'modelId': modelId});
  }
}
