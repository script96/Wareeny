import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/mock_object_detector.dart';

void main() {
  test('returns valid mock detection frames', () async {
    final detector = MockObjectDetector(
      labels: const ['cup'],
      simulatedLatency: Duration.zero,
    );

    await detector.initialize();
    final frame = await detector.detect(_FakeCameraImage());

    expect(frame.detections, isNotEmpty);
    expect(
      frame.detections.every((detection) => detection.label == 'cup'),
      true,
    );
    expect(
      frame.detections.every((detection) {
        final box = detection.boundingBox;
        return box.left >= 0 &&
            box.top >= 0 &&
            box.right <= 1 &&
            box.bottom <= 1;
      }),
      true,
    );

    await detector.dispose();
  });
}

class _FakeCameraImage implements CameraImage {
  @override
  int get height => 480;

  @override
  int get width => 640;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
