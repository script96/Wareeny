import 'package:camera/camera.dart';

import 'package:wareny/core/detection/detection_frame.dart';

abstract class ObjectDetector {
  Future<void> initialize();

  Future<DetectionFrame> detect(CameraImage image, {int rotationDegrees = 0});

  Future<void> dispose();

  bool get isReady;
}
