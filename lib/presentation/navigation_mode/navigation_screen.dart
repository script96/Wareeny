import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';
import 'package:wareeny/presentation/navigation_mode/widgets/navigation_debug_panel.dart';
import 'package:wareeny/presentation/navigation_mode/widgets/navigation_overlay.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
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
  late final YOLOViewController _yoloController;
  NavigationController? _navigation;
  ObjectDetectionSource? _detectionSource;
  Object? _modelError;
  bool _debugEnabled = false;
  bool _initialized = false;
  Timer? _modelCycleTimer;
  Timer? _lightCheckTimer;
  bool _modelSwitchInProgress = false;
  bool _lightCheckInProgress = false;
  int _darkSamples = 0;
  int _lightSamples = 0;
  String _activeModelSource = 'indoor';
  NavigationSubMode _navSubMode = NavigationSubMode.indoor;

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
    )..addListener(_onNavigationChanged);
    _initialized = true;
    unawaited(_navigation!.start());
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
    _modelCycleTimer?.cancel();
    _lightCheckTimer?.cancel();
    unawaited(_yoloController.setTorchMode(false));
    unawaited(_yoloController.stop());
    _navigation
      ?..removeListener(_onNavigationChanged)
      ..dispose();
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
              child: NavigationOverlay(
                path: navigation.path,
                frame: navigation.latestFrame,
                assessment: navigation.assessment,
                showDebug: _debugEnabled,
                logProjection: _debugEnabled,
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
              top: 112,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: NavigationDebugPanel(
                    controller: navigation,
                    enabled: _debugEnabled,
                    onToggle: () {
                      setState(() => _debugEnabled = !_debugEnabled);
                    },
                  ),
                ),
              ),
            ),
            const Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(child: SafeArea(child: CameraSideActions())),
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
        maxFPS: 12,
        inferenceFrequency: 12,
      ),
      onStreamingData: (data) {
        source.processStreamingData({
          ...data,
          'modelSource': isIndoor ? _activeModelSource : 'coco',
        });
      },
      onModelLoad: (loadedPath, _) {
        if (loadedPath != modelPath || !mounted) return;
        if (_modelError != null) {
          setState(() => _modelError = null);
        }
        _startLightMonitoring();
        if (isIndoor) _startIndoorModelCycle(source);
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
      _startLightMonitoring();
      final source = _detectionSource;
      if (_navSubMode == NavigationSubMode.indoor &&
          source is YoloStreamingObjectDetectionSource) {
        _startIndoorModelCycle(source);
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _modelError = 'YOLO camera plugin is unavailable');
      }
    }
  }

  Future<void> _pause() async {
    _modelCycleTimer?.cancel();
    _lightCheckTimer?.cancel();
    await _setTorch(false);
    try {
      await _yoloController.pause();
    } on MissingPluginException {
      // The platform view may already be detached during lifecycle teardown.
    }
    await _navigation?.stop();
  }

  void _onNavigationChanged() {
    if (mounted) setState(() {});
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
    });
    _navigation?.setIndoorMode(mode == NavigationSubMode.indoor);
    _modelCycleTimer?.cancel();
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

  void _startIndoorModelCycle(YoloStreamingObjectDetectionSource source) {
    _modelCycleTimer?.cancel();
    _modelCycleTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(_switchIndoorModel(source)),
    );
  }

  Future<void> _switchIndoorModel(
    YoloStreamingObjectDetectionSource source,
  ) async {
    if (!mounted ||
        _navSubMode != NavigationSubMode.indoor ||
        _modelSwitchInProgress) {
      return;
    }
    _modelSwitchInProgress = true;
    final nextSource = _activeModelSource == 'indoor' ? 'coco' : 'indoor';
    final nextPath = source.modelPathForMode(
      nextSource == 'indoor' ? 'navigation_indoor' : 'navigation_outdoor',
    );
    try {
      await _yoloController.switchModel(nextPath, YOLOTask.detect);
      await _yoloController.setConfidenceThreshold(
        nextSource == 'indoor' ? 0.20 : 0.35,
      );
      _activeModelSource = nextSource;
      _navigation?.reportActiveDetectorSource(nextSource);
    } catch (error) {
      _navigation?.reportModelError(error);
    } finally {
      _modelSwitchInProgress = false;
    }
  }

  void _startLightMonitoring() {
    _lightCheckTimer?.cancel();
    _lightCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_checkSceneLighting()),
    );
  }

  Future<void> _checkSceneLighting() async {
    if (!mounted || _lightCheckInProgress) return;
    _lightCheckInProgress = true;
    try {
      final bytes = await _yoloController.captureFrame();
      if (bytes == null || bytes.isEmpty) return;
      final luminance = await compute(_estimateLuminance, bytes);
      if (luminance == null || !mounted) return;

      if (luminance < 45) {
        _darkSamples++;
        _lightSamples = 0;
      } else if (luminance > 190) {
        _lightSamples++;
        _darkSamples = 0;
      } else {
        _darkSamples = 0;
        _lightSamples = 0;
      }

      if (_darkSamples >= 2 && !_yoloController.isTorchEnabled) {
        await _setTorch(true);
      } else if (_lightSamples >= 3 && _yoloController.isTorchEnabled) {
        await _setTorch(false);
      }
      _navigation?.reportLighting(
        luminance: luminance,
        torchOn: _yoloController.isTorchEnabled,
      );
    } on MissingPluginException {
      _lightCheckTimer?.cancel();
    } catch (error) {
      debugPrint('[Navigation] Light check failed: $error');
    } finally {
      _lightCheckInProgress = false;
    }
  }

  Future<void> _setTorch(bool enabled) async {
    try {
      await _yoloController.setTorchMode(enabled);
    } on MissingPluginException {
      return;
    }
    if (!enabled) {
      _darkSamples = 0;
      _lightSamples = 0;
    }
  }
}

double? _estimateLuminance(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;

  var luminanceTotal = 0.0;
  var samples = 0;
  final xStride = (image.width / 32).ceil().clamp(1, image.width);
  final yStride = (image.height / 32).ceil().clamp(1, image.height);
  for (var y = 0; y < image.height; y += yStride) {
    for (var x = 0; x < image.width; x += xStride) {
      final pixel = image.getPixel(x, y);
      luminanceTotal += 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
      samples++;
    }
  }
  return samples == 0 ? null : luminanceTotal / samples;
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
