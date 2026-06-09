import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';

import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';
import 'package:wareny/core/detection/target_labels.dart';

class MockObjectDetector implements ObjectDetector {
  MockObjectDetector({
    List<String>? labels,
    math.Random? random,
    this.simulatedLatency = const Duration(milliseconds: 50),
  }) : assert(labels == null || labels.isNotEmpty),
       _labels = labels ?? TargetLabels.supportedStuffFinderDetectorLabels,
       _random = random ?? math.Random();

  final List<String> _labels;
  final math.Random _random;
  final Duration simulatedLatency;

  var _isReady = false;
  var _frameIndex = 0;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  Future<DetectionFrame> detect(CameraImage image) async {
    if (!_isReady) {
      throw StateError('MockObjectDetector must be initialized before detect.');
    }

    final stopwatch = Stopwatch()..start();
    await Future<void>.delayed(simulatedLatency);

    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final detections = <DetectionResult>[];
    final primaryLabel = _labels[_frameIndex % _labels.length];
    detections.add(_randomDetection(primaryLabel, timestampMs));

    final extraCount = 1 + _random.nextInt(2);
    for (var index = 0; index < extraCount; index += 1) {
      detections.add(
        _randomDetection(_labels[_random.nextInt(_labels.length)], timestampMs),
      );
    }

    stopwatch.stop();
    _frameIndex += 1;

    return DetectionFrame(
      detections: detections,
      latencyMs: stopwatch.elapsedMilliseconds,
      frameIndex: _frameIndex,
    );
  }

  @override
  Future<void> dispose() async {
    _isReady = false;
  }

  DetectionResult _randomDetection(String label, int timestampMs) {
    final width = 0.14 + _random.nextDouble() * 0.34;
    final height = 0.12 + _random.nextDouble() * 0.36;
    final left = _random.nextDouble() * math.max(0.01, 1 - width);
    final top = _random.nextDouble() * math.max(0.01, 1 - height);

    return DetectionResult.fromNormalizedBox(
      label: label,
      confidence: 0.52 + _random.nextDouble() * 0.43,
      boundingBox: Rect.fromLTWH(left, top, width, height),
      timestampMs: timestampMs,
    );
  }
}
