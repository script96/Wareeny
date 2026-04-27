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

  // Finder UI state — target name persists while in finder mode,
  // highlight label only set when target is visible (tracking).
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
        state == AppLifecycleState.inactive) {
      _handlePause();
    } else if (state == AppLifecycleState.resumed) {
      _initAll();
    }
  }

  void _handlePause() {
    _vision.stopAllTimers();
    _camera.dispose();
    if (mounted) setState(() => _isInit = false);
  }

  Future<void> _initAll() async {
    if (mounted) setState(() => _statusText = 'جاري التشغيل...');

    final cameraOk = await _camera.init();
    if (!mounted) return;

    if (!cameraOk) {
      setState(() => _statusText = 'خطأ في الكاميرا');
      return;
    }

    await _vision.init();

    // Listen to status updates
    _statusSub?.cancel();
    _statusSub = _vision.statusStream.listen((status) {
      if (mounted) setState(() => _statusText = status);
    });

    // Listen to mode changes
    _modeSub?.cancel();
    _modeSub = _vision.modeStream.listen(_handleModeChange);

    // Listen to finder state
    _finderSub?.cancel();
    _finderSub = _vision.finderStateStream.listen(_handleFinderState);

    // Start in current mode (restore after resume)
    await _vision.switchMode(_currentMode, speak: false);

    if (mounted) {
      setState(() {
        _isInit = true;
        _statusText = 'AI Ready ✓';
      });
    }
    await _speech.speak('وَرِّينِي جَاهِز', throttle: false);
  }

  void _handleModeChange(WareneMode newMode) {
    if (!mounted) return;
    setState(() {
      _currentMode = newMode;
      // Clear finder UI ONLY when leaving finder mode
      if (newMode != WareneMode.objectFinderFast &&
          newMode != WareneMode.objectFinderSmart) {
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
        // Target not visible — keep target name, clear highlight
        setState(() {
          _finderTargetArabic = state.targetArabicName;
          _finderHighlightLabel = null;
          _finderIsTracking = false;
        });
        break;

      case ObjectFinderStatus.tracking:
        // Target visible — haptic only on transition
        if (!_finderIsTracking) {
          HapticFeedback.heavyImpact();
        }
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

  /// VisionService is an app-lifetime singleton,
  /// so we only stop its timers here, not call _vision.dispose().
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
    if (mounted) setState(() => _statusText = 'جاري الوصف...');
    final desc = await _vision.describeScene();
    if (mounted) setState(() => _statusText = desc);
  }

  void _onSwipeRight() async {
    if (_vision.isBusy) return;
    HapticFeedback.lightImpact();
    final newMode = _currentMode == WareneMode.currency
        ? WareneMode.generalObjects
        : WareneMode.currency;
    await _vision.switchMode(newMode);
  }

  void _onSwipeLeft() {
    if (_vision.isBusy) return;
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
    }
  }

  void _onTripleTap() async {
    if (_vision.isBusy) return;
    HapticFeedback.heavyImpact();
    await _vision.switchMode(WareneMode.color);
  }

  // ══════════════════════════════════════════════════════════════════
  //  BUILD — 3 INDEPENDENT LAYERS
  // ══════════════════════════════════════════════════════════════════

  /// Layer 1: Camera preview — always visible when initialized.
  /// Not inside any StreamBuilder. Never depends on detection or mode state.
  Widget _buildCameraPreview() {
    final controller = _camera.controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Positioned.fill(
        child: ColoredBox(color: Colors.black),
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  /// Layer 2: Detection overlay — bounding boxes on top of preview.
  /// Hidden in color mode and smart finder mode (no YOLO boxes).
  /// Returns SizedBox.shrink() when no boxes to draw.
  Widget _buildDetectionOverlay() {
    if (_currentMode == WareneMode.color ||
        _currentMode == WareneMode.objectFinderSmart) {
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
              if (controller == null || !controller.value.isInitialized) {
                return const SizedBox.shrink();
              }

              final previewSize = controller.value.previewSize!;
              final previewW = previewSize.height;
              final previewH = previewSize.width;
              final screenW = constraints.maxWidth;
              final screenH = constraints.maxHeight;
              final scale =
                  math.max(screenW / previewW, screenH / previewH);
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
                  highlightLabel:
                      isFinder ? _finderHighlightLabel : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Layer 3: Top UI — badges, status, hints. Independent of preview.
  List<Widget> _buildTopUi() {
    final isFinder = _currentMode == WareneMode.objectFinderFast ||
        _currentMode == WareneMode.objectFinderSmart;
    final isColor = _currentMode == WareneMode.color;

    return [
      // App title
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

      // Mode badge
      Positioned(
        top: 48,
        left: 16,
        child: _ModeBadge(
          text: _modeBadgeText(),
          color: _modeBadgeColor(),
          isPulsing: isFinder,
        ),
      ),

      // Detection count badge — only for general/currency
      if (!isFinder && !isColor)
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
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

      // Status bar
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),

      // Gesture hints
      Positioned(
        bottom: 30,
        left: 0,
        right: 0,
        child: Center(
          child: Text(
            'مطول: القائمة  •  نقرتين: وصف  •  سحب: تبديل',
            style: TextStyle(
              color: Colors.white.withAlpha(120),
              fontSize: 11,
            ),
          ),
        ),
      ),
    ];
  }

  // ── Mode badge helpers ──

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
        // 3 independent layers — preview never depends on detections
        child: Stack(
          children: [
            _buildCameraPreview(),     // Layer 1: always visible
            _buildDetectionOverlay(),  // Layer 2: boxes only
            ..._buildTopUi(),          // Layer 3: badges, status
          ],
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
