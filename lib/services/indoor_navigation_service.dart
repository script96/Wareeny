import 'dart:async';
import 'dart:io';

import '../detector.dart';
import 'camera_service.dart';
import 'depth_provider.dart';
import 'haptic_cue_service.dart';
import 'indoor_navigation_logic.dart';
import 'indoor_navigation_types.dart';
import 'speech_service.dart';

class IndoorNavigationUpdate {
  final IndoorNavigationDecision decision;
  final int imageWidth;
  final int imageHeight;

  const IndoorNavigationUpdate({
    required this.decision,
    required this.imageWidth,
    required this.imageHeight,
  });
}

class IndoorNavigationService {
  final YoloDetector detector;
  final CameraService camera;
  final SpeechService speech;
  final HapticCueService haptics;

  IndoorNavigationService({
    required this.detector,
    required this.camera,
    required this.speech,
    HapticCueService? haptics,
  }) : haptics = haptics ?? HapticCueService();

  final List<DepthProvider> _providers = [];
  DepthProvider? _activeDepthProvider;
  Timer? _timer;
  bool _isRunning = false;
  bool _isProcessing = false;
  Completer<void>? _activeProcessingCompleter;
  DetectionResult? _lastDetections;
  int _frameCounter = 0;
  int _calmFrames = 0;
  IndoorNavigationDecision? _lastDecision;
  DateTime _lastSpokenAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSafePromptAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isRunning => _isRunning;

  Future<void> init() async {
    if (_providers.isNotEmpty) return;

    if (Platform.isAndroid) {
      _providers.add(ArcoreDepthProvider());
    } else if (Platform.isIOS) {
      _providers.add(ArkitDepthProvider());
    }
    _providers.add(MonocularDepthProvider());

    for (final provider in _providers) {
      final isReady = await provider.initialize();
      if (isReady) {
        _activeDepthProvider = provider;
        break;
      }
    }

    _activeDepthProvider ??= _providers.last;
  }

  Future<void> start({
    required Future<void> Function(IndoorNavigationUpdate update) onUpdate,
  }) async {
    await init();
    await camera.startAnalysisStream();

    _timer?.cancel();
    _isRunning = true;
    _lastDecision = null;
    _lastDetections = null;
    _frameCounter = 0;
    _calmFrames = 0;

    _timer = Timer.periodic(const Duration(milliseconds: 160), (_) async {
      await _tick(onUpdate);
    });
  }

  Future<void> _tick(
    Future<void> Function(IndoorNavigationUpdate update) onUpdate,
  ) async {
    if (!_isRunning || _isProcessing) return;
    _isProcessing = true;
    final completer = Completer<void>();
    _activeProcessingCompleter = completer;

    try {
      final bytes =
          camera.latestAnalysisBytes ?? await camera.takeAnalysisBytes();
      if (bytes == null) return;

      final depthProvider = _activeDepthProvider;
      if (depthProvider == null) return;

      final depthFrame = await depthProvider.estimate(bytes);
      if (depthFrame == null) return;

      DetectionResult? detections = _lastDetections;
      if (_lastDetections == null || _frameCounter.isEven) {
        detections = await detector.detectFromBytes(bytes);
        if (detections != null) {
          _lastDetections = detections;
        }
      }
      _frameCounter++;

      final imageWidth = detections?.imageWidth ?? 1;
      final imageHeight = detections?.imageHeight ?? 1;
      final decision = IndoorNavigationLogic.evaluate(
        detections: detections?.detections ?? const [],
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        depthFrame: depthFrame,
      );
      final stableDecision = _applyHysteresis(decision);

      await haptics.emit(stableDecision.dangerLevel);
      await _speakIfNeeded(stableDecision);
      _lastDecision = stableDecision;

      await onUpdate(
        IndoorNavigationUpdate(
          decision: stableDecision,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        ),
      );
    } catch (e) {
      print('⚠️ Indoor navigation tick error: $e');
    } finally {
      _isProcessing = false;
      completer.complete();
      if (_activeProcessingCompleter == completer) {
        _activeProcessingCompleter = null;
      }
    }
  }

  IndoorNavigationDecision _applyHysteresis(IndoorNavigationDecision next) {
    final previous = _lastDecision;
    if (previous == null) {
      return next;
    }

    if (next.dangerLevel.index < previous.dangerLevel.index) {
      _calmFrames++;
      if (_calmFrames < 2) {
        return IndoorNavigationDecision(
          dangerLevel: previous.dangerLevel,
          cue: previous.cue,
          spokenText: previous.spokenText,
          statusText: next.statusText,
          hazards: next.hazards,
          highlightedDetections: next.highlightedDetections,
          wallLikely: next.wallLikely,
          freeSpaceRatio: next.freeSpaceRatio,
          depthSource: next.depthSource,
        );
      }
    } else {
      _calmFrames = 0;
    }

    return next;
  }

  Future<void> _speakIfNeeded(IndoorNavigationDecision decision) async {
    final now = DateTime.now();
    final previous = _lastDecision;

    final isEscalation =
        previous == null ||
        decision.dangerLevel.index > previous.dangerLevel.index;
    final cueChanged = previous == null || decision.cue != previous.cue;
    final shouldReassure =
        decision.dangerLevel == DangerLevel.safe &&
        now.difference(_lastSafePromptAt) >= const Duration(seconds: 8);

    if (decision.dangerLevel == DangerLevel.safe && !shouldReassure) {
      return;
    }

    if (isEscalation ||
        cueChanged ||
        now.difference(_lastSpokenAt) >= const Duration(seconds: 4)) {
      if (decision.dangerLevel == DangerLevel.safe) {
        _lastSafePromptAt = now;
      }
      _lastSpokenAt = now;
      await speech.speak(
        decision.spokenText,
        force: decision.dangerLevel.index >= DangerLevel.danger.index,
        throttle: false,
      );
    }
  }

  Future<void> stop() async {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    await waitForIdle();
    await camera.stopAnalysisStream();
  }

  Future<void> waitForIdle() async {
    if (_activeProcessingCompleter != null &&
        !_activeProcessingCompleter!.isCompleted) {
      try {
        await _activeProcessingCompleter!.future.timeout(
          const Duration(seconds: 2),
        );
      } catch (_) {}
    }
  }

  Future<void> dispose() async {
    await stop();
    for (final provider in _providers) {
      await provider.dispose();
    }
  }
}
