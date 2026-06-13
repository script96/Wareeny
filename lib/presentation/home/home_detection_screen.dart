import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

class HomeDetectionScreen extends StatefulWidget {
  const HomeDetectionScreen({
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
  State<HomeDetectionScreen> createState() => _HomeDetectionScreenState();
}

class _HomeDetectionScreenState extends State<HomeDetectionScreen>
    with WidgetsBindingObserver {
  late final YOLOViewController _yoloController;
  YoloStreamingObjectDetectionSource? _detectionSource;
  Object? _modelError;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _yoloController = YOLOViewController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final source = AppScope.of(context).objectDetectionSource;
    if (source is YoloStreamingObjectDetectionSource) {
      _detectionSource = source;
      unawaited(source.start(mode: 'home'));
    }
    _initialized = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resume());
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
    unawaited(_detectionSource?.stop());
    _yoloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TwoFingerSwipeDetector(
      onSwipeLeft: widget.onNext,
      onSwipeRight: widget.onPrevious,
      child: Semantics(
        label: l10n.activeModeNamed(AppMode.home.labelFor(l10n)),
        customSemanticsActions: AppMode.home.getModeSwitchActions(
          l10n: l10n,
          settings: widget.settings,
          onModeSelect: widget.onModeSelect,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildDetector(),
            const Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                minimum: EdgeInsets.only(top: 12),
                child: CameraTopBar(currentMode: AppMode.home),
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
                    current: AppMode.home,
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

  Widget _buildDetector() {
    if (_modelError != null) {
      return CameraStatusView(
        icon: Icons.videocam_off_outlined,
        title: 'Object detector unavailable',
        message: 'The Home detection model could not be loaded. $_modelError',
      );
    }
    final source = _detectionSource;
    if (source == null) {
      return const CameraStatusView(
        icon: Icons.error_outline,
        title: 'Detector unavailable',
        message: 'Home requires the YOLO streaming detector.',
      );
    }

    return YOLOView(
      modelPath: source.modelPathForMode('home'),
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
      await _detectionSource?.start(mode: 'home');
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
    await _detectionSource?.stop();
  }
}
