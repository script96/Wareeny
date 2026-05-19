import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import '../detector.dart';
import '../gemini_service.dart';
import '../ocr_service.dart';
import '../models/ocr_result.dart';
import '../models/qa_types.dart';
import 'camera_service.dart';
import 'speech_service.dart';
import 'color_service.dart';
import 'voice_input_service.dart';
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
  final VoiceInputService _voice = VoiceInputService();

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
  bool get isBusy =>
      _isSwitchingMode || _isOneShot || _isQaListening || _isQaAnswering;

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

  // ── Danger Alert state ──

  Timer? _dangerScanTimer;
  bool _isDangerScanning = false;
  Completer<void>? _activeDangerScanCompleter;
  String _lastDangerKeyword = '';
  DateTime _lastDangerWarnTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const Map<String, String> _dangerArabic = {
    'wet floor': 'أرضية زلقة',
    'slippery floor': 'أرضية زلقة',
    'slippery': 'أرضية زلقة',
    'danger': 'خطر',
    'dangerous': 'خطر',
    'warning': 'تحذير',
    'caution': 'انتبه',
    'hazard': 'خطر',
    'hazardous': 'خطر',
    'beware': 'احذر',
    'high voltage': 'ضغط عالي خطر',
    'do not enter': 'ممنوع الدخول',
    'no entry': 'ممنوع الدخول',
    'restricted area': 'منطقة مقيدة',
    'keep out': 'ممنوع الاقتراب',
    'emergency': 'طوارئ',
    'fire hazard': 'خطر حريق',
    'poison': 'سم',
    'toxic': 'مواد سامة',
    'flammable': 'قابل للاشتعال',
    'no smoking': 'ممنوع التدخين',
    'explosive': 'متفجرات',
    'construction': 'منطقة بناء',
    'biohazard': 'خطر بيولوجي',
  };

  // ── Color mode state ──

  Timer? _colorTimer;
  bool _isColorProcessing = false;
  String _lastColorSpoken = '';
  DateTime _lastColorSpeakTime = DateTime.fromMillisecondsSinceEpoch(0);

  // ── QA Mode state ──

  String? _qaDocumentText;
  OCRLanguage? _qaLanguage;
  List<QaTurn> _qaHistory = [];
  bool _isQaListening = false;
  bool _isQaAnswering = false;
  bool get hasActiveQaDocument => _qaDocumentText != null;
  static const int _maxQaHistory = 5;

  /// Pure helper to trim QA history to [maxTurns].
  /// Delegates to the testable `trimQaHistory` in `qa_types.dart`.
  List<QaTurn> _trimHistory(List<QaTurn> history) =>
      trimQaHistory(history, maxTurns: _maxQaHistory);

  /// Clears QA state safely.
  Future<void> _clearDocumentQaState({bool stopVoice = true}) async {
    _qaDocumentText = null;
    _qaLanguage = null;
    _qaHistory.clear();
    _isQaListening = false;
    _isQaAnswering = false;
    if (stopVoice && _voice.isListening) {
      await _voice.stopListening();
    }
  }

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
    final ratio =
        (boxW * boxH) / (imageWidth.toDouble() * imageHeight.toDouble());

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
    if (!Platform.isIOS) {
      _startDangerScanner();
    }
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
      await _waitForActiveDangerScan();

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
      // color, smartFinder, documentQa don't need YOLO

      // 4b. Clear QA state when leaving QA mode
      if (_mode == WareneMode.documentQa && newMode != WareneMode.documentQa) {
        await _clearDocumentQaState(stopVoice: true);
      }

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
        case WareneMode.documentQa:
          // No timer — QA is event-driven (user double-taps to ask)
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

      // Restart danger scanner if it was stopped (e.g. after app pause).
      if (!Platform.isIOS && _dangerScanTimer == null) {
        _startDangerScanner();
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
      case WareneMode.documentQa:
        return 'وضع سؤال وجواب عن نص';
    }
  }

  /// Wait for any active detection cycle to complete.
  Future<void> _waitForActiveDetection() async {
    if (_activeDetectionCompleter != null &&
        !_activeDetectionCompleter!.isCompleted) {
      try {
        await _activeDetectionCompleter!.future.timeout(
          const Duration(seconds: 3),
        );
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
    if (Platform.isIOS) {
      return mode == WareneMode.objectFinderFast
          ? const Duration(seconds: 3)
          : const Duration(seconds: 2);
    }

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

    try {
      final bytes = await _camera.takeAnalysisBytes();
      if (bytes == null) return;

      final result = _detector.detectFromBytes(bytes);
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
          '(${(best.confidence * 100).toStringAsFixed(0)}%)',
        );

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
      final areaA =
          (a.bbox[2] - a.bbox[0]).abs() * (a.bbox[3] - a.bbox[1]).abs();
      final areaB =
          (b.bbox[2] - b.bbox[0]).abs() * (b.bbox[3] - b.bbox[1]).abs();
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
    _finderStateController.add(
      ObjectFinderState(
        status: ObjectFinderStatus.tracking,
        mode: target.mode,
        targetLabel: target.label,
        targetArabicName: target.arabicName,
        foundDetection: best,
        statusText: announcement,
      ),
    );
    _setStatus(announcement);

    // Speak only when:
    //   - first found (transition from searching → tracking)
    //   - direction or distance changed
    //   - 4 seconds since last speech
    final now = DateTime.now();
    final isFirstFound = !_finderWasTracking;
    final isChanged = announcement != _lastFinderSpoken;
    final isThrottled = now.difference(_lastFinderSpeakTime).inSeconds >= 4;

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
        _finderStateController.add(
          ObjectFinderState(
            status: ObjectFinderStatus.tracking,
            mode: ObjectFinderMode.smartVision,
            targetLabel: _finderTarget!.label,
            targetArabicName: _finderTarget!.arabicName,
            statusText: announcement,
          ),
        );

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
        try {
          await File(snapshot.path).delete();
        } catch (_) {}
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

    try {
      final bytes = await _camera.takeAnalysisBytes();
      if (bytes == null) return;

      final colorName = await _color.detectColorBytes(bytes);
      if (_mode != WareneMode.color) return; // mode changed while processing

      final announcement = 'اللون: $colorName';
      _setStatus(announcement);

      // Speak only when color changes or 5 seconds since last speech
      final now = DateTime.now();
      final isChanged = colorName != _lastColorSpoken;
      final isThrottled = now.difference(_lastColorSpeakTime).inSeconds >= 5;

      if (isChanged || isThrottled) {
        _lastColorSpoken = colorName;
        _lastColorSpeakTime = now;
        await _speech.speak(announcement, force: true, throttle: false);
      }
    } catch (e) {
      print('⚠️ Color check error: $e');
    } finally {
      _isColorProcessing = false;
    }
  }

  // ══════════════════════════════════════════════════════════════════
  //  DANGER ALERT — always-on background scan (independent of mode)
  // ══════════════════════════════════════════════════════════════════

  void _startDangerScanner() {
    _dangerScanTimer?.cancel();
    _dangerScanTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _runDangerScan(),
    );
  }

  Future<void> _runDangerScan() async {
    // Skip if any other camera/CPU work is in progress to avoid
    // collisions on takeSnapshot() and to keep the app responsive.
    if (_isDangerScanning ||
        _isSwitchingMode ||
        _isOneShot ||
        _isDetecting ||
        _isSmartFinderProcessing ||
        _isColorProcessing) {
      return;
    }

    _isDangerScanning = true;
    final completer = Completer<void>();
    _activeDangerScanCompleter = completer;

    XFile? snapshot;
    try {
      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) return;

      final matched = await _ocr.scanForDanger(snapshot.path);
      if (matched == null) return;

      final now = DateTime.now();
      final sameWord = matched == _lastDangerKeyword;
      final tooSoon = now.difference(_lastDangerWarnTime).inSeconds < 30;
      if (sameWord && tooSoon) return;

      _lastDangerKeyword = matched;
      _lastDangerWarnTime = now;

      final arabic = _dangerArabic[matched] ?? 'تحذير';
      await _speech.speak('تنبيه: $arabic', force: true, throttle: false);
      print('⚠️ Danger alert: "$matched" → $arabic');
    } catch (e) {
      print('⚠️ Danger scan error: $e');
    } finally {
      if (snapshot != null) {
        try {
          await File(snapshot.path).delete();
        } catch (_) {}
      }
      _isDangerScanning = false;
      completer.complete();
      if (_activeDangerScanCompleter == completer) {
        _activeDangerScanCompleter = null;
      }
    }
  }

  /// Wait for any in-flight danger scan to complete (used by one-shot
  /// actions before they take their own snapshot).
  Future<void> _waitForActiveDangerScan() async {
    if (_activeDangerScanCompleter != null &&
        !_activeDangerScanCompleter!.isCompleted) {
      try {
        await _activeDangerScanCompleter!.future.timeout(
          const Duration(seconds: 3),
        );
      } catch (_) {
        // Timeout — proceed anyway
      }
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
    await _waitForActiveDangerScan();

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
        try {
          await File(snapshot.path).delete();
        } catch (_) {}
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
    await _waitForActiveDangerScan();

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

      String text;
      if (language == OCRLanguage.arabic) {
        final bytes = await File(snapshot.path).readAsBytes();
        final extracted = await _gemini.extractTextFromImage(bytes);
        if (extracted == null) {
          text = 'حصل خطأ في خدمة القراءة. حاول تاني.';
        } else if (extracted.isEmpty) {
          text = 'لا يوجد نص في الصورة';
        } else {
          text = extracted;
        }
      } else {
        text = await _ocr.extractText(snapshot, language: language);
      }
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
        try {
          await File(snapshot.path).delete();
        } catch (_) {}
      }
      _isOneShot = false;
      // Resume previous mode
      await switchMode(previousMode, target: previousTarget, speak: false);
    }
  }
  // ══════════════════════════════════════════════════════════════════
  //  DOCUMENT QA MODE
  //  Persistent mode: scan once, ask many questions via voice.
  // ══════════════════════════════════════════════════════════════════

  /// Start QA mode: scan a document, store text, await voice questions.
  ///
  /// Call from the action menu. The user should point the camera at a
  /// document before calling this. Returns a status message.
  Future<String> startDocumentQa({required OCRLanguage language}) async {
    if (_isSwitchingMode || _isOneShot) return 'جاري العمل...';

    _isOneShot = true;
    stopAllTimers();
    await _waitForActiveDetection();

    currentDetections = [];
    _detectionController.add(currentDetections);

    XFile? snapshot;
    try {
      // Switch to QA mode
      await switchMode(WareneMode.documentQa, speak: false);

      // Instruct user
      _setStatus('وجه الكاميرا على الورقة وثبتها');
      await _speech.speakAndWait('وجه الكاميرا على الورقة وثبتها');
      await Future.delayed(const Duration(seconds: 2));

      // Take snapshot
      _setStatus('جاري مسح النص...');
      snapshot = await _camera.takeSnapshot();
      if (snapshot == null) {
        final err = 'خطأ في الكاميرا';
        _setStatus(err);
        await _speech.speakAndWait(err);
        _isOneShot = false;
        await endDocumentQa();
        return err;
      }

      // Run OCR — Arabic uses Groq Vision, English uses ML Kit.
      OCRResult ocrResult;
      if (language == OCRLanguage.arabic) {
        final bytes = await File(snapshot.path).readAsBytes();
        final rawText = await _gemini.extractTextFromImage(bytes);
        if (rawText == null) {
          // API/network failure — distinguish from "no text found".
          final err = 'حصل خطأ في خدمة القراءة. حاول تاني.';
          _setStatus(err);
          await _speech.speakAndWait(err);
          _isOneShot = false;
          await endDocumentQa();
          return err;
        }
        ocrResult = OCRResult.fromRawText(rawText, language);
      } else {
        ocrResult = await _ocr.extractStructured(snapshot, language: language);
      }

      print('📄 OCR result: $ocrResult');

      // Check quality
      switch (ocrResult.quality) {
        case OCRQuality.empty:
          final msg = 'مش واضح أي نص. قرب الورقة وثبت الكاميرا وحاول تاني.';
          _setStatus(msg);
          await _speech.speakAndWait(msg);
          _isOneShot = false;
          await endDocumentQa();
          return msg;

        case OCRQuality.tooShort:
          final msg = 'النص مش واضح كفاية. حاول تثبت الكاميرا وتقرب شوية.';
          _setStatus(msg);
          await _speech.speakAndWait(msg);
          _isOneShot = false;
          await endDocumentQa();
          return msg;

        case OCRQuality.valid:
          // Store document context
          _qaDocumentText = ocrResult.rawText;
          _qaLanguage = language;
          _qaHistory.clear();

          if (_qaDocumentText!.length > 4000) {
            _qaDocumentText = _qaDocumentText!.substring(0, 4000);
            print(
              '⚠️ Document QA context truncated to 4000 chars (was ${ocrResult.rawText.length})',
            );
            final confirmation = 'النص طويل، هجاوب من أول جزء واضح منه.';
            _setStatus(confirmation);
            await _speech.speakAndWait(confirmation);
          } else {
            final confirmation = 'قرأت النص. دبل تاب واسألني عنه.';
            _setStatus(confirmation);
            await _speech.speakAndWait(confirmation);
          }

          _isOneShot = false;
          return statusText;
      }
    } catch (e) {
      print('⚠️ startDocumentQa error: $e');
      final errMsg = 'حصل خطأ في مسح النص. حاول تاني.';
      _setStatus(errMsg);
      await _speech.speakAndWait(errMsg);
      _isOneShot = false;
      await endDocumentQa();
      return errMsg;
    } finally {
      if (snapshot != null) {
        try {
          await File(snapshot.path).delete();
        } catch (_) {}
      }
    }
  }

  /// Ask a voice question about the scanned document.
  ///
  /// Call from double-tap when in QA mode. Listens for speech,
  /// sends to Groq, speaks the answer, and stays in QA mode.
  Future<String> askDocumentQuestion() async {
    // Guard: no document
    if (_qaDocumentText == null) {
      final msg = 'امسح ورقة الأول. افتح القائمة واختار اسأل عن نص.';
      _setStatus(msg);
      await _speech.speak(msg, force: true, throttle: false);
      return msg;
    }

    // Guard: already processing
    if (_isQaListening || _isQaAnswering) {
      return 'جاري العمل...';
    }

    try {
      await _voice.init();

      // Prompt user to speak
      _setStatus('اسأل سؤالك دلوقتي');
      await _speech.speakAndWait('اسأل سؤالك دلوقتي');

      // Short pause before listening (let TTS finish)
      await Future.delayed(const Duration(milliseconds: 500));

      // Listen for question
      _isQaListening = true;
      _setStatus('بسمعك...');
      final voiceResult = await _voice.listenOnce(
        language: _qaLanguage ?? OCRLanguage.arabic,
      );
      _isQaListening = false;

      if (!voiceResult.isSuccess) {
        String errorMsg;
        switch (voiceResult.failure) {
          case VoiceInputFailure.noSpeech:
          case VoiceInputFailure.timeout:
            errorMsg = 'مسمعتش السؤال. دبل تاب وحاول تاني.';
            break;
          case VoiceInputFailure.permissionDenied:
            errorMsg = 'الميكروفون محتاج إذن من الإعدادات.';
            break;
          case VoiceInputFailure.unavailable:
            errorMsg = 'التعرف على الصوت مش جاهز على الجهاز.';
            break;
          case VoiceInputFailure.error:
          case null:
            errorMsg = 'حصل خطأ في التعرف على الصوت. حاول تاني.';
            break;
        }
        _setStatus(errorMsg);
        await _speech.speakAndWait(errorMsg);
        return errorMsg;
      }

      // Question cleanup
      final rawQuestion = voiceResult.text!;
      final question = rawQuestion.trim().replaceAll(RegExp(r'\s+'), ' ');
      print('❓ QA question: "$question"');

      if (question.length < 2) {
        final errMsg = 'السؤال مش واضح. دبل تاب واسأل تاني.';
        _setStatus(errMsg);
        await _speech.speakAndWait(errMsg);
        return errMsg;
      }

      // Processing indicator
      _setStatus('ثواني، بدور في النص...');
      await _speech.speak('ثواني، بدور في النص', force: true, throttle: false);

      // Call Groq QA
      _isQaAnswering = true;
      final qaResult = await _gemini.answerQuestionFromDocument(
        documentText: _qaDocumentText!,
        question: question,
        history: _qaHistory,
        language: _qaLanguage ?? OCRLanguage.arabic,
      );
      _isQaAnswering = false;

      if (qaResult.isError) {
        _setStatus(qaResult.answer);
        await _speech.speakAndWait(qaResult.answer);
        return qaResult.answer;
      }

      // Speak answer
      _setStatus(qaResult.answer);
      await _speech.speakAndWait(qaResult.answer);

      // Append to history (trim to max)
      _qaHistory.add(QaTurn(question: question, answer: qaResult.answer));
      _qaHistory = _trimHistory(_qaHistory);

      // Prompt for follow-up
      await Future.delayed(const Duration(milliseconds: 500));
      await _speech.speak(
        'ممكن تسأل سؤال تاني. دبل تاب.',
        force: false,
        throttle: false,
      );

      return qaResult.answer;
    } catch (e) {
      print('⚠️ askDocumentQuestion error: $e');
      _isQaListening = false;
      _isQaAnswering = false;
      final errMsg = 'حصل خطأ. حاول تسأل تاني.';
      _setStatus(errMsg);
      await _speech.speakAndWait(errMsg);
      return errMsg;
    }
  }

  /// Exit QA mode, clear document context and history.
  ///
  /// If [resumeGeneral] is true, switches back to generalObjects mode.
  Future<void> endDocumentQa({bool resumeGeneral = true}) async {
    await _clearDocumentQaState(stopVoice: false);

    if (_voice.isListening) {
      await _voice.stopListening();
    }

    if (resumeGeneral && _mode == WareneMode.documentQa) {
      await switchMode(WareneMode.generalObjects);
    }
  }

  // ── Finder state helper ──

  void _emitFinderState(ObjectFinderStatus status) {
    _finderStateController.add(
      ObjectFinderState(
        status: status,
        mode: _finderTarget?.mode,
        targetLabel: _finderTarget?.label,
        targetArabicName: _finderTarget?.arabicName,
        statusText: statusText,
      ),
    );
  }

  // ── Status helper ──

  void _setStatus(String text) {
    statusText = text;
    _statusController.add(text);
  }

  /// Stop everything when app goes to background.
  Future<void> handleAppPause() async {
    stopAllTimers();
    _dangerScanTimer?.cancel();
    _dangerScanTimer = null;
    // Let any in-flight scan finish so we don't leave the camera
    // in a half-disposed state.
    await _waitForActiveDangerScan();
    if (_voice.isListening) {
      await _voice.stopListening();
    }
    _isQaListening = false;
    _isQaAnswering = false;
    // We intentionally DO NOT clear _qaDocumentText here, so the user
    // doesn't lose their scan just by locking the screen momentarily.
  }

  // ── Cleanup ──

  Future<void> dispose() async {
    stopAllTimers();
    _dangerScanTimer?.cancel();
    _dangerScanTimer = null;
    // Wait for in-flight detection and danger scan to finish before
    // tearing down the underlying recognizers/detectors.
    await _waitForActiveDetection();
    await _waitForActiveDangerScan();
    await _detector.dispose();
    _gemini.dispose();
    _ocr.dispose();
    await _detectionController.close();
    await _statusController.close();
    await _finderStateController.close();
    await _modeController.close();
  }
}
