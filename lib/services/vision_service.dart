import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import '../detector.dart';
import '../gemini_service.dart';
import '../ocr_service.dart';
import 'camera_service.dart';
import 'speech_service.dart';
import 'color_service.dart';
import 'object_finder_types.dart';

class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  final YoloDetector _detector = YoloDetector();
  final GeminiService _gemini = GeminiService();
  final CameraService _camera = CameraService();
  final SpeechService _speech = SpeechService();
  final ColorService _color = ColorService();
  final OCRService _ocr = OCRService();

  // ── Central mode state ──

  WareneMode _mode = WareneMode.generalObjects;
  WareneMode get mode => _mode;

  final _modeController = StreamController<WareneMode>.broadcast();
  Stream<WareneMode> get modeStream => _modeController.stream;

  // ── Operation lock ──

  bool _isSwitchingMode = false;
  bool _isDetecting = false;
  Completer<void>? _activeDetectionCompleter;

  /// True when a one-shot action (OCR, scene) is running.
  bool _isOneShot = false;
  bool get isBusy => _isSwitchingMode || _isOneShot;

  // ── YOLO state ──

  DetectionModel _currentModel = DetectionModel.general;
  DetectionModel get currentModel => _currentModel;
  Timer? _detectionTimer;

  /// Announcement throttle — don't repeat same description within 3s.
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Detection frame persistence — only clear boxes after N consecutive empty.
  int _emptyFrameCount = 0;

  // ── Public detection state ──

  List<Detection> currentDetections = [];
  int sourceWidth = 1;
  int sourceHeight = 1;
  String statusText = '';

  final _detectionController = StreamController<List<Detection>>.broadcast();
  Stream<List<Detection>> get detectionStream => _detectionController.stream;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  // ── Object Finder state (subordinate to mode) ──

  ObjectFinderTarget? _finderTarget;
  ObjectFinderTarget? get finderTarget => _finderTarget;
  Timer? _smartFinderTimer;
  bool _isSmartFinderProcessing = false;
  DateTime _finderStartedAt = DateTime.now();
  DateTime _lastFinderHintAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Hard timeout for Smart Finder (2 minutes).
  static const Duration _smartFinderTimeout = Duration(minutes: 2);

  /// Finder speech throttle — only re-announce when direction/distance
  /// changes or after 4 seconds.
  String _lastFinderSpoken = '';
  DateTime _lastFinderSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the target was visible in the previous frame.
  bool _finderWasTracking = false;

  final _finderStateController =
      StreamController<ObjectFinderState>.broadcast();
  Stream<ObjectFinderState> get finderStateStream =>
      _finderStateController.stream;

  bool get isFindingObject =>
      _mode == WareneMode.objectFinderFast ||
      _mode == WareneMode.objectFinderSmart;

  // ── Color mode state ──

  Timer? _colorTimer;
  bool _isColorProcessing = false;
  String _lastColorSpoken = '';
  DateTime _lastColorSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Spatial helpers ──

  String getDirection(Detection d, int imageWidth) {
    final centerX = (d.bbox[0] + d.bbox[2]) / 2;
    final third = imageWidth / 3;

    if (centerX < third) return 'عَلَى الْيَسَار';
    if (centerX < third * 2) return 'فِي الْوَسَط';
    return 'عَلَى الْيَمِين';
  }

  String getDistance(Detection d, int imageWidth, int imageHeight) {
    final boxW = (d.bbox[2] - d.bbox[0]).abs();
    final boxH = (d.bbox[3] - d.bbox[1]).abs();
    final ratio = (boxW * boxH) / (imageWidth.toDouble() * imageHeight.toDouble());

    if (ratio > 0.15) return 'قَرِيب جِدًّا';
    if (ratio > 0.05) return 'قَرِيب';
    return 'بَعِيد';
  }

  String buildSpatialDescription(Detection d) {
    final direction = getDirection(d, sourceWidth);
    final distance = getDistance(d, sourceWidth, sourceHeight);
    return '${d.arabicLabel} $direction، $distance';
  }

  // ── Initialization ──

  Future<void> init() async {
    await _detector.loadModel(DetectionModel.general);
    _currentModel = DetectionModel.general;
    await _gemini.init();
  }

  // ══════════════════════════════════════════════════════════════════
  //  CENTRAL MODE SWITCH
  // ══════════════════════════════════════════════════════════════════

  /// Switch the app to [newMode]. This is the single entry point for
  /// all mode transitions. It:
  /// 1. Stops all timers.
  /// 2. Waits for any active detection/processing to finish.
  /// 3. Clears mode-specific state.
  /// 4. Loads the YOLO model if needed.
  /// 5. Starts the correct timer for the new mode.
  /// 6. Emits mode/finder/status streams.
  ///
  /// Pass [target] when entering objectFinderFast/Smart.
  /// Pass [speak] = false to suppress mode announcement (e.g. during resume).
  Future<void> switchMode(
    WareneMode newMode, {
    ObjectFinderTarget? target,
    bool speak = true,
  }) async {
    if (_isSwitchingMode) return;
    _isSwitchingMode = true;

    try {
      // 1. Stop ALL timers
      _detectionTimer?.cancel();
      _detectionTimer = null;
      _smartFinderTimer?.cancel();
      _smartFinderTimer = null;
      _colorTimer?.cancel();
      _colorTimer = null;

      // 2. Wait for active detection/processing to finish
      await _waitForActiveDetection();

      // 3. Clear detections and mode-specific UI state
      currentDetections = [];
      _detectionController.add(currentDetections);
      _emptyFrameCount = 0;
      _lastSpoken = '';
      _isSmartFinderProcessing = false;
      _isColorProcessing = false;

      // 4. Load the correct YOLO model if needed
      if (newMode == WareneMode.generalObjects ||
          newMode == WareneMode.objectFinderFast) {
        if (_currentModel != DetectionModel.general) {
          _currentModel = DetectionModel.general;
          await _detector.loadModel(DetectionModel.general);
        }
      } else if (newMode == WareneMode.currency) {
        if (_currentModel != DetectionModel.currency) {
          _currentModel = DetectionModel.currency;
          await _detector.loadModel(DetectionModel.currency);
        }
      }
      // color & smartFinder don't need YOLO

      // 5. Set mode and finder target
      final previousMode = _mode;
      _mode = newMode;

      if (newMode == WareneMode.objectFinderFast ||
          newMode == WareneMode.objectFinderSmart) {
        _finderTarget = target;
        _finderStartedAt = DateTime.now();
        _lastFinderHintAt = DateTime.fromMillisecondsSinceEpoch(0);
        _lastFinderSpoken = '';
        _lastFinderSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
        _finderWasTracking = false;
      } else {
        _finderTarget = null;
        _finderWasTracking = false;
      }

      // 6. Start the correct timer
      switch (newMode) {
        case WareneMode.generalObjects:
        case WareneMode.currency:
        case WareneMode.objectFinderFast:
          _startDetectionLoop();
          break;
        case WareneMode.objectFinderSmart:
          _startSmartFinderTimer();
          break;
        case WareneMode.color:
          _startColorTimer();
          break;
      }

      // 7. Emit streams
      _modeController.add(newMode);

      // Emit finder state
      if (isFindingObject) {
        _emitFinderState(ObjectFinderStatus.searching);
      } else if (previousMode == WareneMode.objectFinderFast ||
          previousMode == WareneMode.objectFinderSmart) {
        // Was in finder, now leaving — emit inactive
        _emitFinderState(ObjectFinderStatus.inactive);
      }

      // 8. Announce mode
      if (speak) {
        final announcement = _getModeAnnouncement(newMode, target);
        _setStatus(announcement);
        await _speech.speak(announcement, force: true, throttle: false);
      }

      print('🔄 Mode switched: ${previousMode.name} → ${newMode.name}');
    } finally {
      _isSwitchingMode = false;
    }
  }

  String _getModeAnnouncement(WareneMode mode, ObjectFinderTarget? target) {
    switch (mode) {
      case WareneMode.generalObjects:
        return 'وَضْع الْأَشْيَاء';
      case WareneMode.currency:
        return 'وَضْع الْفُلُوس';
      case WareneMode.objectFinderFast:
      case WareneMode.objectFinderSmart:
        return 'جاري البحث عن ${target?.arabicName ?? '...'}';
      case WareneMode.color:
        return 'وضع الألوان';
    }
  }

  /// Wait for any active detection cycle to complete.
  Future<void> _waitForActiveDetection() async {
    if (_activeDetectionCompleter != null &&
        !_activeDetectionCompleter!.isCompleted) {
      try {
        await _activeDetectionCompleter!.future
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        // Timeout — proceed anyway
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  DETECTION LOOP (General, Currency, Fast Finder)
  // ══════════════════════════════════════════════════════════════════

  void _startDetectionLoop() {
    if (!_detector.isReady) {
      print('⚠️ Detector not ready, skipping timer start');
      return;
    }
    _detectionTimer?.cancel();
    final interval = _detectionIntervalForMode(_mode);
    _detectionTimer = Timer.periodic(interval, (_) {
      _runSingleDetection();
    });
    print('✅ Detection timer started (${interval.inMilliseconds}ms)');
  }

  /// Finder uses a slower interval to reduce preview blackouts
  /// from frequent takePicture() calls on some Android devices.
  Duration _detectionIntervalForMode(WareneMode mode) {
    if (mode == WareneMode.objectFinderFast) {
      return const Duration(seconds: 2);
    }
    return const Duration(milliseconds: 1500);
  }

  /// Kept public for lifecycle pause/resume in CameraScreen.
  void stopDetectionLoop() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  /// Also stop smart finder and color timers — used by lifecycle.
  void stopAllTimers() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
    _smartFinderTimer?.cancel();
    _smartFinderTimer = null;
    _colorTimer?.cancel();
    _colorTimer = null;
  }

  Future<void> _runSingleDetection() async {
    if (_isDetecting || _isSwitchingMode || _isOneShot) return;
    if (!_detector.isReady) return;
    _isDetecting = true;
    final completer = Completer<void>();
    _activeDetectionCompleter = completer;

    XFile? snapshot;
    try {
      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) return;

      final result = await _detector.detectFromFile(snapshot.path);
      if (result == null) return;

      // Route by mode
      switch (_mode) {
        case WareneMode.objectFinderFast:
          sourceWidth = result.imageWidth;
          sourceHeight = result.imageHeight;
          _handleFastFinderDetections(result.detections);
          break;
        case WareneMode.generalObjects:
          _handleGeneralDetections(result);
          break;
        case WareneMode.currency:
          _handleCurrencyDetections(result);
          break;
        default:
          // color/smart modes don't use detection loop
          break;
      }
    } catch (e) {
      print('⚠️ Detection loop error: $e');
    } finally {
      if (snapshot != null) {
        try { await File(snapshot.path).delete(); } catch (_) {}
      }
      _isDetecting = false;
      completer.complete();
      if (_activeDetectionCompleter == completer) {
        _activeDetectionCompleter = null;
      }
    }
  }

  // ── General detection handler ──

  void _handleGeneralDetections(DetectionResult result) {
    if (result.detections.isNotEmpty) {
      _emptyFrameCount = 0;
      currentDetections = result.detections;
      sourceWidth = result.imageWidth;
      sourceHeight = result.imageHeight;
      _detectionController.add(currentDetections);

      // Announce top detection with throttling
      final best = result.detections.first;
      final desc = buildSpatialDescription(best);
      final now = DateTime.now();
      final timePassed = now.difference(_lastSpeakTime).inSeconds >= 3;
      final differentObject = desc != _lastSpoken;

      if (differentObject || timePassed) {
        _lastSpoken = desc;
        _lastSpeakTime = now;

        _setStatus(
            '${best.arabicLabel} ${getDirection(best, result.imageWidth)} '
            '(${(best.confidence * 100).toStringAsFixed(0)}%)');

        final phrases = result.detections
            .take(3)
            .map(buildSpatialDescription)
            .join('، ');
        _speech.speak(phrases, throttle: false);
      }
    } else {
      _emptyFrameCount++;
      if (_emptyFrameCount >= 3) {
        currentDetections = [];
        _detectionController.add(currentDetections);
      }
    }
  }

  // ── Currency detection handler ──

  void _handleCurrencyDetections(DetectionResult result) {
    // Same logic as general — currency model only outputs money labels
    _handleGeneralDetections(result);
  }

  // ══════════════════════════════════════════════════════════════════
  //  FAST FINDER — persistent, throttled
  // ══════════════════════════════════════════════════════════════════

  void _handleFastFinderDetections(List<Detection> detections) {
    final target = _finderTarget;
    if (target == null) return;

    // Filter for target label with minimum confidence
    final matches = detections
        .where((d) => d.label == target.label && d.confidence >= 0.35)
        .toList();

    if (matches.isEmpty) {
      // Target not visible — only emit empty list on transition,
      // not every frame, to avoid rebuild churn.
      if (currentDetections.isNotEmpty) {
        currentDetections = [];
        _detectionController.add(currentDetections);
      }

      if (_finderWasTracking) {
        // Transition: tracking → searching
        _finderWasTracking = false;
        _emitFinderState(ObjectFinderStatus.searching);
        _setStatus('البحث عن: ${target.arabicName}');
      }
      return;
    }

    // Pick the best match: largest bounding-box area, then confidence
    matches.sort((a, b) {
      final areaA = (a.bbox[2] - a.bbox[0]).abs() * (a.bbox[3] - a.bbox[1]).abs();
      final areaB = (b.bbox[2] - b.bbox[0]).abs() * (b.bbox[3] - b.bbox[1]).abs();
      final areaCmp = areaB.compareTo(areaA);
      if (areaCmp != 0) return areaCmp;
      return b.confidence.compareTo(a.confidence);
    });

    final best = matches.first;
    final direction = getDirection(best, sourceWidth);
    final distance = getDistance(best, sourceWidth, sourceHeight);

    // Show only the found target
    currentDetections = [best];
    _detectionController.add(currentDetections);

    // Build announcement
    final announcement = 'لقيت ${target.arabicName} $direction، $distance';

    // Emit tracking state
    _finderStateController.add(ObjectFinderState(
      status: ObjectFinderStatus.tracking,
      mode: target.mode,
      targetLabel: target.label,
      targetArabicName: target.arabicName,
      foundDetection: best,
      statusText: announcement,
    ));
    _setStatus(announcement);

    // Speak only when:
    //   - first found (transition from searching → tracking)
    //   - direction or distance changed
    //   - 4 seconds since last speech
    final now = DateTime.now();
    final isFirstFound = !_finderWasTracking;
    final isChanged = announcement != _lastFinderSpoken;
    final isThrottled =
        now.difference(_lastFinderSpeakTime).inSeconds >= 4;

    if (isFirstFound || isChanged || isThrottled) {
      _lastFinderSpoken = announcement;
      _lastFinderSpeakTime = now;
      _speech.speak(announcement, force: true, throttle: false);
    }

    _finderWasTracking = true;
  }

  // ══════════════════════════════════════════════════════════════════
  //  SMART FINDER — persistent, timer-based
  // ══════════════════════════════════════════════════════════════════

  void _startSmartFinderTimer() {
    _smartFinderTimer?.cancel();
    _smartFinderTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _runSmartFinderCheck(),
    );
    // Run the first check immediately
    _runSmartFinderCheck();
  }

  Future<void> _runSmartFinderCheck() async {
    if (_mode != WareneMode.objectFinderSmart) return;
    if (_isSmartFinderProcessing || _isSwitchingMode || _isOneShot) return;

    // Hard timeout check (2 minutes)
    if (DateTime.now().difference(_finderStartedAt) > _smartFinderTimeout) {
      await _speech.speak(
        'انتهى وقت البحث. حاول تاني.',
        force: true,
        throttle: false,
      );
      _emitFinderState(ObjectFinderStatus.error);
      // Switch back to general
      switchMode(WareneMode.generalObjects, speak: false);
      return;
    }

    _isSmartFinderProcessing = true;

    XFile? snapshot;
    try {
      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) {
        // Camera busy or disposed — skip this tick
        return;
      }

      final bytes = await File(snapshot.path).readAsBytes();
      final result = await _gemini.findObjectInScene(
        bytes,
        targetName: _finderTarget!.label,
        targetArabicName: _finderTarget!.arabicName,
      );

      // Check if mode was changed while we were waiting
      if (_mode != WareneMode.objectFinderSmart) return;

      if (result.isError) {
        await _speech.speak(result.spokenText, force: true, throttle: false);
        _emitFinderState(ObjectFinderStatus.error);
        switchMode(WareneMode.generalObjects, speak: false);
        return;
      }

      if (result.found) {
        final announcement = result.spokenText.isNotEmpty
            ? result.spokenText
            : 'لقيت ${_finderTarget!.arabicName}';

        _setStatus(announcement);
        _finderStateController.add(ObjectFinderState(
          status: ObjectFinderStatus.tracking,
          mode: ObjectFinderMode.smartVision,
          targetLabel: _finderTarget!.label,
          targetArabicName: _finderTarget!.arabicName,
          statusText: announcement,
        ));

        // Speak with throttle — don't repeat same announcement within 4s
        final now = DateTime.now();
        if (announcement != _lastFinderSpoken ||
            now.difference(_lastFinderSpeakTime).inSeconds >= 4) {
          _lastFinderSpoken = announcement;
          _lastFinderSpeakTime = now;
          await _speech.speak(announcement, force: true, throttle: false);
        }

        // Stay in smart finder mode — keep searching
      } else {
        // Not found — emit searching state
        if (_finderWasTracking) {
          _finderWasTracking = false;
          _emitFinderState(ObjectFinderStatus.searching);
        }

        // Give periodic guidance
        final now = DateTime.now();
        if (now.difference(_lastFinderHintAt).inSeconds >= 30) {
          _lastFinderHintAt = now;
          if (now.difference(_finderStartedAt).inSeconds >= 5) {
            await _speech.speak(
              'لسه بدور، حرك الكاميرا ببطء',
              force: false,
              throttle: false,
            );
          }
        }
      }
    } catch (e) {
      print('⚠️ Smart Finder check error: $e');
    } finally {
      if (snapshot != null) {
        try { await File(snapshot.path).delete(); } catch (_) {}
      }
      _isSmartFinderProcessing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  COLOR MODE — persistent
  // ══════════════════════════════════════════════════════════════════

  void _startColorTimer() {
    _lastColorSpoken = '';
    _lastColorSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);
    _colorTimer?.cancel();
    _colorTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _runColorCheck(),
    );
    // Run the first check immediately
    _runColorCheck();
  }

  Future<void> _runColorCheck() async {
    if (_mode != WareneMode.color) return;
    if (_isColorProcessing || _isSwitchingMode || _isOneShot) return;

    _isColorProcessing = true;

    XFile? snapshot;
    try {
      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) return;

      final colorName = await _color.detectColor(snapshot.path);
      if (_mode != WareneMode.color) return; // mode changed while processing

      final announcement = 'اللون: $colorName';
      _setStatus(announcement);

      // Speak only when color changes or 5 seconds since last speech
      final now = DateTime.now();
      final isChanged = colorName != _lastColorSpoken;
      final isThrottled =
          now.difference(_lastColorSpeakTime).inSeconds >= 5;

      if (isChanged || isThrottled) {
        _lastColorSpoken = colorName;
        _lastColorSpeakTime = now;
        await _speech.speak(announcement, force: true, throttle: false);
      }
    } catch (e) {
      print('⚠️ Color check error: $e');
    } finally {
      if (snapshot != null) {
        try { await File(snapshot.path).delete(); } catch (_) {}
      }
      _isColorProcessing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  ONE-SHOT ACTIONS (OCR, Scene Description)
  //  These pause the current mode, perform the action, then resume.
  // ══════════════════════════════════════════════════════════════════

  Future<String> describeScene() async {
    if (_isSwitchingMode || _isOneShot) return 'جاري العمل...';

    final previousMode = _mode;
    final previousTarget = _finderTarget;

    // Pause current mode
    _isOneShot = true;
    stopAllTimers();
    await _waitForActiveDetection();

    currentDetections = [];
    _detectionController.add(currentDetections);

    XFile? snapshot;
    try {
      _setStatus('جاري الوصف...');
      await _speech.speak('جَارِي الْوَصْف', force: true, throttle: false);

      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) {
        final err = 'خطأ في الكاميرا';
        _setStatus(err);
        return err;
      }

      final bytes = await File(snapshot.path).readAsBytes();
      final desc = await _gemini.describeScene(bytes);

      _setStatus(desc);
      await _speech.speakAndWait(desc);
      await Future.delayed(const Duration(milliseconds: 500));
      return desc;
    } catch (e) {
      print('⚠️ Scene description error: $e');
      final errMsg = 'حَصَل خَطَأ فِى الْوَصْف. حَاوِل تَانِي.';
      _setStatus(errMsg);
      await _speech.speakAndWait(errMsg);
      return errMsg;
    } finally {
      if (snapshot != null) {
        try { await File(snapshot.path).delete(); } catch (_) {}
      }
      _isOneShot = false;
      // Resume previous mode
      await switchMode(previousMode, target: previousTarget, speak: false);
    }
  }

  Future<String> readText({OCRLanguage language = OCRLanguage.english}) async {
    if (_isSwitchingMode || _isOneShot) return 'جاري العمل...';

    final previousMode = _mode;
    final previousTarget = _finderTarget;

    // Pause current mode
    _isOneShot = true;
    stopAllTimers();
    await _waitForActiveDetection();

    currentDetections = [];
    _detectionController.add(currentDetections);

    XFile? snapshot;
    try {
      _setStatus('جاري القراءة...');
      await _speech.speak('جَارِي الْقِرَاءَة', force: true, throttle: false);

      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) {
        final err = 'خطأ في الكاميرا';
        _setStatus(err);
        return err;
      }

      final text = await _ocr.extractText(snapshot, language: language);
      _setStatus(text);

      final ttsLang = language == OCRLanguage.english ? 'en-US' : 'ar-EG';
      await _speech.speakAndWait(text, language: ttsLang);
      await Future.delayed(const Duration(milliseconds: 500));
      return text;
    } catch (e) {
      print('⚠️ OCR error: $e');
      final errMsg = 'حَصَل خَطَأ فِي الْقِرَاءَة. حَاوِل تَانِي.';
      _setStatus(errMsg);
      await _speech.speakAndWait(errMsg);
      return errMsg;
    } finally {
      if (snapshot != null) {
        try { await File(snapshot.path).delete(); } catch (_) {}
      }
      _isOneShot = false;
      // Resume previous mode
      await switchMode(previousMode, target: previousTarget, speak: false);
    }
  }

  // ── Finder state helper ──

  void _emitFinderState(ObjectFinderStatus status) {
    _finderStateController.add(ObjectFinderState(
      status: status,
      mode: _finderTarget?.mode,
      targetLabel: _finderTarget?.label,
      targetArabicName: _finderTarget?.arabicName,
      statusText: statusText,
    ));
  }

  // ── Status helper ──

  void _setStatus(String text) {
    statusText = text;
    _statusController.add(text);
  }

  // ── Cleanup ──

  Future<void> dispose() async {
    stopAllTimers();
    await _detector.dispose();
    _gemini.dispose();
    _ocr.dispose();
    await _detectionController.close();
    await _statusController.close();
    await _finderStateController.close();
    await _modeController.close();
  }
}
