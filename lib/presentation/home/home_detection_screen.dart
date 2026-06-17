import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';
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
  AudioHapticsBridge? _audioHaptics;
  bool Function()? _canSpeak;
  StreamSubscription<ObjectDetectionFrame>? _frameSubscription;
  Object? _modelError;
  bool _initialized = false;
  String? _lastAnnouncedLabel;
  DateTime? _lastAnnouncementAt;

  static const _announcementCooldown = Duration(seconds: 3);
  static const _repeatAnnouncementCooldown = Duration(seconds: 7);
  static const _minimumAnnouncementArea = 0.02;
  static const _minimumAnnouncementConfidence = 0.45;

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
    final services = AppScope.of(context);
    final source = services.objectDetectionSource;
    if (source is YoloStreamingObjectDetectionSource) {
      _detectionSource = source;
      _audioHaptics = services.audioHapticsBridge;
      _canSpeak = () => !services.voiceInteractionController.isCapturingSpeech;
      _frameSubscription = source.frames.listen(_handleFrame);
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
    unawaited(_frameSubscription?.cancel());
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

  void _handleFrame(ObjectDetectionFrame frame) {
    final bridge = _audioHaptics;
    final canSpeak = _canSpeak;
    if (bridge == null || canSpeak == null || !canSpeak()) return;

    final closest = _closestDetection(frame);
    if (closest == null) return;

    final normalizedLabel = closest.label.trim().toLowerCase();
    final now = DateTime.now();
    final lastAnnouncementAt = _lastAnnouncementAt;
    if (lastAnnouncementAt != null) {
      final elapsed = now.difference(lastAnnouncementAt);
      if (normalizedLabel == _lastAnnouncedLabel &&
          elapsed < _repeatAnnouncementCooldown) {
        return;
      }
      if (normalizedLabel != _lastAnnouncedLabel &&
          elapsed < _announcementCooldown) {
        return;
      }
    }

    final announcement = _announcementForLabel(normalizedLabel);
    _lastAnnouncedLabel = normalizedLabel;
    _lastAnnouncementAt = now;
    unawaited(
      bridge.speak(
        announcement.message,
        interrupt: true,
        languageCode: announcement.languageCode,
      ),
    );
  }

  ObjectDetection? _closestDetection(ObjectDetectionFrame frame) {
    ObjectDetection? closest;
    var bestArea = 0.0;
    for (final detection in frame.detections) {
      if (detection.confidence < _minimumAnnouncementConfidence) continue;
      final area =
          (detection.boundingBox.width * detection.boundingBox.height) /
          (frame.sourceSize.width * frame.sourceSize.height);
      if (area < _minimumAnnouncementArea || area <= bestArea) continue;
      bestArea = area;
      closest = detection;
    }
    return closest;
  }

  _HomeObjectAnnouncement _announcementForLabel(String label) {
    final arabic = _arabicObjectLabels[label];
    if (arabic != null) {
      return _HomeObjectAnnouncement(
        message: 'أقرب حاجة $arabic',
        languageCode: 'ar-EG',
      );
    }
    return _HomeObjectAnnouncement(
      message: 'Closest object $label',
      languageCode: 'en-US',
    );
  }
}

class _HomeObjectAnnouncement {
  const _HomeObjectAnnouncement({
    required this.message,
    required this.languageCode,
  });

  final String message;
  final String languageCode;
}

const _arabicObjectLabels = <String, String>{
  'person': 'شخص',
  'chair': 'كرسي',
  'couch': 'كنبة',
  'sofa': 'كنبة',
  'bench': 'مقعد',
  'dining table': 'طاولة',
  'table': 'طاولة',
  'bottle': 'زجاجة',
  'cup': 'كوب',
  'book': 'كتاب',
  'backpack': 'شنطة',
  'handbag': 'حقيبة',
  'cell phone': 'موبايل',
  'laptop': 'لاب توب',
  'tv': 'تلفزيون',
  'remote': 'ريموت',
  'keyboard': 'كيبورد',
  'mouse': 'ماوس',
  'wallet': 'محفظة',
  'glasses': 'نظارة',
  'keys': 'مفاتيح',
};
