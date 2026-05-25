import 'package:camera/camera.dart';

import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/object_detector.dart';
import 'package:wareny/shared/bridges/local_ai_runtime_bridge.dart';

class YoloObjectDetector implements ObjectDetector {
  YoloObjectDetector({required LocalAiRuntimeBridge localAiRuntimeBridge})
    : _localAiRuntimeBridge = localAiRuntimeBridge;

  final LocalAiRuntimeBridge _localAiRuntimeBridge;

  @override
  bool get isReady => false;

  @override
  Future<void> initialize() async {
    throw UnimplementedError(
      'Native YOLO/LiteRT integration is not wired yet. '
      'Use MockObjectDetector until a .tflite adapter is available.',
    );
  }

  @override
  Future<DetectionFrame> detect(CameraImage image) async {
    throw UnimplementedError(
      'YOLO detection must be implemented by the native LiteRT adapter.',
    );
  }

  @override
  Future<void> dispose() async {
    await _localAiRuntimeBridge.unloadModel('yolo-object-detector');
  }
}
