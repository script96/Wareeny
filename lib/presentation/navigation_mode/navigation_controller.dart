import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:wareeny/shared/navigation/navigation_feedback.dart';
import 'package:wareeny/shared/navigation/navigation_models.dart';
import 'package:wareeny/shared/navigation/navigation_risk_engine.dart';
import 'package:wareeny/shared/camera/light_condition_service.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

typedef NavigationClock = DateTime Function();

class NavigationController extends ChangeNotifier {
  factory NavigationController({
    required ObjectDetectionSource detectionSource,
    required NavigationFeedback feedback,
    NavigationRiskEngine engine = const NavigationRiskEngine(),
    DetectionCoordinateMapper coordinateMapper =
        const DetectionCoordinateMapper(),
    NavigationClock? clock,
    bool diagnosticsEnabled = false,
    bool indoorMode = true,
  }) {
    return NavigationController._(
      detectionSource,
      feedback,
      engine,
      coordinateMapper,
      clock ?? DateTime.now,
      diagnosticsEnabled,
      indoorMode,
    );
  }

  NavigationController._(
    this._detectionSource,
    this._feedback,
    this._engine,
    this._coordinateMapper,
    this._clock,
    this.diagnosticsEnabled,
    this._indoorMode,
  );

  final ObjectDetectionSource _detectionSource;
  final NavigationFeedback _feedback;
  final NavigationRiskEngine _engine;
  final DetectionCoordinateMapper _coordinateMapper;
  final NavigationClock _clock;
  final bool diagnosticsEnabled;
  bool _indoorMode;

  static const dangerConfirmation = Duration(milliseconds: 250);
  static const cautionConfirmation = Duration(milliseconds: 500);
  static const dangerSpeechCooldown = Duration(seconds: 4);
  static const cautionSpeechCooldown = Duration(seconds: 7);
  static const dangerHapticCooldown = Duration(milliseconds: 450);
  static const cautionHapticCooldown = Duration(milliseconds: 900);
  static const pathClearSpeechCooldown = Duration(seconds: 12);

  StreamSubscription<ObjectDetectionFrame>? _subscription;
  final Map<String, DateTime> _lastSpeechAt = {};
  String? _pendingFingerprint;
  DateTime? _pendingSince;
  DateTime? _lastHapticAt;
  DateTime? _lastPathClearSpeechAt;
  DateTime? _lastFrameAt;
  ObjectDetectionFrame? _latestIndoorFrame;
  ObjectDetectionFrame? _latestCocoFrame;
  int _consecutiveClearFrames = 0;
  int framesReceived = 0;
  int framesWithDetections = 0;
  int totalDetections = 0;
  double? sceneLuminance;
  double? darkPixelRatio;
  LightCondition lightCondition = LightCondition.normal;
  Duration darkDuration = Duration.zero;
  bool flashRequested = false;
  bool torchEnabled = false;
  String activeDetectorSource = 'indoor';
  bool _started = false;

  UprightDetectionFrame? latestFrame;
  NavigationAssessment assessment = const NavigationAssessment(
    objects: [],
    selected: null,
  );
  String latestMessage = '';
  List<String> latestDetectionLabels = const [];
  String detectorStatus = 'Waiting for navigation model';
  String cooldownStatus = 'No feedback yet';

  NavigationPath get path => _engine.path;
  DateTime? get lastFrameAt => _lastFrameAt;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _subscription = _detectionSource.frames.listen(
      processFrame,
      onError: _onDetectorError,
    );

