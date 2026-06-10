import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

class StuffFinderController extends ChangeNotifier {
  factory StuffFinderController({
    required ObjectDetectionSource detectionSource,
    DetectionCoordinateMapper coordinateMapper =
        const DetectionCoordinateMapper(),
  }) {
    return StuffFinderController._(detectionSource, coordinateMapper);
  }

  StuffFinderController._(this._detectionSource, this._coordinateMapper);

  final ObjectDetectionSource _detectionSource;
  final DetectionCoordinateMapper _coordinateMapper;

  StreamSubscription<ObjectDetectionFrame>? _subscription;
  bool _started = false;

  String? selectedTarget;
  UprightDetectionFrame? latestFrame;
  String status = 'Choose an object to start searching';

  int get matchCount => latestFrame?.detections.length ?? 0;

  Future<void> selectTarget(String target) async {
    final normalizedTarget = target.trim().toLowerCase();
    if (!cocoClasses.contains(normalizedTarget)) {
      throw ArgumentError.value(target, 'target', 'Not a COCO class');
    }

    final changed = selectedTarget != normalizedTarget;
    selectedTarget = normalizedTarget;
    if (changed) latestFrame = null;
    status = 'Starting ${_detectionSource.displayName}';
    notifyListeners();
    await start();
  }

  Future<void> start() async {
    if (_started || selectedTarget == null) return;
    _started = true;
    _subscription = _detectionSource.frames.listen(
      processFrame,
      onError: _onDetectorError,
    );

    try {
      await _detectionSource.start(mode: 'stuff_finder');
      status = 'Searching for $selectedTarget';
    } on MissingPluginException {
      status = 'Object detector plugin is not installed';
    } on PlatformException catch (error) {
      status = 'Detector unavailable: ${error.code}';
    } catch (error) {
      status = 'Detector unavailable: $error';
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _detectionSource.stop();
    } on MissingPluginException {
      // The platform view may already be detached during teardown.
    } on PlatformException {
      // The native detector may already be stopped during lifecycle teardown.
    }
  }

  void processFrame(ObjectDetectionFrame rawFrame) {
    final target = selectedTarget;
    if (target == null) return;

    final uprightFrame = _coordinateMapper.orient(rawFrame);
    final matches = uprightFrame.detections
        .where(
          (detection) => detection.source.label.trim().toLowerCase() == target,
        )
        .toList(growable: false);

    latestFrame = UprightDetectionFrame(
      source: rawFrame,
      imageSize: uprightFrame.imageSize,
      detections: matches,
    );
    status = matches.isEmpty
        ? 'Searching for $target'
        : '${matches.length} ${matches.length == 1 ? "match" : "matches"} found';
    notifyListeners();
  }

  void _onDetectorError(Object error, StackTrace stackTrace) {
    status = 'Detector stream error: $error';
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
