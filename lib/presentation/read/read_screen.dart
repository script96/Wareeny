import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:wareeny/core/di/app_scope.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/navigation/app_mode.dart';
import 'package:wareeny/presentation/read/vlm_read_controller.dart';
import 'package:wareeny/presentation/read/widgets/ocr_controls_bar.dart';
import 'package:wareeny/presentation/read/widgets/reading_status_pill.dart';
import 'package:wareeny/presentation/reusable/camera_side_actions.dart';
import 'package:wareeny/presentation/reusable/camera_top_bar.dart';
import 'package:wareeny/presentation/reusable/mode_carousel_bar.dart';
import 'package:wareeny/presentation/reusable/two_finger_swipe_detector.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/presentation/voice/voice_interaction_controller.dart';

class ReadScreen extends StatefulWidget {
  const ReadScreen({
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
  State<ReadScreen> createState() => _ReadScreenState();
}

class _ReadScreenState extends State<ReadScreen> {
  CameraController? _camera;
  late final VlmReadController _read;
  VoiceInteractionController? _voiceInteraction;
  bool _readReady = false;
  bool _wasCapturingSpeech = false;
  Object? _cameraError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_readReady) {
      final services = AppScope.of(context);
      _read = VlmReadController(
        assistant: services.vlmAssistant,
        audioHaptics: services.audioHapticsBridge,
        unavailableMessage: AppLocalizations.of(context).readUnavailable,
      )..addListener(_onReadChange);
      _voiceInteraction = services.voiceInteractionController
        ..addListener(_onVoiceInteractionChange);
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
    _voiceInteraction?.removeListener(_onVoiceInteractionChange);
    _camera?.dispose();
    super.dispose();
  }

  void _onReadChange() => setState(() {});

  void _onVoiceInteractionChange() {
    final capturing = _voiceInteraction?.isCapturingSpeech ?? false;
    if (capturing && !_wasCapturingSpeech) {
      _read.stopReading();
    }
    _wasCapturingSpeech = capturing;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final modeActions = AppMode.read.getModeSwitchActions(
      l10n: l10n,
      settings: widget.settings,
      onModeSelect: widget.onModeSelect,
    );
    modeActions[CustomSemanticsAction(label: l10n.askButton)] = _handleAsk;

    return TwoFingerSwipeDetector(
      onSwipeLeft: () => widget.onModeSelect(
        (AppMode.values.indexOf(AppMode.read) + 1) % AppMode.values.length,
      ),
      onSwipeRight: () => widget.onModeSelect(
        (AppMode.values.indexOf(AppMode.read) - 1) % AppMode.values.length,
      ),
      child: Semantics(
        label: l10n.activeModeNamed(AppMode.read.labelFor(l10n)),
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
                onLongPress: _handleAsk,
                child: _buildCameraLayer(),
              ),
            ),
            if (_read.isThinking)
              IgnorePointer(
                child: ReadingStatusPill(label: l10n.readingStatus),
              ),
            const _TopHud(),
            _RightActions(onAsk: _handleAsk, askLabel: l10n.askButton),
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
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraError != null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(
            Icons.videocam_off_outlined,
            color: Colors.white38,
            size: 48,
          ),
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
    await _read.startReading(file.path);
  }

  /// QA: freeze the current frame, listen for a spoken question, then answer it.
  Future<void> _handleAsk() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized || _read.isThinking) return;
    final l10n = AppLocalizations.of(context);
    final voice = AppScope.of(context).voiceInteractionController;
    final file = await cam.takePicture();
    final question = await voice.listenForQuestion(l10n.askPrompt);
    if (!mounted) return;
    if (question == null || question.trim().isEmpty) return;
    await _read.ask(
      file.path,
      question,
      unavailableMessage: l10n.askUnavailable,
      answerInArabic: widget.settings.isArabic,
    );
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
        child: CameraTopBar(currentMode: AppMode.read),
      ),
    );
  }
}

class _RightActions extends StatelessWidget {
  const _RightActions({this.onAsk, this.askLabel});

  final VoidCallback? onAsk;
  final String? askLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: SafeArea(
          child: CameraSideActions(onAsk: onAsk, askLabel: askLabel),
        ),
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