    try {
      await _detectionSource.start(mode: 'navigation');
      detectorStatus = _loadingStatus;
    } on MissingPluginException {
      detectorStatus = 'Object detector plugin is not installed';
    } on PlatformException catch (error) {
      detectorStatus = 'Detector unavailable: ${error.code}';
    } catch (error) {
      detectorStatus = 'Detector unavailable: $error';
    }
    _log('path polygon=${path.polygon}');
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
      // The temporary detector adapter is optional until native YOLO is wired.
    } on PlatformException {
      // The native runtime may already be stopped during lifecycle teardown.
    }
    await _feedback.stopSpeech();
    _resetPending();
  }

  void processFrame(ObjectDetectionFrame rawFrame) {
    framesReceived++;
    _lastFrameAt = rawFrame.timestamp;
    final filteredFrame = _filterFrameForMode(rawFrame);
    totalDetections += filteredFrame.detections.length;
    if (filteredFrame.detections.isNotEmpty) {
      framesWithDetections++;
    }
    final mergedFrame = _mergeIndoorFrames(filteredFrame);
    latestDetectionLabels = mergedFrame.detections
        .map(
          (item) =>
              '${item.label} ${(item.confidence * 100).toStringAsFixed(0)}%',
        )
        .toList(growable: false);
    final frame = _coordinateMapper.orient(mergedFrame);
    final nextAssessment = _engine.assess(frame, indoorMode: _indoorMode);
    latestFrame = frame;
    assessment = nextAssessment;
    detectorStatus = _activeStatus;

    _log(
      'frame=${rawFrame.frameId} size=${rawFrame.sourceSize} '
      'rotation=${rawFrame.rotationDegrees} mirrored=${rawFrame.mirrored} '
      'source=${rawFrame.modelSource} '
      'detections=${filteredFrame.detections.length} '
      'merged=${mergedFrame.detections.length}',
    );
    for (final item in nextAssessment.objects) {
      _log(
        'raw=${item.detection.source.label} '
        'confidence=${item.detection.source.confidence.toStringAsFixed(2)} '
        'box=${item.detection.source.boundingBox} '
        'upright=${item.detection.normalizedBox} '
        'overlap=${item.overlapRatio.toStringAsFixed(2)} '
        'inside=${item.insidePath} risk=${item.risk.name} '
        'ignored=${item.ignoreReason ?? false}',
      );
    }

    _handleCandidate(nextAssessment.selected);
    notifyListeners();
  }

  void _handleCandidate(NavigationObjectRisk? candidate) {
    if (candidate == null) {
      _resetPending();
      _consecutiveClearFrames++;
      cooldownStatus = 'No obstacle in path';
      _announcePathClear();
      return;
    }
    _consecutiveClearFrames = 0;

    final now = _clock();
    if (_pendingFingerprint != candidate.fingerprint) {
      _pendingFingerprint = candidate.fingerprint;
      _pendingSince = now;
      cooldownStatus = 'Confirming ${candidate.risk.name}';
      _log('selected=${candidate.fingerprint}; waiting for stability');
      return;
    }

    final stableFor = now.difference(_pendingSince!);
    final required = candidate.risk == NavigationRisk.danger
        ? dangerConfirmation
        : cautionConfirmation;
    if (stableFor < required) {
      cooldownStatus =
          'Confirming ${candidate.risk.name} '
          '(${stableFor.inMilliseconds}/${required.inMilliseconds} ms)';
      return;
    }

    unawaited(_triggerFeedback(candidate, now));
  }

  Future<void> _triggerFeedback(
    NavigationObjectRisk candidate,
    DateTime now,
  ) async {
    final danger = candidate.risk == NavigationRisk.danger;
    final hapticCooldown = danger
        ? dangerHapticCooldown
        : cautionHapticCooldown;
    final speechCooldown = danger
        ? dangerSpeechCooldown
        : cautionSpeechCooldown;

    if (_lastHapticAt == null ||
        now.difference(_lastHapticAt!) >= hapticCooldown) {
      _lastHapticAt = now;
      _log('haptic=${candidate.risk.name}; reason=stable path obstacle');
      try {
        if (danger) {
          await _feedback.playDangerHaptic();
        } else {
          await _feedback.playCautionHaptic();
        }
      } catch (error) {
        _log('haptic failed: $error');
      }
    } else {
      _log('haptic blocked by cooldown');
    }

    final lastSpeech = _lastSpeechAt[candidate.fingerprint];
    if (lastSpeech != null && now.difference(lastSpeech) < speechCooldown) {
      final remaining = speechCooldown - now.difference(lastSpeech);
      cooldownStatus = 'Speech cooldown ${remaining.inMilliseconds} ms';
      _log('speech blocked by cooldown for ${candidate.fingerprint}');
      return;
    }

    final message = _messageFor(candidate);
    _lastSpeechAt[candidate.fingerprint] = now;
    latestMessage = message;
    cooldownStatus = 'Spoke ${candidate.risk.name} warning';
    _log('tts="$message"; reason=${candidate.fingerprint}');
    notifyListeners();
    try {
      await _feedback.speak(message);
    } catch (error) {
      _log('speech failed: $error');
    }
  }

  void _announcePathClear() {
    // Wait for a few consecutive clear frames to confirm the path is truly clear.
    if (_consecutiveClearFrames < 10) return;
    final now = _clock();
    if (_lastPathClearSpeechAt != null &&
        now.difference(_lastPathClearSpeechAt!) < pathClearSpeechCooldown) {
      cooldownStatus = 'Path-clear speech cooldown active';
      return;
    }
    _lastPathClearSpeechAt = now;
    latestMessage = 'كمّل، الطريق فاضي';
    cooldownStatus = 'Spoke path-clear';
    _log('tts="$latestMessage"; reason=path clear');
    notifyListeners();
    unawaited(
      _feedback.speak(latestMessage).catchError((Object error) {
        _log('path-clear speech failed: $error');
      }),
    );
  }

  String _messageFor(NavigationObjectRisk candidate) {
    if (_indoorMode && candidate.isIndoorSlipHazard) {
      return 'خلي بالك، في حذاء أو شبشب على الأرض وممكن يسبب انزلاق';
    }
    if (candidate.isBottomDanger || candidate.area >= 0.18) {
      return 'وقف، في عائق قريب قدامك';
    }
    return switch (candidate.zone) {
      NavigationZone.left => 'امشي يمين',
      NavigationZone.right => 'امشي شمال',
      NavigationZone.center => 'وقف، في عائق قدامك',
    };
  }

  void _onDetectorError(Object error, StackTrace stackTrace) {
    detectorStatus = 'Detector stream error: $error';
    _log('$detectorStatus\n$stackTrace');
    notifyListeners();
  }

  void _resetPending() {
    _pendingFingerprint = null;
    _pendingSince = null;
  }

  void setIndoorMode(bool enabled) {
    if (_indoorMode == enabled) return;
    _indoorMode = enabled;
    latestFrame = null;
    assessment = const NavigationAssessment(objects: [], selected: null);
    latestDetectionLabels = const [];
    framesReceived = 0;
    framesWithDetections = 0;
    totalDetections = 0;
    _lastFrameAt = null;
    _latestIndoorFrame = null;
    _latestCocoFrame = null;
    activeDetectorSource = enabled ? 'indoor' : 'coco';
    detectorStatus = _loadingStatus;
    _resetPending();
    notifyListeners();
  }

  void reportModelError(Object error) {
    detectorStatus = 'Navigation model unavailable: $error';
    notifyListeners();
  }

  void reportLighting({
    required LightConditionResult result,
    required bool torchOn,
  }) {
    sceneLuminance = result.averageBrightness;
    darkPixelRatio = result.darkPixelRatio;
    lightCondition = result.condition;
    darkDuration = result.darkDuration;
    flashRequested = result.flashRequested;
    torchEnabled = torchOn;
    notifyListeners();
  }

  void announceLowLight({required bool flashEnabled}) {
    latestMessage = flashEnabled
        ? 'الإضاءة ضعيفة، هفتح الفلاش عشان الكشف يكون أوضح'
        : 'الإضاءة ضعيفة، افتح الفلاش عشان أقدر أشوف الطريق';
    cooldownStatus = flashEnabled
        ? 'Auto-flash enabled'
        : 'Torch unavailable; asked user to enable it';
    _log('tts="$latestMessage"; flashEnabled=$flashEnabled');
    notifyListeners();
    unawaited(
      _feedback.speak(latestMessage).catchError((Object error) {
        _log('low-light speech failed: $error');
      }),
    );
  }

  void reportActiveDetectorSource(String source) {
    if (activeDetectorSource == source) return;
    activeDetectorSource = source;
    notifyListeners();
  }

  String get _loadingStatus => _indoorMode
      ? 'Loading indoor navigation model'
      : 'Loading outdoor navigation model';

  String get _activeStatus => _indoorMode
      ? 'Indoor navigation model active'
      : 'Outdoor navigation model active';

  ObjectDetectionFrame _mergeIndoorFrames(ObjectDetectionFrame incoming) {
    if (!_indoorMode) return incoming;
    if (incoming.modelSource == 'indoor') {
      _latestIndoorFrame = incoming;
    } else if (incoming.modelSource == 'coco') {
      _latestCocoFrame = incoming;
    }

    final now = incoming.timestamp;
    final recent = <ObjectDetectionFrame>[
      if (_isRecent(_latestIndoorFrame, now)) _latestIndoorFrame!,
      if (_isRecent(_latestCocoFrame, now)) _latestCocoFrame!,
    ];
    if (recent.isEmpty) return incoming;

    return ObjectDetectionFrame(
      frameId: incoming.frameId,
      sourceSize: incoming.sourceSize,
      detections: recent
          .expand((frame) => frame.detections)
          .toList(growable: false),
      timestamp: incoming.timestamp,
      rotationDegrees: incoming.rotationDegrees,
      mirrored: incoming.mirrored,
      inferenceTime: incoming.inferenceTime,
      framesPerSecond: incoming.framesPerSecond,
      isLowLight: incoming.isLowLight,
      modelSource: 'indoor+coco',
    );
  }

  ObjectDetectionFrame _filterFrameForMode(ObjectDetectionFrame frame) {
    if (!_isCocoFrame(frame.modelSource)) return frame;

    final filtered = frame.detections
        .where((detection) {
          return !isIgnoredCocoLabel(detection.label, indoorMode: _indoorMode);
        })
        .toList(growable: false);

    if (filtered.length == frame.detections.length) return frame;
    return ObjectDetectionFrame(
      frameId: frame.frameId,
      sourceSize: frame.sourceSize,
      detections: filtered,
      timestamp: frame.timestamp,
      rotationDegrees: frame.rotationDegrees,
      mirrored: frame.mirrored,
      inferenceTime: frame.inferenceTime,
      framesPerSecond: frame.framesPerSecond,
      isLowLight: frame.isLowLight,
      modelSource: frame.modelSource,
    );
  }

  bool _isCocoFrame(String modelSource) {
    return modelSource == 'coco' || modelSource == 'indoor+coco';
  }

  bool _isRecent(ObjectDetectionFrame? frame, DateTime now) {
    return frame != null &&
        now.difference(frame.timestamp).abs() <= const Duration(seconds: 4);
  }

  void _log(String message) {
    if (diagnosticsEnabled) {
      debugPrint('[Navigation] $message');
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
