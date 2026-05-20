import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../ocr_service.dart';
import '../../services/camera_service.dart';
import '../../services/object_finder_types.dart';
import '../../services/speech_service.dart';
import '../../services/vision_service.dart';
import '../theme/app_colors.dart';
import '../widgets/reusable/app_loading_view.dart';
import '../widgets/sheets/action_menu.dart';
import '../widgets/sheets/target_picker.dart';
import 'camera/widgets/camera_brand_title.dart';
import 'camera/widgets/camera_detection_count_badge.dart';
import 'camera/widgets/camera_detection_overlay.dart';
import 'camera/widgets/camera_footer_hint.dart';
import 'camera/widgets/camera_mode_badge.dart';
import 'camera/widgets/camera_preview_layer.dart';
import 'camera/widgets/camera_status_panel.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final VisionService _vision = VisionService();
  final CameraService _camera = CameraService();
  final SpeechService _speech = SpeechService();

  bool _isInit = false;
  String _statusText = 'جاري التشغيل...';
  OCRLanguage _ocrLanguage = OCRLanguage.english;
  WareneMode _currentMode = WareneMode.generalObjects;
  bool _finderIsTracking = false;
  String? _finderTargetArabic;
  String? _finderHighlightLabel;
  int _tapCount = 0;
  Timer? _tapTimer;
  StreamSubscription<String>? _statusSub;
  StreamSubscription<WareneMode>? _modeSub;
  StreamSubscription<ObjectFinderState>? _finderSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initAll();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handlePause();
    } else if (state == AppLifecycleState.resumed && !_camera.isInitialized) {
      _initAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _tapTimer?.cancel();
    _statusSub?.cancel();
    _modeSub?.cancel();
    _finderSub?.cancel();
    _vision.stopAllTimers();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _handlePause() async {
    await _vision.handleAppPause();
    await _camera.dispose();
    if (mounted) setState(() => _isInit = false);
  }

  Future<void> _initAll() async {
    if (mounted) setState(() => _statusText = 'جاري التشغيل...');

    bool cameraOk = false;
    for (int attempt = 0; attempt < 3; attempt++) {
      cameraOk = await _camera.init();
      if (cameraOk) break;
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    if (!cameraOk) {
      setState(() => _statusText = 'خطأ في الكاميرا');
      return;
    }

    await _vision.init();
    _bindStreams();
    await _vision.switchMode(_currentMode, speak: false);

    if (mounted) {
      setState(() {
        _isInit = true;
        _statusText = 'AI Ready ✓';
      });
    }

    if (_currentMode == WareneMode.documentQa && _vision.hasActiveQaDocument) {
      const message = 'دبل تاب واسألني عن النص';
      if (mounted) setState(() => _statusText = message);
      await _speech.speak(message, throttle: false);
    } else if (!Platform.isIOS) {
      await _speech.speak('وَرِّينِي جَاهِز', throttle: false);
    }
  }

  void _bindStreams() {
    _statusSub?.cancel();
    _statusSub = _vision.statusStream.listen((status) {
      if (mounted) setState(() => _statusText = status);
    });

    _modeSub?.cancel();
    _modeSub = _vision.modeStream.listen(_handleModeChange);

    _finderSub?.cancel();
    _finderSub = _vision.finderStateStream.listen(_handleFinderState);
  }

  void _handleModeChange(WareneMode newMode) {
    if (!mounted) return;
    setState(() {
      _currentMode = newMode;
      if ((newMode != WareneMode.objectFinderFast &&
              newMode != WareneMode.objectFinderSmart) ||
          newMode == WareneMode.documentQa) {
        _finderIsTracking = false;
        _finderTargetArabic = null;
        _finderHighlightLabel = null;
      }
    });
  }

  void _handleFinderState(ObjectFinderState state) {
    if (!mounted) return;

    switch (state.status) {
      case ObjectFinderStatus.searching:
        setState(() {
          _finderTargetArabic = state.targetArabicName;
          _finderHighlightLabel = null;
          _finderIsTracking = false;
        });
        break;
      case ObjectFinderStatus.tracking:
        if (!_finderIsTracking) HapticFeedback.heavyImpact();
        setState(() {
          _finderIsTracking = true;
          _finderHighlightLabel = state.targetLabel;
          _finderTargetArabic = state.targetArabicName;
        });
        break;
      case ObjectFinderStatus.error:
        HapticFeedback.mediumImpact();
        setState(() {
          _finderIsTracking = false;
          _finderTargetArabic = null;
          _finderHighlightLabel = null;
        });
        break;
      case ObjectFinderStatus.inactive:
        setState(() {
          _finderIsTracking = false;
          _finderTargetArabic = null;
          _finderHighlightLabel = null;
        });
        break;
    }
  }

  void _onTap() {
    _tapCount++;
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 400), () {
      final count = _tapCount;
      _tapCount = 0;
      if (count == 2) {
        _onDoubleTap();
      } else if (count >= 3) {
        _onTripleTap();
      }
    });
  }

  Future<void> _onDoubleTap() async {
    if (_vision.isBusy) return;
    HapticFeedback.mediumImpact();
    if (_currentMode == WareneMode.indoorNavigation) {
      await _speech.speak(
        'الملاحة شغالة. افتح القائمة لو عايز تغير الوضع',
        force: true,
        throttle: false,
      );
      return;
    }
    if (_currentMode == WareneMode.documentQa) {
      final answer = await _vision.askDocumentQuestion();
      if (mounted) setState(() => _statusText = answer);
      return;
    }

    if (mounted) setState(() => _statusText = 'جاري الوصف...');
    final description = await _vision.describeScene();
    if (mounted) setState(() => _statusText = description);
  }

  Future<void> _onSwipeRight() async {
    if (_vision.isBusy) return;
    if (_currentMode == WareneMode.documentQa ||
        _currentMode == WareneMode.indoorNavigation) {
      _speech.speak(
        _currentMode == WareneMode.documentQa
            ? 'افتح القائمة لو عايز تخرج من سؤال النص'
            : 'افتح القائمة لو عايز تغير وضع الملاحة الداخلية',
        force: true,
        throttle: false,
      );
      return;
    }

    HapticFeedback.lightImpact();
    final newMode = _currentMode == WareneMode.currency
        ? WareneMode.generalObjects
        : WareneMode.currency;
    await _vision.switchMode(newMode);
  }

  void _onSwipeLeft() {
    if (_vision.isBusy) return;
    if (_currentMode == WareneMode.documentQa ||
        _currentMode == WareneMode.indoorNavigation) {
      _speech.speak(
        _currentMode == WareneMode.documentQa
            ? 'اللغة ثابتة لحد ما تمسح نص جديد'
            : 'اللغة ثابتة في الملاحة الداخلية',
        force: true,
        throttle: false,
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _ocrLanguage = _ocrLanguage == OCRLanguage.english
          ? OCRLanguage.arabic
          : OCRLanguage.english;
    });
    _speech.speak(
      _ocrLanguage == OCRLanguage.arabic
          ? 'وَضْع عَرَبِي'
          : 'وَضْع إِنْجِلِيزِي',
      force: true,
      throttle: false,
    );
  }

  Future<void> _onLongPress() async {
    HapticFeedback.mediumImpact();

    final result = await showWareneActionMenu(
      context,
      currentMode: _currentMode,
    );

    try {
      await _camera.controller?.resumePreview();
    } catch (_) {}

    if (result == null || !mounted) return;

    switch (result) {
      case ActionMenuResult.generalObjects:
        await _vision.switchMode(WareneMode.generalObjects);
        break;
      case ActionMenuResult.currency:
        await _vision.switchMode(WareneMode.currency);
        break;
      case ActionMenuResult.indoorNavigation:
        await _vision.switchMode(WareneMode.indoorNavigation);
        break;
      case ActionMenuResult.findObject:
        final target = await showTargetPicker(context);
        try {
          await _camera.controller?.resumePreview();
        } catch (_) {}
        if (target != null && mounted) {
          final mode = target.mode == ObjectFinderMode.fastYolo
              ? WareneMode.objectFinderFast
              : WareneMode.objectFinderSmart;
          await _vision.switchMode(mode, target: target);
        }
        break;
      case ActionMenuResult.colorMode:
        await _vision.switchMode(WareneMode.color);
        break;
      case ActionMenuResult.readText:
        if (mounted) setState(() => _statusText = 'جاري القراءة...');
        final text = await _vision.readText(language: _ocrLanguage);
        if (mounted) setState(() => _statusText = text);
        break;
      case ActionMenuResult.describeScene:
        if (mounted) setState(() => _statusText = 'جاري الوصف...');
        final description = await _vision.describeScene();
        if (mounted) setState(() => _statusText = description);
        break;
      case ActionMenuResult.documentQa:
      case ActionMenuResult.rescanDocumentQa:
        if (mounted) setState(() => _statusText = 'جاري مسح النص...');
        final result = await _vision.startDocumentQa(language: _ocrLanguage);
        if (mounted) setState(() => _statusText = result);
        break;
      case ActionMenuResult.exitDocumentQa:
        await _vision.endDocumentQa(resumeGeneral: true);
        break;
    }
  }

  Future<void> _onTripleTap() async {
    if (_vision.isBusy) return;
    if (_currentMode == WareneMode.documentQa ||
        _currentMode == WareneMode.indoorNavigation) {
      _speech.speak(
        _currentMode == WareneMode.documentQa
            ? 'افتح القائمة لو عايز تخرج من سؤال النص'
            : 'افتح القائمة لو عايز تخرج من الملاحة الداخلية',
        force: true,
        throttle: false,
      );
      return;
    }

    HapticFeedback.heavyImpact();
    await _vision.switchMode(WareneMode.color);
  }

  Color _modeBadgeColor() {
    switch (_currentMode) {
      case WareneMode.generalObjects:
        return Colors.blue;
      case WareneMode.currency:
        return Colors.amber;
      case WareneMode.objectFinderFast:
      case WareneMode.objectFinderSmart:
        return Colors.orange;
      case WareneMode.color:
        return Colors.purple;
      case WareneMode.documentQa:
        return Colors.teal;
      case WareneMode.indoorNavigation:
        return Colors.lightGreen;
    }
  }

  String _modeBadgeText() {
    switch (_currentMode) {
      case WareneMode.generalObjects:
        return '👁 أشياء';
      case WareneMode.currency:
        return '💵 فلوس';
      case WareneMode.objectFinderFast:
      case WareneMode.objectFinderSmart:
        return '🔍 ${_finderTargetArabic ?? 'بحث'}';
      case WareneMode.color:
        return '🎨 ألوان';
      case WareneMode.documentQa:
        return '❓ سؤال عن نص';
      case WareneMode.indoorNavigation:
        return '🧭 ملاحة داخلية';
    }
  }

  bool get _showsDetectionOverlay {
    return _currentMode != WareneMode.color &&
        _currentMode != WareneMode.objectFinderSmart &&
        _currentMode != WareneMode.documentQa;
  }

  bool get _isFinderMode {
    return _currentMode == WareneMode.objectFinderFast ||
        _currentMode == WareneMode.objectFinderSmart;
  }

  bool get _isQaMode => _currentMode == WareneMode.documentQa;

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: AppLoadingView(message: _statusText)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: _onTap,
        onLongPress: _onLongPress,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! > 200) {
            _onSwipeRight();
          } else if (details.primaryVelocity! < -200) {
            _onSwipeLeft();
          }
        },
        child: SizedBox.expand(
          child: Stack(
            children: [
              CameraPreviewLayer(controller: _camera.controller),
              CameraDetectionOverlay(
                detectionStream: _vision.detectionStream,
                controller: _camera.controller,
                sourceWidth: _vision.sourceWidth,
                sourceHeight: _vision.sourceHeight,
                highlightLabel: _isFinderMode ? _finderHighlightLabel : null,
                isVisible: _showsDetectionOverlay,
              ),
              const CameraBrandTitle(),
              Positioned(
                top: 48,
                left: 16,
                child: CameraModeBadge(
                  text: _modeBadgeText(),
                  color: _modeBadgeColor(),
                  isPulsing: _isFinderMode,
                ),
              ),
              CameraDetectionCountBadge(
                detectionStream: _vision.detectionStream,
                isVisible:
                    !_isFinderMode &&
                    _currentMode != WareneMode.color &&
                    !_isQaMode,
              ),
              CameraStatusPanel(statusText: _statusText),
              CameraFooterHint(isQa: _isQaMode),
            ],
          ),
        ),
      ),
    );
  }
}
