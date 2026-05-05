import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../services/camera_service.dart';
import '../../services/vision_service.dart';
import '../../services/speech_service.dart';
import '../../services/object_finder_types.dart';
import '../../detector.dart';
import '../../ocr_service.dart';
import '../widgets/bounding_box_painter.dart';
import '../widgets/action_menu.dart';
import '../widgets/target_picker.dart';
import 'dart:math' as math;

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

  StreamSubscription<String>? _statusSub;
  StreamSubscription<WareneMode>? _modeSub;
  StreamSubscription<ObjectFinderState>? _finderSub;

  // Mode state (driven by VisionService streams)
  WareneMode _currentMode = WareneMode.generalObjects;

  // Finder UI state
  bool _finderIsTracking = false;
  String? _finderTargetArabic;
  String? _finderHighlightLabel;

  // Triple-tap detection
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initAll();
  }

  // ══════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _handlePause();
    } else if (state == AppLifecycleState.resumed) {
      // If we are resuming but the camera is already alive, it means we
      // only went 'inactive' (e.g. opened a bottom sheet) and didn't
      // actually pause/dispose the camera. DO NOT re-initialize.
      if (!_camera.isInitialized) {
        _initAll();
      }
    }
    // 'inactive' is intentionally ignored to keep the camera alive behind menus.
  }

  Future<void> _handlePause() async {
    await _vision.handleAppPause();
    await _camera.dispose(); // must be awaited — avoids race with _initAll
    if (mounted) setState(() => _isInit = false);
  }

  Future<void> _initAll() async {
    if (mounted) setState(() => _statusText = 'جاري التشغيل...');

    // Retry init up to 3 times to survive brief _isDisposing windows
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

    // Subscribe to streams
    _statusSub?.cancel();
    _statusSub = _vision.statusStream.listen((status) {
      if (mounted) setState(() => _statusText = status);
    });

    _modeSub?.cancel();
    _modeSub = _vision.modeStream.listen(_handleModeChange);

    _finderSub?.cancel();
    _finderSub = _vision.finderStateStream.listen(_handleFinderState);

    // Restore mode (resume after background)
    await _vision.switchMode(_currentMode, speak: false);

    if (mounted) {
      setState(() {
        _isInit = true;
        _statusText = 'AI Ready ✓';
      });
    }

    if (_currentMode == WareneMode.documentQa && _vision.hasActiveQaDocument) {
      final msg = 'دبل تاب واسألني عن النص';
      if (mounted) setState(() => _statusText = msg);
      await _speech.speak(msg, throttle: false);
    } else {
      await _speech.speak('وَرِّينِي جَاهِز', throttle: false);
    }
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

  // ══════════════════════════════════════════════════════════════════
  //  GESTURE HANDLERS
  // ══════════════════════════════════════════════════════════════════

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

  void _onDoubleTap() async {
    if (_vision.isBusy) return;
    HapticFeedback.mediumImpact();
    if (_currentMode == WareneMode.documentQa) {
      final answer = await _vision.askDocumentQuestion();
      if (mounted) setState(() => _statusText = answer);
    } else {
      if (mounted) setState(() => _statusText = 'جاري الوصف...');
      final desc = await _vision.describeScene();
      if (mounted) setState(() => _statusText = desc);
    }
  }

  void _onSwipeRight() async {
    if (_vision.isBusy) return;
    if (_currentMode == WareneMode.documentQa) {
      _speech.speak('افتح القائمة لو عايز تخرج من سؤال النص',
          force: true, throttle: false);
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
    if (_currentMode == WareneMode.documentQa) {
      _speech.speak('اللغة ثابتة لحد ما تمسح نص جديد',
          force: true, throttle: false);
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _ocrLanguage = _ocrLanguage == OCRLanguage.english
          ? OCRLanguage.arabic
          : OCRLanguage.english;
    });
    _speech.speak(
      _ocrLanguage == OCRLanguage.arabic ? 'وَضْع عَرَبِي' : 'وَضْع إِنْجِلِيزِي',
      force: true,
      throttle: false,
    );
  }

  void _onLongPress() async {
    HapticFeedback.mediumImpact();

    final result = await showWareneActionMenu(
      context,
      currentMode: _currentMode,
    );

    // Force the native camera preview to unfreeze. On some Android devices,
    // showing an overlay/modal freezes the camera texture surface.
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
        final desc = await _vision.describeScene();
        if (mounted) setState(() => _statusText = desc);
        break;
      case ActionMenuResult.documentQa:
        if (mounted) setState(() => _statusText = 'جاري مسح النص...');
        final qaResult = await _vision.startDocumentQa(language: _ocrLanguage);
        if (mounted) setState(() => _statusText = qaResult);
        break;
      case ActionMenuResult.rescanDocumentQa:
        if (mounted) setState(() => _statusText = 'جاري مسح النص...');
        final rescanResult =
            await _vision.startDocumentQa(language: _ocrLanguage);
        if (mounted) setState(() => _statusText = rescanResult);
        break;
      case ActionMenuResult.exitDocumentQa:
        await _vision.endDocumentQa(resumeGeneral: true);
        break;
    }
  }

  void _onTripleTap() async {
    if (_vision.isBusy) return;
    if (_currentMode == WareneMode.documentQa) {
      _speech.speak('افتح القائمة لو عايز تخرج من سؤال النص',
          force: true, throttle: false);
      return;
    }
    HapticFeedback.heavyImpact();
    await _vision.switchMode(WareneMode.color);
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUILD — 3 INDEPENDENT LAYERS
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCameraPreview() {
    final controller = _camera.controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.previewSize == null) {
      return const Positioned.fill(
        child: ColoredBox(
          color: Colors.red,
          child: Center(
            child: Text(
              'CAMERA PREVIEW UNAVAILABLE',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(
            controller,
            key: ValueKey(controller.cameraId),
          ),
        ),
      ),
    );
  }

  Widget _buildDetectionOverlay() {
    if (_currentMode == WareneMode.color ||
        _currentMode == WareneMode.objectFinderSmart ||
        _currentMode == WareneMode.documentQa) {
      return const SizedBox.shrink();
    }

    final isFinder = _currentMode == WareneMode.objectFinderFast;

    return Positioned.fill(
      child: StreamBuilder<List<Detection>>(
        stream: _vision.detectionStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final controller = _camera.controller;
              if (controller == null ||
                  !controller.value.isInitialized ||
                  controller.value.previewSize == null) {
                return const SizedBox.shrink();
              }

              final previewSize = controller.value.previewSize!;
              final previewW = previewSize.height;
              final previewH = previewSize.width;
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;
              final scale = math.max(screenW / previewW, screenH / previewH);
              final displayW = previewW * scale;
              final displayH = previewH * scale;
              final offsetX = (screenW - displayW) / 2;
              final offsetY = (screenH - displayH) / 2;

              return CustomPaint(
                size: Size(screenW, screenH),
                painter: BoundingBoxPainter(
                  detections: snapshot.data!,
                  sourceWidth: _vision.sourceWidth,
                  sourceHeight: _vision.sourceHeight,
                  displayWidth: displayW,
                  displayHeight: displayH,
                  offsetX: offsetX,
                  offsetY: offsetY,
                  highlightLabel: isFinder ? _finderHighlightLabel : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildTopUi() {
    final isFinder = _currentMode == WareneMode.objectFinderFast ||
        _currentMode == WareneMode.objectFinderSmart;
    final isColor = _currentMode == WareneMode.color;
    final isQa = _currentMode == WareneMode.documentQa;

    return [
      Positioned(
        top: 48,
        left: 0,
        right: 0,
        child: Center(
          child: Text(
            'وريني',
            style: TextStyle(
              color: Colors.white.withAlpha(200),
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
          ),
        ),
      ),

      Positioned(
        top: 48,
        left: 16,
        child: _ModeBadge(
          text: _modeBadgeText(),
          color: _modeBadgeColor(),
          isPulsing: isFinder,
        ),
      ),

      if (!isFinder && !isColor && !isQa)
        StreamBuilder<List<Detection>>(
          stream: _vision.detectionStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned(
              top: 48,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${snapshot.data!.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),

      Positioned(
        bottom: 100,
        left: 20,
        right: 20,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(180),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _statusText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),

      Positioned(
        bottom: 30,
        left: 0,
        right: 0,
        child: Center(
          child: Text(
            isQa
                ? 'نقرتين: اسأل سؤال  •  مطول: القائمة'
                : 'مطول: القائمة  •  نقرتين: وصف  •  سحب: تبديل',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 11,
            ),
          ),
        ),
      ),
    ];
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.greenAccent),
              const SizedBox(height: 24),
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
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
              _buildCameraPreview(),
              _buildDetectionOverlay(),
              ..._buildTopUi(),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  MODE BADGE with optional pulse animation
// ══════════════════════════════════════════════════════════════════

class _ModeBadge extends StatefulWidget {
  final String text;
  final Color color;
  final bool isPulsing;

  const _ModeBadge({
    required this.text,
    required this.color,
    this.isPulsing = false,
  });

  @override
  State<_ModeBadge> createState() => _ModeBadgeState();
}

class _ModeBadgeState extends State<_ModeBadge>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant _ModeBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPulsing != widget.isPulsing) {
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    if (widget.isPulsing) {
      _controller ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1200),
      );
      _opacity = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      );
      _controller!.repeat(reverse: true);
    } else {
      _controller?.stop();
      _controller?.dispose();
      _controller = null;
      _opacity = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.color.withAlpha(180),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        widget.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    if (_opacity != null && _controller != null) {
      return AnimatedBuilder(
        animation: _opacity!,
        builder: (context, child) {
          return Opacity(opacity: _opacity!.value, child: badge);
        },
      );
    }

    return badge;
  }
}
