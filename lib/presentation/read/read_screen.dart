import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/read/vlm_read_controller.dart';
import 'package:wareeny/presentation/read/widgets/ocr_controls_bar.dart';
import 'package:wareeny/presentation/read/widgets/reading_status_pill.dart';
import 'package:wareeny/presentation/read/widgets/scan_result_view.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';

class ReadScreen extends StatefulWidget {
  const ReadScreen({
    required this.previousMode,
    required this.nextMode,
    required this.onModeSelect,
    super.key,
  });

  final AppMode previousMode;
  final AppMode nextMode;
  final void Function(int index) onModeSelect;

  @override
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  CameraController? _camera;
  late final VlmReadController _read;
  bool _readReady = false;
  Object? _cameraError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readReady) {
      final services = AppScope.of(context);
      _read = VlmReadController(
        assistant: services.vlmAssistant,
        audioHaptics: services.audioHapticsBridge,
      )..addListener(_onReadChange);
      _readReady = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    if (_readReady) {
      _read
        ..removeListener(_onReadChange)
        ..dispose();
    }
    _camera?.dispose();
    super.dispose();
  }

  void _onReadChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return TwoFingerSwipeDetector(
      onSwipeLeft: () => widget.onModeSelect(
          (AppMode.values.indexOf(AppMode.read) + 1) % AppMode.values.length),
      onSwipeRight: () => widget.onModeSelect(
          (AppMode.values.indexOf(AppMode.read) - 1) % AppMode.values.length),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            child: _buildCameraLayer(),
          ),
          if (_read.isThinking)
            const IgnorePointer(child: ReadingStatusPill(label: 'Reading…')),
          if (_read.subMode == ReadSubMode.scan && _read.streamedText.isNotEmpty)
            Positioned(
              left: 24,
              right: 24,
              bottom: 120,
              child: IgnorePointer(
                child: ScanResultView(text: _read.streamedText),
              ),
            ),
          _TopHud(subMode: _read.subMode, onToggle: _read.toggleSubMode),
          const _RightActions(),
          _BottomArea(
            read: _read,
            previousMode: widget.previousMode,
            nextMode: widget.nextMode,
            onPreviousTap: () => widget.onModeSelect(
              (AppMode.values.indexOf(AppMode.read) - 1) %
                  AppMode.values.length,
            ),
            onNextTap: () => widget.onModeSelect(
              (AppMode.values.indexOf(AppMode.read) + 1) %
                  AppMode.values.length,
            ),
          ),
        ],
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
    if (cam == null || !cam.value.isInitialized || _read.isThinking) return;
    final file = await cam.takePicture();
    if (_read.subMode == ReadSubMode.scan) {
      await _read.scan(file.path);
      if (mounted) {
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Scan complete',
          TextDirection.ltr,
        );
      }
    } else {
      await _read.startReading(file.path);
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  const _TopHud({required this.subMode, required this.onToggle});

  final ReadSubMode subMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          children: [
            const CameraTopBar(currentMode: AppMode.read),
            const SizedBox(height: AppSpacing.sm),
            _SubModeToggle(subMode: subMode, onToggle: onToggle),
          ],
        ),
      ),
    );
  }
}

class _SubModeToggle extends StatelessWidget {
  const _SubModeToggle({required this.subMode, required this.onToggle});

  final ReadSubMode subMode;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Switch to ${subMode == ReadSubMode.scan ? "Read" : "Scan"} mode',
      child: GestureDetector(
        onTap: onToggle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs + 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.glassWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Pill(
                    label: 'SCAN',
                    active: subMode == ReadSubMode.scan,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _Pill(
                    label: 'READ',
                    active: subMode == ReadSubMode.read,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: active ? AppColors.electricGreenDim : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: active
            ? Border.all(color: AppColors.electricGreen, width: 1)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.electricGreen : Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
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
    required this.read,
    required this.previousMode,
    required this.nextMode,
    required this.onPreviousTap,
    required this.onNextTap,
  });

  final VlmReadController read;
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
          child: read.isReadingActive
              ? OcrControlsBar(
                  onStop: read.stopReading,
                  onRepeat: read.repeatChunk,
                  onSkip: read.skipChunk,
                  onCancel: read.cancel,
                )
              : ModeCarouselBar(
                  previous: previousMode,
                  current: AppMode.read,
                  next: nextMode,
                  onPreviousTap: onPreviousTap,
                  onNextTap: onNextTap,
                ),
        ),
      ),
    );
  }
}
