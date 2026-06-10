import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

abstract interface class StuffFinderFeedback {
  Future<void> speak(String message);

  Future<void> stopSpeech();
}

class BridgeStuffFinderFeedback implements StuffFinderFeedback {
  const BridgeStuffFinderFeedback(this._bridge);

  final AudioHapticsBridge _bridge;

  @override
  Future<void> speak(String message) {
    return _bridge.speak(message, languageCode: 'en-US');
  }

  @override
  Future<void> stopSpeech() {
    return _bridge.stopSpeech();
  }
}

class SilentStuffFinderFeedback implements StuffFinderFeedback {
  const SilentStuffFinderFeedback();

  @override
  Future<void> speak(String message) async {}

  @override
  Future<void> stopSpeech() async {}
}

class StuffFinderController extends ChangeNotifier {
  factory StuffFinderController({
    required ObjectDetectionSource detectionSource,
    StuffFinderFeedback feedback = const SilentStuffFinderFeedback(),
    DetectionCoordinateMapper coordinateMapper =
        const DetectionCoordinateMapper(),
  }) {
    return StuffFinderController._(detectionSource, feedback, coordinateMapper);
  }

  StuffFinderController._(
    this._detectionSource,
    this._feedback,
    this._coordinateMapper,
  );

  final ObjectDetectionSource _detectionSource;
  final StuffFinderFeedback _feedback;
  final DetectionCoordinateMapper _coordinateMapper;

  static const matchSpeechCooldown = Duration(seconds: 4);

  StreamSubscription<ObjectDetectionFrame>? _subscription;
  bool _started = false;
  bool _hadMatch = false;
  DateTime? _lastMatchSpeechAt;

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
    if (changed) {
      latestFrame = null;
      _hadMatch = false;
      _lastMatchSpeechAt = null;
    }
    status = 'Starting ${_detectionSource.displayName}';
    notifyListeners();
    unawaited(_feedback.speak('Searching for $normalizedTarget'));
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
    await _feedback.stopSpeech();
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
    _handleMatchSpeech(target, matches.length);
    notifyListeners();
  }

  void _handleMatchSpeech(String target, int count) {
    if (count == 0) {
      _hadMatch = false;
      return;
    }

    final now = DateTime.now();
    final cooldownActive =
        _lastMatchSpeechAt != null &&
        now.difference(_lastMatchSpeechAt!) < matchSpeechCooldown;
    if (_hadMatch && cooldownActive) return;

    _hadMatch = true;
    _lastMatchSpeechAt = now;
    final message = count == 1
        ? 'Found $target'
        : 'Found $count $target matches';
    unawaited(_feedback.speak(message));
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
