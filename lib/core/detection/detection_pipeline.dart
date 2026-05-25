import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import 'package:wareny/core/detection/detection_config.dart';
import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';

typedef DetectionClock = DateTime Function();

class DetectionPipeline extends ChangeNotifier {
  DetectionPipeline({
    required ObjectDetector detector,
    DetectionConfig config = const DetectionConfig(),
    bool enableDiagnostics = false,
    DetectionClock? clock,
  }) : _detector = detector,
       _config = config,
       _enableDiagnostics = enableDiagnostics,
       _clock = clock ?? DateTime.now;

  final ObjectDetector _detector;
  final DetectionConfig _config;
  final bool _enableDiagnostics;
  final DetectionClock _clock;
  final _targetController = StreamController<DetectionResult>.broadcast();

  DetectionResult? _currentTarget;
  DetectionFrame? _lastFrame;
  String? _targetLabel;
  String? _lastAnnouncementKey;
  DateTime? _lastAnnouncementAt;
  var _frameCounter = 0;
  var _isRunning = false;
  var _isProcessing = false;
  var _isDisposed = false;

  DetectionConfig get config => _config;
  DetectionResult? get currentTarget => _currentTarget;
  DetectionFrame? get lastFrame => _lastFrame;
  String? get targetLabel => _targetLabel;
  bool get isRunning => _isRunning;
  bool get isReady => _detector.isReady;
  Stream<DetectionResult> get targetResults => _targetController.stream;

  Future<void> initialize() async {
    if (_detector.isReady) {
      return;
    }
    await _detector.initialize();
    _notify();
  }

  void start() {
    if (_isRunning) {
      return;
    }
    _isRunning = true;
    _notify();
  }

  void stop() {
    if (!_isRunning && _currentTarget == null) {
      return;
    }
    _isRunning = false;
    _isProcessing = false;
    _currentTarget = null;
    _notify();
  }

  void setTargetLabel(String? label) {
    final nextLabel = label?.trim();
    if (nextLabel == null || nextLabel.isEmpty) {
      _targetLabel = null;
    } else {
      _targetLabel = nextLabel;
    }
    _currentTarget = null;
    _lastAnnouncementKey = null;
    _lastAnnouncementAt = null;
    _notify();
  }

  Future<void> processFrame(CameraImage image) async {
    if (!_isRunning || !_detector.isReady || _targetLabel == null) {
      return;
    }

    _frameCounter += 1;
    if (_frameCounter % _config.frameSampleInterval != 0 || _isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      final frame = await _detector.detect(image);
      if (!_isRunning) {
        return;
      }

      _lastFrame = frame;
      final best = _bestTargetFrom(frame);
      _currentTarget = best;
      _notify();

      if (best != null && _canEmit(best)) {
        _targetController.add(best);
      }

      if (_enableDiagnostics) {
        debugPrint(
          'Detection frame ${frame.frameIndex}: '
          '${frame.latencyMs}ms, ${frame.detections.length} detections',
        );
      }
    } catch (error, stackTrace) {
      if (_enableDiagnostics) {
        debugPrint('Detection failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _isProcessing = false;
    }
  }

  DetectionResult? _bestTargetFrom(DetectionFrame frame) {
    final label = _targetLabel;
    if (label == null) {
      return null;
    }

    final normalizedLabel = label.toLowerCase();
    final candidates = frame.detections.where((detection) {
      return detection.label.toLowerCase() == normalizedLabel &&
          detection.confidence >= _config.confidenceThreshold;
    }).toList();

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.first;
  }

  bool _canEmit(DetectionResult result) {
    final key = '${result.label}:${result.direction.name}';
    final now = _clock();
    final lastAt = _lastAnnouncementAt;

    if (_lastAnnouncementKey == key &&
        lastAt != null &&
        now.difference(lastAt) < _config.cooldownDuration) {
      return false;
    }

    _lastAnnouncementKey = key;
    _lastAnnouncementAt = now;
    return true;
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _isRunning = false;
    unawaited(_targetController.close().then<void>((_) {}));
    unawaited(_detector.dispose());
    super.dispose();
  }
}
