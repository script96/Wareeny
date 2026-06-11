import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/core/theme/app_spacing.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/read/ocr_controller.dart';
import 'package:wareeny/presentation/read/widgets/ocr_controls_bar.dart';
import 'package:wareeny/presentation/read/widgets/ocr_framing_overlay.dart';
import 'package:wareeny/presentation/read/widgets/scan_result_view.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/shared/ocr/ocr_models.dart';

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
  late final OcrController _ocr;
  bool _ocrReady = false;
  Object? _cameraError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ocrReady) {
      final services = AppScope.of(context);
      _ocr = OcrController(
        ocrBridge: services.ocrBridge,
      )..addListener(_onOcrChange);
      _ocrReady = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    if (_ocrReady) {
      _ocr
        ..removeListener(_onOcrChange)
        ..dispose();
    }
    _camera?.dispose();
    super.dispose();
  }

  void _onOcrChange() => setState(() {});

  void _cycleOcrSubModeForward() {
    _ocr.cycleSubMode();
    SemanticsService.announce(
      '${_ocr.subMode.label} active',
      TextDirection.ltr,
    );
  }

  void _cycleOcrSubModeBackward() {
    _ocr.cycleSubModePrevious();
    SemanticsService.announce(
      '${_ocr.subMode.label} active',
      TextDirection.ltr,
    );
  }

  @override
  Widget build(BuildContext context) {
    return TwoFingerSwipeDetector(
      onSwipeLeft: () => widget.onModeSelect(
          (AppMode.values.indexOf(AppMode.read) + 1) % AppMode.values.length),
      onSwipeRight: () => widget.onModeSelect(
          (AppMode.values.indexOf(AppMode.read) - 1) % AppMode.values.length),
      onSwipeUp: _cycleOcrSubModeForward,
      onSwipeDown: _cycleOcrSubModeBackward,
      child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleTap,
              child: _buildCameraLayer(),
            ),
            IgnorePointer(child: OcrFramingOverlay(cue: _ocr.framingCue)),
              if (_ocr.subMode == OcrReadingMode.document &&
                _ocr.lastResult != null &&
                !_ocr.lastResult!.isEmpty)
              Positioned(
                left: 24,
                right: 24,
                bottom: 120,
                child: IgnorePointer(
                  child: ScanResultView(text: _ocr.lastResult!.fullText),
                ),
              ),
            _TopHud(subMode: _ocr.subMode, onSelect: _ocr.setSubMode),
            const _RightActions(),
            _BottomArea(
              ocr: _ocr,
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
    if (cam == null || !cam.value.isInitialized || _ocr.isCapturing) return;
    final file = await cam.takePicture();
    // In all modes we start continuous reading; document mode uses chunked TTS,
    // others will eventually have specialised pipelines (currency, brand, qa).
    // For now all modes funnel through startReading so the user gets audio feedback.
    await _ocr.startReading(file.path);
    if (mounted) {
      SemanticsService.sendAnnouncement(
        View.of(context),
        '${_ocr.subMode.label} scan complete',
        TextDirection.ltr,
      );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _TopHud extends StatelessWidget {
  const _TopHud({required this.subMode, required this.onSelect});

  final OcrReadingMode subMode;
  final void Function(OcrReadingMode) onSelect;

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
            _OcrSubModeSelector(subMode: subMode, onSelect: onSelect),
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable row of OCR sub-mode pills.
class _OcrSubModeSelector extends StatelessWidget {
  const _OcrSubModeSelector({required this.subMode, required this.onSelect});

  final OcrReadingMode subMode;
  final void Function(OcrReadingMode) onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'OCR mode selector. Current: ${subMode.label}.',
      hint: 'Tap a mode to switch.',
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: OcrReadingMode.values.map((mode) {
                  final active = mode == subMode;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: _OcrModePill(
                      mode: mode,
                      active: active,
                      onTap: () => onSelect(mode),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OcrModePill extends StatelessWidget {
  const _OcrModePill({
    required this.mode,
    required this.active,
    required this.onTap,
  });

  final OcrReadingMode mode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: mode.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active ? AppColors.electricGreenDim : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: AppColors.electricGreen, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mode.icon,
                color: active ? AppColors.electricGreen : Colors.white54,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                mode.label.toUpperCase(),
                style: TextStyle(
                  color: active ? AppColors.electricGreen : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
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
    required this.ocr,
    required this.previousMode,
    required this.nextMode,
    required this.onPreviousTap,
    required this.onNextTap,
  });

  final OcrController ocr;
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
          child: ocr.isReadingActive
              ? OcrControlsBar(
                  onStop: ocr.stopReading,
                  onRepeat: ocr.repeatChunk,
                  onSkip: ocr.skipChunk,
                  onCancel: ocr.cancelReading,
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
