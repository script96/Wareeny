import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/object_detection/object_detection_source.dart';

void main() {
  test('uses separate bundled models for each detector mode', () {
    expect(
      UltralyticsYoloDetectionSource.homeAndroidModelPath,
      'assets/models/home/home_object_detector_int8.tflite',
    );
    expect(
      UltralyticsYoloDetectionSource.indoorNavigationAndroidModelPath,
      'assets/models/navigation/indoor/indoor_navigation_int8.tflite',
    );
    expect(
      UltralyticsYoloDetectionSource.outdoorNavigationAndroidModelPath,
      'assets/models/navigation/outdoor/outdoor_navigation_int8.tflite',
    );
    expect(
      UltralyticsYoloDetectionSource.dangerAndroidModelPath,
      'assets/models/danger/danger_model.tflite',
    );
    expect(
      UltralyticsYoloDetectionSource.dangerIosModelPath,
      'assets/models/danger/danger_model.mlpackage.zip',
    );
    expect(
      UltralyticsYoloDetectionSource.stuffFinderAndroidModelPath,
      'assets/models/stuff_finder/stuff_finder_int8.tflite',
    );

    final source = UltralyticsYoloDetectionSource();
    expect(
      source.modelPathForMode('stuff_finder', useCustomModel: true),
      UltralyticsYoloDetectionSource.stuffFinderAndroidModelPath,
    );
    expect(
      source.modelPathForMode('navigation_indoor'),
      UltralyticsYoloDetectionSource.indoorNavigationAndroidModelPath,
    );
    expect(
      source.modelPathForMode('navigation_outdoor'),
      UltralyticsYoloDetectionSource.outdoorNavigationAndroidModelPath,
    );
    expect(
      source.modelPathForMode('danger'),
      Platform.isIOS
          ? UltralyticsYoloDetectionSource.dangerIosModelPath
          : UltralyticsYoloDetectionSource.dangerAndroidModelPath,
    );
    expect(
      source.modelPathForMode('home'),
      UltralyticsYoloDetectionSource.homeAndroidModelPath,
    );
  });

  test('maps normalized YOLO detections into source-frame pixels', () async {
    final source = UltralyticsYoloDetectionSource();
    await source.start(mode: 'navigation');
    final frameFuture = source.frames.first;

    source.processStreamingData({
      'frameNumber': 12,
      'timestamp': 1767225600000,
      'imageWidth': 1280,
      'imageHeight': 720,
      'processingTimeMs': 18.4,
      'fps': 24.5,
      'detections': [
        {
          'className': 'chair',
          'confidence': 0.87,
          'normalizedBox': {
            'left': 0.25,
            'top': 0.20,
            'right': 0.75,
            'bottom': 0.80,
          },
        },
      ],
    });

    final frame = await frameFuture;
    expect(frame.frameId, 12);
    expect(frame.sourceSize.width, 1280);
    expect(frame.sourceSize.height, 720);
    expect(frame.framesPerSecond, 24.5);
    expect(frame.inferenceTime, const Duration(microseconds: 18400));
    expect(frame.detections, hasLength(1));
    expect(frame.detections.single.label, 'chair');
    expect(frame.detections.single.confidence, 0.87);
    expect(frame.detections.single.boundingBox.left, 320);
    expect(frame.detections.single.boundingBox.top, 144);
    expect(frame.detections.single.boundingBox.right, 960);
    expect(frame.detections.single.boundingBox.bottom, 576);
  });

  test('ignores startup events and malformed boxes', () async {
    final source = UltralyticsYoloDetectionSource();
    await source.start(mode: 'navigation');
    final frames = <Object>[];
    final subscription = source.frames.listen(frames.add);

    source.processStreamingData({'test': 'Streaming started'});
    source.processStreamingData({
      'imageWidth': 640,
      'imageHeight': 480,
      'detections': [
        {
          'className': 'person',
          'confidence': 0.9,
          'normalizedBox': {'left': 0.7, 'right': 0.2},
        },
      ],
    });
    await Future<void>.delayed(Duration.zero);

    expect(frames, hasLength(1));
    await subscription.cancel();
  });

  test(
    'does not drop frames when an old screen stops the shared source',
    () async {
      final source = UltralyticsYoloDetectionSource();
      await source.start(mode: 'navigation');
      await source.stop();
      final frameFuture = source.frames.first;

      source.processStreamingData({
        'imageWidth': 640,
        'imageHeight': 480,
        'detections': const [],
      });

      final frame = await frameFuture;
      expect(frame.sourceSize, const Size(640, 480));
    },
  );
}
