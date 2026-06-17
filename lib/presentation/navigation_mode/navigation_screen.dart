import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';
import 'package:wareeny/presentation/navigation_mode/widgets/navigation_overlay.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/camera/light_condition_service.dart';
import 'package:wareeny/shared/danger/danger_alert_manager.dart';
import 'package:wareeny/shared/danger/danger_detection_result.dart';
import 'package:wareeny/shared/danger/danger_detection_service.dart';
import 'package:wareeny/shared/navigation/coco_navigation_assist_service.dart';
import 'package:wareeny/shared/navigation/navigation_feedback.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

/// Sub-modes available inside the Navigation screen.
enum NavigationSubMode {
  indoor,
  outdoor;

  IconData get icon => switch (this) {
    NavigationSubMode.indoor => Icons.apartment_outlined,
    NavigationSubMode.outdoor => Icons.explore_outlined,
  };

  String labelFor(AppLocalizations l10n) => switch (this) {
    NavigationSubMode.indoor => l10n.navIndoor,
    NavigationSubMode.outdoor => l10n.navOutdoor,
  };
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    required this.previousMode,
    required this.nextMode,
    required this.onPrevious,
    required this.onNext,
    required this.onModeSelect,
    required this.settings,
    super.key,
  });

  final AppMode previousMode;
  final AppMode nextMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final void Function(int) onModeSelect;
  final SettingsController settings;

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen>
    with WidgetsBindingObserver {
  static const _torchProbeInterval = Duration(seconds: 4);
  static const _torchProbeSettleDelay = Duration(milliseconds: 250);

  late final YOLOViewController _yoloController;
  NavigationController? _navigation;
  CocoNavigationAssistService? _indoorCocoAssist;
  DangerAlertManager? _dangerAlerts;
  DangerDetectionService? _dangerDetection;
  ObjectDetectionSource? _detectionSource;
  Object? _modelError;
  bool _debugEnabled = false;
  bool _initialized = false;
  Timer? _lightCheckTimer;
  Timer? _exitSearchTimer;
  final LightConditionService _lightService = LightConditionService();
  bool _lightCheckInProgress = false;
  bool _exitSearchActive = false;
  String _activeModelSource = 'indoor';
  NavigationSubMode _navSubMode = NavigationSubMode.indoor;
  Uint8List? _latestFrameBytes;
  DateTime? _latestFrameAt;
  Future<Uint8List?>? _frameCaptureInFlight;
  DateTime? _lastTorchProbeAt;

  @override
  void initState() {
    super.initState();
    _yoloController = YOLOViewController();
    unawaited(_yoloController.setShowOverlays(false));
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final services = AppScope.of(context);
    _detectionSource = services.objectDetectionSource;
    _debugEnabled = services.config.enableDiagnostics;
    _navigation = NavigationController(
      detectionSource: services.objectDetectionSource,
      feedback: BridgeNavigationFeedback(services.audioHapticsBridge),
      diagnosticsEnabled: services.config.enableDiagnostics,
    );
    _indoorCocoAssist = CocoNavigationAssistService(
      diagnosticsEnabled: services.config.enableDiagnostics,
      onFrame: (frame) {
        _navigation?.processFrame(frame);
      },
    );
    _dangerAlerts = DangerAlertManager(
      feedback: BridgeDangerAlertFeedback(
        services.audioHapticsBridge,
        stopVoiceInput:
            services.voiceInteractionController.interruptForDangerAlert,
      ),
      diagnosticsEnabled: services.config.enableDiagnostics,
    );
    _dangerDetection = DangerDetectionService(
      alertManager: _dangerAlerts!,
      diagnosticsEnabled: services.config.enableDiagnostics,
    );
    _initialized = true;
    unawaited(_navigation!.start());
    unawaited(_indoorCocoAssist!.start());
    _startDangerDetection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
      unawaited(_navigation?.start());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lightCheckTimer?.cancel();
    unawaited(_yoloController.setTorchMode(false));
    unawaited(_yoloController.stop());
    _clearFrameCache();
    unawaited(_indoorCocoAssist?.stop());
    _navigation?.dispose();
    _dangerDetection?.dispose();
    _dangerAlerts?.dispose();
    _yoloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigation = _navigation;
    if (navigation == null) {
      return const ColoredBox(color: Colors.black);
    }

    final l10n = AppLocalizations.of(context);
    final listenables = <Listenable>[navigation];
    final dangerDetection = _dangerDetection;
    if (dangerDetection != null) listenables.add(dangerDetection);
    final overlayListenable = Listenable.merge(listenables);
    final modeActions = AppMode.navigation.getModeSwitchActions(
      l10n: l10n,
      settings: widget.settings,
      onModeSelect: widget.onModeSelect,
    );

    final toggleSubModeLabel = widget.settings.isArabic
        ? 'تبديل نوع التنقل'
        : 'Toggle Navigation Type';
    modeActions[CustomSemanticsAction(label: toggleSubModeLabel)] =
        _cycleNavigationSubMode;
    final findExitLabel = widget.settings.isArabic
        ? 'ابحث عن مخرج'
        : 'Find Exit';
    modeActions[CustomSemanticsAction(label: findExitLabel)] = _beginExitSearch;

    return TwoFingerSwipeDetector(
      onSwipeLeft: widget.onNext,
      onSwipeRight: widget.onPrevious,
      onSwipeUp: _cycleNavigationSubMode,
      onSwipeDown: _cycleNavigationSubMode,
      child: Semantics(
        label: l10n.activeModeNamed(AppMode.navigation.labelFor(l10n)),
        customSemanticsActions: modeActions,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCamera(),
            IgnorePointer(
              child: ListenableBuilder(
                listenable: overlayListenable,
                builder: (context, _) {
                  return NavigationOverlay(
                    path: navigation.path,
                    frame: navigation.latestFrame,
                    assessment: navigation.assessment,
                    dangerFrame: _dangerDetection?.latestFrame,
                    showDebug: _debugEnabled,
                    logProjection: _debugEnabled,
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    const CameraTopBar(currentMode: AppMode.navigation),
                    const SizedBox(height: AppSpacing.sm),
                    _NavSubModeToggle(
                      subMode: _navSubMode,
                      onSelect: _selectNavigationSubMode,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: Center(
                  child: ModeCarouselBar(
                    previous: widget.previousMode,
                    current: AppMode.navigation,
                    next: widget.nextMode,
                    onPreviousTap: widget.onPrevious,
                    onNextTap: widget.onNext,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCamera() {
    if (_modelError != null) {
      return const CameraStatusView(
        icon: Icons.videocam_off_outlined,
        title: 'YOLOv8n unavailable',
        message: 'The navigation model could not be loaded.',
      );
    }
    final source = _detectionSource;
    if (source is! YoloStreamingObjectDetectionSource) {
      return const CameraStatusView(
        icon: Icons.error_outline,
        title: 'Detector unavailable',
        message: 'Navigation requires the YOLO streaming detector.',
      );
    }

    final modelPath = source.modelPathForMode(
      _navSubMode == NavigationSubMode.indoor
          ? 'navigation_indoor'
          : 'navigation_outdoor',
    );
    final isIndoor = _navSubMode == NavigationSubMode.indoor;
    return YOLOView(
      modelPath: modelPath,
      task: YOLOTask.detect,
      controller: _yoloController,
      cameraResolution: '720p',
      confidenceThreshold: isIndoor ? 0.20 : 0.35,
      iouThreshold: 0.45,
      useGpu: !isIndoor,
      lensFacing: LensFacing.back,
      streamingConfig: const YOLOStreamingConfig(
        includeDetections: true,
        includeClassifications: false,
        includeProcessingTimeMs: true,
        includeFps: true,
        // Reuse streamed frames for danger/light analysis to avoid extra preview captures.
        includeOriginalImage: true,
        maxFPS: 12,
        inferenceFrequency: 12,
      ),
      onStreamingData: (data) {
        _cacheFrameBytes(data);
        source.processStreamingData({
          ...data,
          'modelSource': isIndoor ? _activeModelSource : 'coco',
        });
        if (isIndoor) {
          _runIndoorCocoAssist(data);
        }
      },
      onModelLoad: (loadedPath, _) {
        if (loadedPath != modelPath || !mounted) return;
        if (_modelError != null) {
          setState(() => _modelError = null);
        }
        _startDangerDetection();
        _startLightMonitoring();
      },
      onModelError: (error, failedPath, _) {
        if (failedPath != modelPath || !mounted) return;
        _navigation?.reportModelError(error);
        setState(() => _modelError = error);
      },
    );
  }

  Future<void> _resume() async {
    try {
      await _yoloController.resume();
      await _indoorCocoAssist?.start();
      _startLightMonitoring();
      _startDangerDetection();
    } on MissingPluginException {
      if (mounted) {
        setState(() => _modelError = 'YOLO camera plugin is unavailable');
      }
    }
  }

  Future<void> _pause() async {
    _lightCheckTimer?.cancel();
    _exitSearchTimer?.cancel();
    _lastTorchProbeAt = null;
    _lightService.reset();
    _clearFrameCache();
    await _setTorch(false);
    await _indoorCocoAssist?.stop();
    await _dangerDetection?.stop();
    try {
      await _yoloController.pause();
    } on MissingPluginException {
      // The platform view may already be detached during lifecycle teardown.
    }
    await _navigation?.stop();
  }

  void _startDangerDetection() {
    final dangerDetection = _dangerDetection;
    final source = _detectionSource;
    if (dangerDetection == null || source == null) return;
    unawaited(
      dangerDetection.start(
        captureFrame: _captureDangerFrame,
        navigationMode: () => _navSubMode == NavigationSubMode.indoor
            ? DangerNavigationMode.indoor
            : DangerNavigationMode.outdoor,
        exitSearchActive: () => _exitSearchActive,
      ),
    );
  }

  void _runIndoorCocoAssist(Map<String, dynamic> data) {
    final assist = _indoorCocoAssist;
    if (assist == null) return;

    final originalImage = data['originalImage'];
    Uint8List? bytes;
    if (originalImage is Uint8List && originalImage.isNotEmpty) {
      bytes = originalImage;
    } else if (originalImage is List<int> && originalImage.isNotEmpty) {
      bytes = Uint8List.fromList(originalImage);
    }
    if (bytes == null || bytes.isEmpty) return;

    final timestamp = _frameTimestampFrom(data) ?? DateTime.now();
    unawaited(assist.analyzeFrame(bytes, timestamp: timestamp));
  }

  Future<Uint8List?> _captureDangerFrame() async {
    return _readAnalysisFrame(
      maxAge: const Duration(milliseconds: 400),
      allowControllerCapture: false,
    );
  }

  void _cycleNavigationSubMode() {
    final nextMode = _navSubMode == NavigationSubMode.indoor
        ? NavigationSubMode.outdoor
        : NavigationSubMode.indoor;
    _selectNavigationSubMode(nextMode);
  }

  void _selectNavigationSubMode(NavigationSubMode mode) {
    if (_navSubMode == mode) return;
    setState(() {
      _navSubMode = mode;
      _modelError = null;
      if (mode == NavigationSubMode.outdoor) {
        _exitSearchActive = false;
        _exitSearchTimer?.cancel();
      }
    });
    _navigation?.setIndoorMode(mode == NavigationSubMode.indoor);
    _activeModelSource = mode == NavigationSubMode.indoor ? 'indoor' : 'coco';
    _navigation?.reportActiveDetectorSource(_activeModelSource);
    final l10n = AppLocalizations.of(context);
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.settings.isArabic
          ? '${mode.labelFor(l10n)} ${l10n.activeMode('')}'.trim()
          : l10n.activeMode(mode.labelFor(l10n)),
      widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  void _beginExitSearch() {
    if (_navSubMode != NavigationSubMode.indoor) return;
    setState(() => _exitSearchActive = true);
    _exitSearchTimer?.cancel();
    _exitSearchTimer = Timer(const Duration(seconds: 45), () {
      if (mounted) setState(() => _exitSearchActive = false);
    });
    SemanticsService.sendAnnouncement(
      View.of(context),
      widget.settings.isArabic
          ? 'تمام، هدور على علامة خروج'
          : 'Searching for an exit sign',
      widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  void _startLightMonitoring() {
    _lightCheckTimer?.cancel();
    _lightCheckTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_checkSceneLighting()),
    );
  }

  Future<void> _checkSceneLighting() async {
    if (!mounted || _lightCheckInProgress) return;
    _lightCheckInProgress = true;
    try {
      var torchEnabled = _yoloController.isTorchEnabled;
      LightConditionResult? result;
      if (torchEnabled) {
        result = await _probeAmbientLightWhileTorchOn();
        torchEnabled = _yoloController.isTorchEnabled;
      } else {
        result = await _analyzeCurrentLightFrame();
      }
      if (result == null || !mounted) return;

      if (result.flashRequested && !torchEnabled) {
        torchEnabled = await _setTorch(true);
        if (torchEnabled) {
          _lastTorchProbeAt = DateTime.now();
        }
        if (result.shouldSpeak) {
          _navigation?.announceLowLight(flashEnabled: torchEnabled);
        }
      }
      _navigation?.reportLighting(result: result, torchOn: torchEnabled);
      debugPrint(
        '[LightCondition] average=${result.averageBrightness.toStringAsFixed(1)} '
        'darkRatio=${result.darkPixelRatio.toStringAsFixed(2)} '
        'state=${result.condition.name} '
        'darkFor=${result.darkDuration.inMilliseconds}ms '
        'flashRequested=${result.flashRequested} torchOn=$torchEnabled',
      );
    } on MissingPluginException {
      _lightCheckTimer?.cancel();
    } catch (error) {
      debugPrint('[Navigation] Light check failed: $error');
    } finally {
      _lightCheckInProgress = false;
    }
  }

  Future<bool> _setTorch(bool enabled) async {
    try {
      await _yoloController.setTorchMode(enabled);
    } on MissingPluginException {
      return false;
    } catch (error) {
      debugPrint('[LightCondition] Torch change failed: $error');
      return false;
    }
    return _yoloController.isTorchEnabled;
  }

  Future<LightConditionResult?> _analyzeCurrentLightFrame() async {
    final bytes = await _readAnalysisFrame(
      maxAge: const Duration(milliseconds: 900),
      allowControllerCapture: true,
    );
    if (bytes == null || bytes.isEmpty) return null;
    return _analyzeLightFrameBytes(bytes);
  }

  Future<LightConditionResult?> _probeAmbientLightWhileTorchOn() async {
    final lastProbeAt = _lastTorchProbeAt;
    final now = DateTime.now();
    if (lastProbeAt != null &&
        now.difference(lastProbeAt) < _torchProbeInterval) {
      return null;
    }

    _lastTorchProbeAt = now;
    final wasTorchEnabled = _yoloController.isTorchEnabled;
    if (!wasTorchEnabled) {
      return _analyzeCurrentLightFrame();
    }

    await _setTorch(false);
    await Future<void>.delayed(_torchProbeSettleDelay);
    _clearFrameCache();

    final result = await _analyzeCurrentLightFrame();
    if (result == null) {
      await _setTorch(true);
      _clearFrameCache();
      return null;
    }

    final shouldKeepTorchOff =
        result.condition == LightCondition.normal && result.recovered;
    if (!shouldKeepTorchOff) {
      await _setTorch(true);
    }
    _clearFrameCache();
    return result;
  }

  Future<LightConditionResult?> _analyzeLightFrameBytes(Uint8List bytes) async {
    final rawStats = await compute(analyzeEncodedLightFrame, {
      'bytes': bytes,
      'darkPixelThreshold': _lightService.config.darkPixelThreshold,
      'sampleStride': _lightService.config.sampleStride,
      'pathWeight': _navSubMode == NavigationSubMode.indoor
          ? _lightService.config.pathWeight
          : 1,
    });
    if (rawStats == null || !mounted) return null;
    return _lightService.addSample(
      LightFrameStats(
        averageBrightness: rawStats['averageBrightness']!.toDouble(),
        darkPixelRatio: rawStats['darkPixelRatio']!.toDouble(),
        sampleCount: rawStats['sampleCount']!.toInt(),
      ),
    );
  }

  Future<Uint8List?> _readAnalysisFrame({
    required Duration maxAge,
    required bool allowControllerCapture,
  }) async {
    final cached = _latestUsableFrame(maxAge: maxAge);
    if (cached != null) return cached;
    if (!allowControllerCapture) return null;
    if (!_yoloController.isInitialized) return null;

    final inFlight = _frameCaptureInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final capture = _captureControllerFrame();
    _frameCaptureInFlight = capture;
    try {
      return await capture;
    } finally {
      if (identical(_frameCaptureInFlight, capture)) {
        _frameCaptureInFlight = null;
      }
    }
  }

  Future<Uint8List?> _captureControllerFrame() async {
    try {
      final bytes = await _yoloController.captureFrame();
      if (bytes != null && bytes.isNotEmpty) {
        _latestFrameBytes = bytes;
        _latestFrameAt = DateTime.now();
      }
      return bytes;
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('[Navigation] frame capture failed: $error');
      return null;
    }
  }

  Uint8List? _latestUsableFrame({required Duration maxAge}) {
    final bytes = _latestFrameBytes;
    final capturedAt = _latestFrameAt;
    if (bytes == null ||
        bytes.isEmpty ||
        capturedAt == null ||
        DateTime.now().difference(capturedAt) > maxAge) {
      return null;
    }
    return bytes;
  }

  void _cacheFrameBytes(Map<String, dynamic> data) {
    final originalImage = data['originalImage'];
    if (originalImage is Uint8List && originalImage.isNotEmpty) {
      _latestFrameBytes = originalImage;
      _latestFrameAt = _frameTimestampFrom(data) ?? DateTime.now();
      return;
    }
    if (originalImage is List<int> && originalImage.isNotEmpty) {
      _latestFrameBytes = Uint8List.fromList(originalImage);
      _latestFrameAt = _frameTimestampFrom(data) ?? DateTime.now();
    }
  }

  DateTime? _frameTimestampFrom(Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    if (timestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    }
    return null;
  }

  void _clearFrameCache() {
    _latestFrameBytes = null;
    _latestFrameAt = null;
    _frameCaptureInFlight = null;
  }
}

// ── Navigation sub-mode toggle ────────────────────────────────────────────────

class _NavSubModeToggle extends StatelessWidget {
  const _NavSubModeToggle({required this.subMode, required this.onSelect});

  final NavigationSubMode subMode;
  final void Function(NavigationSubMode) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n.navTypeSelectorHint,
      hint: l10n.subModeSwipeHint,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: NavigationSubMode.values.map((mode) {
                final active = mode == subMode;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Semantics(
                    button: true,
                    selected: active,
                    label: mode.labelFor(l10n),
                    child: GestureDetector(
                      onTap: () => onSelect(mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm + 2,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.electricGreenDim
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: active
                              ? Border.all(
                                  color: AppColors.electricGreen,
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              mode.icon,
                              color: active
                                  ? AppColors.electricGreen
                                  : Colors.white54,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              mode.labelFor(l10n).toUpperCase(),
                              style: TextStyle(
                                color: active
                                    ? AppColors.electricGreen
                                    : Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
