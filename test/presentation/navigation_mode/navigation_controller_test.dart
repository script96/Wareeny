import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';
import 'package:wareeny/shared/navigation/navigation_feedback.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

void main() {
  test(
    'stabilizes danger and suppresses repeated speech during cooldown',
    () async {
      var now = DateTime(2026);
      final feedback = _FakeFeedback();
      final controller = NavigationController(
        detectionSource: _FakeDetectionSource(),
        feedback: feedback,
        clock: () => now,
      );
      final frame = _dangerFrame();

      controller.processFrame(frame);
      expect(feedback.spoken, isEmpty);

      now = now.add(const Duration(milliseconds: 300));
      controller.processFrame(frame);
      await _flushAsync();
      expect(feedback.spoken, ['وقف، في عائق قدامك']);
      expect(feedback.dangerHaptics, 1);

      now = now.add(const Duration(seconds: 1));
      controller.processFrame(frame);
      await _flushAsync();
      expect(feedback.spoken, hasLength(1));
      expect(feedback.dangerHaptics, 2);

      now = now.add(const Duration(seconds: 4));
      controller.processFrame(frame);
      await _flushAsync();
      expect(feedback.spoken, hasLength(2));
    },
  );

  test(
    'does not warn when a detection flickers away before confirmation',
    () async {
      var now = DateTime(2026);
      final feedback = _FakeFeedback();
      final controller = NavigationController(
        detectionSource: _FakeDetectionSource(),
        feedback: feedback,
        clock: () => now,
      );

      controller.processFrame(_dangerFrame());
      now = now.add(const Duration(milliseconds: 100));
      controller.processFrame(_emptyFrame());
      now = now.add(const Duration(milliseconds: 300));
      controller.processFrame(_dangerFrame());
      await _flushAsync();

      expect(feedback.spoken, isEmpty);
      expect(feedback.dangerHaptics, 0);
    },
  );
}

ObjectDetectionFrame _dangerFrame() {
  return ObjectDetectionFrame(
    frameId: 1,
    sourceSize: const Size(100, 100),
    detections: const [
      ObjectDetection(
        label: 'chair',
        confidence: 0.9,
        boundingBox: Rect.fromLTWH(44, 48, 12, 20),
      ),
    ],
    timestamp: DateTime(2026),
  );
}

ObjectDetectionFrame _emptyFrame() {
  return ObjectDetectionFrame(
    frameId: 2,
    sourceSize: const Size(100, 100),
    detections: const [],
    timestamp: DateTime(2026),
  );
}

Future<void> _flushAsync() {
  return Future<void>.delayed(Duration.zero);
}

class _FakeDetectionSource implements ObjectDetectionSource {
  final StreamController<ObjectDetectionFrame> _controller =
      StreamController<ObjectDetectionFrame>.broadcast();

  @override
  String get displayName => 'Fake detector';

  @override
  Stream<ObjectDetectionFrame> get frames => _controller.stream;

  @override
  Future<void> start({required String mode}) async {}

  @override
  Future<void> stop() async {}
}

class _FakeFeedback implements NavigationFeedback {
  final List<String> spoken = [];
  int dangerHaptics = 0;
  int cautionHaptics = 0;

  @override
  Future<void> playCautionHaptic() async {
    cautionHaptics++;
  }

  @override
  Future<void> playDangerHaptic() async {
    dangerHaptics++;
  }

  @override
  Future<void> speak(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> stopSpeech() async {}
}
