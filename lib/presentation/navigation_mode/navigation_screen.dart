import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/navigation_mode/navigation_controller.dart';
import 'package:wareeny/presentation/navigation_mode/widgets/navigation_debug_panel.dart';
import 'package:wareeny/presentation/navigation_mode/widgets/navigation_overlay.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/shared/navigation/navigation_feedback.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({
    required this.previousMode,
    required this.nextMode,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final AppMode previousMode;
  final AppMode nextMode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

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

    return TwoFingerSwipeDetector(
      onSwipeLeft: widget.onNext,
      onSwipeRight: widget.onPrevious,
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
              child: const CameraTopBar(currentMode: AppMode.navigation),
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
}
