import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

class LocalAiRuntimeBridge {
  const LocalAiRuntimeBridge()
    : _channel = const MethodChannel(NativeBridgeChannels.localAiRuntime),
      _stream = const EventChannel(NativeBridgeChannels.localAiRuntimeStream);

  final MethodChannel _channel;
  final EventChannel _stream;

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

  /// Streams on-device VLM token deltas for a multimodal (image + prompt)
  /// request. Listening starts generation; the stream emits text deltas and
  /// completes when generation finishes. Errors (model missing, native runtime
  /// not present) surface as stream errors so the caller can fall back.
  ///
  /// The native side (MediaPipe LLM Inference) is wired in Phase F; until then
  /// the event channel has no handler and the stream errors immediately with a
  /// `MissingPluginException`, which the local provider treats as unavailable.
  Stream<String> generateStream({
    required String modelId,
    required String prompt,
    required String imagePath,
  }) {
    return _stream
        .receiveBroadcastStream(<String, dynamic>{
          'modelId': modelId,
          'prompt': prompt,
          'imagePath': imagePath,
        })
        .map((event) => event as String);
  }
}
