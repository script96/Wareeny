import 'dart:async';
import 'dart:ui';

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
    modeActions[CustomSemanticsAction(label: toggleSubModeLabel)] = _cycleNavigationSubMode;

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
                      onSelect: (mode) {
                        setState(() => _navSubMode = mode);
                        final l10n = AppLocalizations.of(context);
                        SemanticsService.announce(
                          widget.settings.isArabic
                              ? '${mode.labelFor(l10n)} ${l10n.activeMode('')}'.trim()
                              : l10n.activeMode(mode.labelFor(l10n)),
                          widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 84,
              left: 16,
              child: SafeArea(
                child: NavigationDebugPanel(
                  controller: navigation,
                  enabled: _debugEnabled,
                  onToggle: () {
                    setState(() => _debugEnabled = !_debugEnabled);
                  },
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

    return YOLOView(
      modelPath: source.modelPath,
      task: YOLOTask.detect,
      controller: _yoloController,
      cameraResolution: '720p',
      confidenceThreshold: 0.45,
      iouThreshold: 0.45,
      useGpu: true,
      lensFacing: LensFacing.back,
      streamingConfig: const YOLOStreamingConfig(
        includeDetections: true,
        includeClassifications: false,
        includeProcessingTimeMs: true,
        includeFps: true,
        maxFPS: 15,
        inferenceFrequency: 15,
      ),
      onStreamingData: source.processStreamingData,
      onModelLoad: (_, _) {
        if (mounted && _modelError != null) {
          setState(() => _modelError = null);
        }
      },
      onModelError: (error, _, _) {
        if (mounted) setState(() => _modelError = error);
      },
    );
  }

  Future<void> _resume() async {
    try {
      await _yoloController.resume();
    } on MissingPluginException {
      if (mounted) {
        setState(() => _modelError = 'YOLO camera plugin is unavailable');
      }
    }
  }

  Future<void> _pause() async {
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
    final l10n = AppLocalizations.of(context);
    final nextMode = _navSubMode == NavigationSubMode.indoor
        ? NavigationSubMode.outdoor
        : NavigationSubMode.indoor;
    setState(() => _navSubMode = nextMode);
    SemanticsService.announce(
      widget.settings.isArabic
          ? '${nextMode.labelFor(l10n)} ${l10n.activeMode('')}'.trim()
          : l10n.activeMode(nextMode.labelFor(l10n)),
      widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
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
                                  color: AppColors.electricGreen, width: 1)
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
