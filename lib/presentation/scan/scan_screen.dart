import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/read/vlm_read_controller.dart';
import 'package:wareeny/presentation/read/widgets/reading_status_pill.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/scan_result_view.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';

/// One-tap identify: point, tap, hear one spoken sentence about the thing —
/// object, money (total + breakdown), or a packaged product read off its label.
/// Reuses [VlmReadController.scan] (the `scan` VLM task); no playback controls,
/// just a "Repeat result" gesture/action for blind users who miss the answer.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    required this.previousMode,
    required this.nextMode,
    required this.onModeSelect,
    required this.settings,
    super.key,
  });

  final AppMode previousMode;
  final AppMode nextMode;
  final void Function(int index) onModeSelect;
  final SettingsController settings;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  CameraController? _camera;
  late final VlmReadController _scan;
  bool _scanReady = false;
  Object? _cameraError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_scanReady) {
      final services = AppScope.of(context);
      _scan = VlmReadController(
        assistant: services.vlmAssistant,
        audioHaptics: services.audioHapticsBridge,
        unavailableMessage: AppLocalizations.of(context).scanUnavailable,
      )..addListener(_onScanChange);
      _scanReady = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    if (_scanReady) {
      _scan
        ..removeListener(_onScanChange)
        ..dispose();
    }
    _camera?.dispose();
    super.dispose();
  }

  void _onScanChange() => setState(() {});

  bool get _isScreenReaderActive =>
      MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final modeActions = AppMode.scan.getModeSwitchActions(
      l10n: l10n,
      settings: widget.settings,
      onModeSelect: widget.onModeSelect,
    );
    modeActions[CustomSemanticsAction(label: l10n.repeatResult)] =
        _scan.repeatChunk;

    final scanIndex = AppMode.values.indexOf(AppMode.scan);

    return TwoFingerSwipeDetector(
      onSwipeLeft: () =>
          widget.onModeSelect((scanIndex + 1) % AppMode.values.length),
      onSwipeRight: () =>
          widget.onModeSelect((scanIndex - 1) % AppMode.values.length),
      onSwipeUp: _scan.repeatChunk,
      child: Semantics(
        label: l10n.activeModeNamed(AppMode.scan.labelFor(l10n)),
        customSemanticsActions: modeActions,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: l10n.tapToCaptureHint,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                child: _buildCameraLayer(),
              ),
            ),
            if (_scan.isThinking)
              IgnorePointer(
                child: ReadingStatusPill(label: l10n.scanningStatus),
              ),
            if (_scan.streamedText.isNotEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 120,
                child: IgnorePointer(
                  ignoring: !_isScreenReaderActive,
                  child: ScanResultView(text: _scan.streamedText),
                ),
              ),
            const _TopHud(),
            const _RightActions(),
            _BottomArea(
              previousMode: widget.previousMode,
              nextMode: widget.nextMode,
              onPreviousTap: () =>
                  widget.onModeSelect((scanIndex - 1) % AppMode.values.length),
              onNextTap: () =>
                  widget.onModeSelect((scanIndex + 1) % AppMode.values.length),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraError != null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_off_outlined, color: Colors.white38, size: 48),
        ),
      );
    }
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: cam.value.previewSize!.height,
            height: cam.value.previewSize!.width,
            child: CameraPreview(cam),
          ),
        ),
      ),
    );
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (e) {
      if (mounted) setState(() => _cameraError = e);
    }
  }

  Future<void> _handleTap() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _scan.isThinking) return;
    final file = await cam.takePicture();
    await _scan.scan(file.path);
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  const _TopHud();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: CameraTopBar(currentMode: AppMode.scan),
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  const _RightActions();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: SafeArea(child: const CameraSideActions()),
      ),
    );
  }
}

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.previousMode,
    required this.nextMode,
    required this.onPreviousTap,
    required this.onNextTap,
  });

  final AppMode previousMode;
  final AppMode nextMode;
  final VoidCallback onPreviousTap;
  final VoidCallback onNextTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Center(
          child: ModeCarouselBar(
            previous: previousMode,
            current: AppMode.scan,
            next: nextMode,
            onPreviousTap: onPreviousTap,
            onNextTap: onNextTap,
          ),
        ),
      ),
    );
  }
}
