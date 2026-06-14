import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/stuff_finder/coco_classes.dart';
import 'package:wareeny/presentation/stuff_finder/stuff_finder_controller.dart';
import 'package:wareeny/presentation/stuff_finder/widgets/coco_object_picker.dart';
import 'package:wareeny/presentation/stuff_finder/widgets/stuff_finder_overlay.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

class StuffFinderScreen extends StatefulWidget {
  const StuffFinderScreen({
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
  State<StuffFinderScreen> createState() => _StuffFinderScreenState();
}

class _StuffFinderScreenState extends State<StuffFinderScreen>
    with WidgetsBindingObserver {
  late final YOLOViewController _yoloController;
  StuffFinderController? _finder;
  ObjectDetectionSource? _detectionSource;
  Object? _modelError;
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
    final source = services.objectDetectionSource;
    _detectionSource = source;
    _finder = StuffFinderController(
      detectionSource: source,
      feedback: BridgeStuffFinderFeedback(services.audioHapticsBridge),
    )..addListener(_onFinderChanged);
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
    _finder
      ?..removeListener(_onFinderChanged)
      ..dispose();
    _yoloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finder = _finder;
    if (finder == null) return const ColoredBox(color: Colors.black);

    final l10n = AppLocalizations.of(context);
    final modeActions = AppMode.stuffFinder.getModeSwitchActions(
      l10n: l10n,
      settings: widget.settings,
      onModeSelect: widget.onModeSelect,
    );

    modeActions[CustomSemanticsAction(label: l10n.sfChooseObjectToFind)] =
        _pickTarget;

    return TwoFingerSwipeDetector(
      onSwipeLeft: widget.onNext,
      onSwipeRight: widget.onPrevious,
      child: Semantics(
        label: l10n.activeModeNamed(AppMode.stuffFinder.labelFor(l10n)),
        customSemanticsActions: modeActions,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildCamera(finder),
            IgnorePointer(child: StuffFinderOverlay(frame: finder.latestFrame)),
            Positioned(
              top: 0,
              left: 16,
              right: 16,
              child: SafeArea(
                minimum: const EdgeInsets.only(top: 12),
                child: const CameraTopBar(currentMode: AppMode.stuffFinder),
              ),
            ),
            Positioned(
              top: 84,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Center(
                  child: _TargetButton(finder: finder, onTap: _pickTarget),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 112,
              child: SafeArea(
                child: Center(child: _StatusChip(finder: finder)),
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
                    current: AppMode.stuffFinder,
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

  Widget _buildCamera(StuffFinderController finder) {
    final l10n = AppLocalizations.of(context);
    if (finder.selectedTarget == null) {
      return CameraStatusView(
        icon: Icons.search_outlined,
        title: l10n.sfTitle,
        message: l10n.sfChooseToStart,
      );
    }
    if (_modelError != null) {
      return CameraStatusView(
        icon: Icons.error_outline,
        title: l10n.sfModelUnavailableTitle,
        message: l10n.sfModelUnavailableMsg(_modelError!),
      );
    }
    final source = _detectionSource;
    if (source is! YoloStreamingObjectDetectionSource) {
      return CameraStatusView(
        icon: Icons.error_outline,
        title: l10n.sfDetectorUnavailableTitle,
        message: l10n.sfDetectorUnavailableMsg,
      );
    }

    final useCustomModel = isCustomStuffFinderClass(finder.selectedTarget!);
    final modelPath = source.modelPathForMode(
      'stuff_finder',
      useCustomModel: useCustomModel,
    );

    // The platform view is a raw camera/detector surface with no readable
    // content; hide it from TalkBack/VoiceOver so focus stays on the overlays.
    return ExcludeSemantics(
      child: YOLOView(
        modelPath: modelPath,
        task: YOLOTask.detect,
        controller: _yoloController,
        cameraResolution: '720p',
        confidenceThreshold: 0.45,
        iouThreshold: 0.45,
        useGpu: !(useCustomModel && Platform.isAndroid),
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
        onModelError: (error, failedPath, _) {
          debugPrint(
            '[StuffFinder] Failed to load $failedPath for '
            '${finder.selectedTarget}: $error',
          );
          if (mounted) setState(() => _modelError = error);
        },
      ),
    );
  }

  Future<void> _pickTarget() async {
    final finder = _finder;
    if (finder == null) return;
    final target = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF101512),
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.88,
        child: CocoObjectPicker(selectedTarget: finder.selectedTarget),
      ),
    );
    if (target == null || !mounted) return;
    setState(() => _modelError = null);
    await finder.selectTarget(target);
    if (!mounted) return;
    // Announce the selection in the user's language for screen-reader users.
    final l10n = AppLocalizations.of(context);
    if (MediaQuery.supportsAnnounceOf(context)) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        l10n.sfStatusSearching(_titleCase(target)),
        widget.settings.isArabic ? TextDirection.rtl : TextDirection.ltr,
      );
    }
  }

  Future<void> _resume() async {
    final finder = _finder;
    if (finder?.selectedTarget == null) return;
    try {
      await _yoloController.resume();
    } on MissingPluginException {
      if (mounted) {
        setState(() => _modelError = 'YOLO camera plugin is unavailable');
      }
    }
    await finder?.start();
  }

  Future<void> _pause() async {
    try {
      await _yoloController.pause();
    } on MissingPluginException {
      // The platform view may already be detached during lifecycle teardown.
    }
    await _finder?.stop();
  }

  void _onFinderChanged() {
    if (mounted) setState(() {});
  }
}

class _TargetButton extends StatelessWidget {
  const _TargetButton({required this.finder, required this.onTap});

  final StuffFinderController finder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final target = finder.selectedTarget;
    return Semantics(
      button: true,
      label: target == null
          ? l10n.sfChooseObjectToFind
          : l10n.sfChangeTargetFrom(_titleCase(target)),
      child: FilledButton.icon(
        key: const ValueKey('stuff-finder-target-button'),
        onPressed: onTap,
        icon: Icon(target == null ? Icons.add : Icons.manage_search),
        label: Text(
          target == null
              ? l10n.sfChooseObject
              : l10n.sfFinding(_titleCase(target)),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electricGreen,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.finder});

  final StuffFinderController finder;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = _localizedStatus(l10n);
    return Semantics(
      liveRegion: true,
      label: text,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  String _localizedStatus(AppLocalizations l10n) {
    final target = finder.selectedTarget;
    return switch (finder.statusKind) {
      StuffFinderStatusKind.idle => l10n.sfStatusIdle,
      StuffFinderStatusKind.starting =>
        l10n.sfStatusStarting(finder.statusDetector ?? ''),
      StuffFinderStatusKind.searching =>
        l10n.sfStatusSearching(target == null ? '' : _titleCase(target)),
      StuffFinderStatusKind.matches =>
        l10n.sfStatusMatches(finder.statusMatchCount),
      StuffFinderStatusKind.pluginMissing => l10n.sfStatusPluginMissing,
      StuffFinderStatusKind.unavailable => l10n.sfStatusUnavailable,
      StuffFinderStatusKind.streamError => l10n.sfStatusStreamError,
    };
  }
}

String _titleCase(String value) {
  return value
      .split(' ')
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
