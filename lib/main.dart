// Warene — AI assistive app for visually impaired users in Egypt
//
// Uses flutter_vision for native C++ YOLOv8 inference.
// Detection uses takePicture() snapshots to bypass a YUV stride bug
// in flutter_vision's yoloOnFrame().

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'detector.dart';
import 'gemini_service.dart';
import 'ocr_service.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const WareneApp());
}

class WareneApp extends StatelessWidget {
  const WareneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Warene',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const PermissionGate(),
    );
  }
}

// ── Permission gate ─────────────────────────────────────────────────
class PermissionGate extends StatefulWidget {
  const PermissionGate({super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone].request();
    final cameraOk = await Permission.camera.isGranted;
    final micOk = await Permission.microphone.isGranted;

    if (mounted) {
      if (cameraOk && micOk) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        );
      } else {
        setState(() => _checking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _checking
            ? const CircularProgressIndicator(color: Colors.white)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'Warene needs camera and\nmicrophone permissions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Grant Permissions'),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Camera + detection screen ───────────────────────────────────────
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final FlutterTts _tts = FlutterTts();
  final YoloDetector _detector = YoloDetector();
  final GeminiService _gemini = GeminiService();
  final OCRService _ocrService = OCRService();

  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _isDescribing = false;
  bool _isOCRProcessing = false;
  OCRLanguage _ocrLanguage = OCRLanguage.english;
  String _statusText = 'Initializing...';
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.now();

  Timer? _detectionTimer;

  // Bounding box state
  List<Detection> _detections = [];
  int _sourceImageWidth = 1;
  int _sourceImageHeight = 1;
  int _emptyFrameCount = 0; // Track consecutive empty frames for persistence

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initTts();
    _initAll();
  }

  // ── Lifecycle handling ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _stopDetection();
      _controller?.dispose();
      _controller = null;
      _isCameraReady = false;
    } else if (state == AppLifecycleState.resumed) {
      _initAll();
    }
  }

  Future<void> _initAll() async {
    await _initCamera();
    await _initDetector(modelType: _detector.currentModel);
    await _gemini.init();
    _startDetectionTimer();
  }

  // ── TTS setup ──
  Future<void> _initTts() async {
    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.speak('مَرْحَبًا، وَرِّينِي جَاهِز');
  }

  // ── Camera init — use HIGH resolution for better detection ──
  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      if (mounted) setState(() => _statusText = 'No camera found');
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusText = 'Camera ready';
        });
        print('📷 Camera preview size: ${_controller!.value.previewSize}');
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Camera error: $e');
    }
  }

  // ── Model init ──
  Future<void> _initDetector({DetectionModel modelType = DetectionModel.general}) async {
    if (mounted) setState(() => _statusText = 'Loading AI...');
    try {
      await _detector.loadModel(modelType);
      if (mounted) {
        setState(() => _statusText =
            _detector.isReady ? 'AI Ready ✓' : 'AI Failed');
      }
      print('🔵 _initDetector done — isReady=${_detector.isReady}, model=${_detector.currentModel}');
    } catch (e) {
      print('❌ _initDetector error: $e');
      if (mounted) setState(() => _statusText = 'AI Error: $e');
    }
  }

  // ── Mode Toggle ──
  Future<void> _toggleDetectionMode() async {
    if (!_isCameraReady) return;
    _stopDetection();

    // Clear old bounding boxes immediately so they don't persist
    if (mounted) {
      setState(() {
        _detections = [];
      });
    }

    final newMode = _detector.currentModel == DetectionModel.general
        ? DetectionModel.currency
        : DetectionModel.general;
    
    // Announce mode change
    if (mounted) {
      setState(() => _statusText = newMode == DetectionModel.general ? 'وضع الأشياء' : 'وضع الفلوس');
    }
    await _tts.speak(newMode == DetectionModel.general ? 'وَضْع الْأَشْيَاء' : 'وَضْع الْفُلُوس');
    
    await _initDetector(modelType: newMode);
    _startDetectionTimer();
  }

  // ── Timer-based detection ──
  void _startDetectionTimer() {
    if (!_detector.isReady) {
      print('⚠️ Detector not ready, skipping timer start');
      return;
    }

    _detectionTimer?.cancel();
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _runDetection();
    });
    print('✅ Detection timer started (1500ms, snapshot mode)');
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  // ── Spatial helpers ──

  /// Determine horizontal direction from bbox center.
  /// Splits the image into 3 zones: left / center / right.
  String _getDirection(Detection d, int imageWidth) {
    final centerX = (d.bbox[0] + d.bbox[2]) / 2;
    final third = imageWidth / 3;

    if (centerX < third) {
      return 'عَلَى الْيَسَار'; // on the left
    } else if (centerX < third * 2) {
      return 'فِي الْوَسَط'; // in the center
    } else {
      return 'عَلَى الْيَمِين'; // on the right
    }
  }

  /// Estimate distance from bbox area relative to image area.
  /// Larger box = closer object.
  String _getDistance(Detection d, int imageWidth, int imageHeight) {
    final boxW = (d.bbox[2] - d.bbox[0]).abs();
    final boxH = (d.bbox[3] - d.bbox[1]).abs();
    final boxArea = boxW * boxH;
    final imageArea = imageWidth.toDouble() * imageHeight.toDouble();
    final ratio = boxArea / imageArea;

    if (ratio > 0.15) {
      return 'قَرِيب جِدًّا'; // very close
    } else if (ratio > 0.05) {
      return 'قَرِيب'; // close
    } else {
      return 'بَعِيد'; // far
    }
  }

  /// Build a spatial Arabic description for a detection.
  /// Example: "شخص على اليمين، قريب"
  String _buildSpatialDescription(Detection d, int imgW, int imgH) {
    final direction = _getDirection(d, imgW);
    final distance = _getDistance(d, imgW, imgH);
    return '${d.arabicLabel} $direction، $distance';
  }

  // ── OCR Text Reading ──
  Future<void> _triggerOCR() async {
    if (_isOCRProcessing || _isDescribing || !_isCameraReady || _controller == null) return;

    _isOCRProcessing = true;
    _stopDetection(); // Pause YOLO to prevent TTS collision

    // Clear bounding boxes immediately
    if (mounted) {
      setState(() {
        _detections = [];
        _statusText = 'جاري القراءة...';
      });
    }

    // Haptic feedback + immediate audio confirmation
    HapticFeedback.mediumImpact();
    await _tts.speak('جَارِي الْقِرَاءَة');

    XFile? capturedFile;
    const maxRetries = 2;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        capturedFile = await _controller!.takePicture();
        final text = await _ocrService.extractText(capturedFile, language: _ocrLanguage);

        // Clean up temp file
        try {
          await File(capturedFile.path).delete();
        } catch (_) {}

        if (mounted) {
          setState(() => _statusText = text);
        }

        // Switch TTS language to match OCR mode
        if (_ocrLanguage == OCRLanguage.english) {
          await _tts.setLanguage('en-US');
        }

        // Speak and WAIT for TTS to finish before resuming YOLO
        await _speakAndWait(text);

        // Reset TTS back to Arabic for YOLO/other features
        if (_ocrLanguage == OCRLanguage.english) {
          await _tts.setLanguage('ar-EG');
        }
        break; // Success — exit retry loop
      } catch (e) {
        print('⚠️ OCR error (attempt ${attempt + 1}): $e');
        attempt++;
        if (capturedFile != null) {
          try {
            await File(capturedFile.path).delete();
          } catch (_) {}
        }
        if (attempt == maxRetries) {
          final errorMsg = 'حَصَل خَطَأ فِي الْقِرَاءَة. حَاوِل تَانِي.';
          if (mounted) {
            setState(() => _statusText = errorMsg);
          }
          await _speakAndWait(errorMsg);
        }
      }
    }

    // Wait a beat so the user can process what they heard
    await Future.delayed(const Duration(milliseconds: 500));

    _isOCRProcessing = false;
    if (mounted) setState(() {});
    _startDetectionTimer(); // Resume YOLO only after TTS done
  }

  /// Speak text and wait for TTS to finish (returns a Future that completes
  /// when the utterance is done).
  Future<void> _speakAndWait(String text) async {
    final completer = Completer<void>();
    _tts.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setCancelHandler(() {
      if (!completer.isCompleted) completer.complete();
    });
    _tts.setErrorHandler((msg) {
      if (!completer.isCompleted) completer.complete();
    });
    await _tts.speak(text);
    // Wait for TTS to actually finish speaking
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  /// Run one detection cycle using takePicture() snapshot.
  Future<void> _runDetection() async {
    if (_isDetecting || _isDescribing || _isOCRProcessing || !_isCameraReady || _controller == null) return;
    _isDetecting = true;

    XFile? capturedFile;
    try {
      capturedFile = await _controller!.takePicture();
      final result = await _detector.detectFromFile(capturedFile.path);

      // Clean up the temp file.
      try {
        await File(capturedFile.path).delete();
      } catch (_) {}

      if (result != null && mounted) {
        if (result.detections.isNotEmpty) {
          // Got detections — reset empty counter and update UI
          _emptyFrameCount = 0;
          setState(() {
            _detections = result.detections;
            _sourceImageWidth = result.imageWidth;
            _sourceImageHeight = result.imageHeight;
          });
        } else {
          // No detections — only clear after 3 consecutive empty frames
          // This prevents flickering when the model misses a frame
          _emptyFrameCount++;
          if (_emptyFrameCount >= 3) {
            setState(() {
              _detections = [];
            });
          }
        }

        if (result.detections.isNotEmpty) {
          final now = DateTime.now();
          final timePassed = now.difference(_lastSpeakTime).inSeconds >= 3;

          // Build spatial description for the top detection.
          final best = result.detections.first;
          final spatialDesc = _buildSpatialDescription(
              best, result.imageWidth, result.imageHeight);

          final differentObject = spatialDesc != _lastSpoken;

          if (differentObject || timePassed) {
            _lastSpoken = spatialDesc;
            _lastSpeakTime = now;

            // Status text: show top detection with spatial info.
            if (mounted) {
              setState(() => _statusText =
                  '${best.arabicLabel} ${_getDirection(best, result.imageWidth)} '
                  '(${(best.confidence * 100).toStringAsFixed(0)}%)');
            }

            // Build TTS: announce up to 3 objects with spatial info.
            final topDetections = result.detections.take(3);
            final phrases = topDetections.map((d) =>
                _buildSpatialDescription(
                    d, result.imageWidth, result.imageHeight));
            final ttsText = phrases.join('، ');
            await _tts.speak(ttsText);
          }
        }
      }
    } catch (e) {
      print('⚠️ Detection loop error: $e');
      if (capturedFile != null) {
        try {
          await File(capturedFile.path).delete();
        } catch (_) {}
      }
    } finally {
      _isDetecting = false;
    }
  }

  // ── Gemini Scene Description ──
  Future<void> _describeScene() async {
    if (_isDescribing || !_isCameraReady || _controller == null) return;

    _isDescribing = true;
    _stopDetection(); // Pause YOLO to prevent TTS collision

    // Clear bounding boxes immediately
    if (mounted) {
      setState(() {
        _detections = [];
        _statusText = 'جاري الوصف...';
      });
    }

    // Haptic feedback + immediate audio confirmation
    HapticFeedback.mediumImpact();
    await _tts.speak('جَارِي الْوَصْف');

    XFile? capturedFile;
    try {
      capturedFile = await _controller!.takePicture();
      final imageBytes = await File(capturedFile.path).readAsBytes();

      // Clean up temp file
      try {
        await File(capturedFile.path).delete();
      } catch (_) {}

      final description = await _gemini.describeScene(imageBytes);

      if (mounted) {
        setState(() => _statusText = description);
      }
      
      // Speak and WAIT for TTS to finish before resuming YOLO
      await _speakAndWait(description);
      
      // Wait a beat so the user can process what they heard
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('⚠️ Scene description error: $e');
      final errorMsg = 'حَصَل خَطَأ فِى الْوَصْف. حَاوِل تَانِي.';
      if (mounted) {
        setState(() => _statusText = errorMsg);
      }
      await _speakAndWait(errorMsg);
      if (capturedFile != null) {
        try {
          await File(capturedFile.path).delete();
        } catch (_) {}
      }
    } finally {
      _isDescribing = false;
      if (mounted) setState(() {});
      _startDetectionTimer(); // Resume YOLO only after TTS done
    }
  }

  // ── Cleanup ──
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _stopDetection();
    _controller?.dispose();
    _tts.stop();
    _detector.dispose();
    _gemini.dispose();
    _ocrService.dispose();
    super.dispose();
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview with bounding box overlay
          if (_isCameraReady && _controller != null)
            SizedBox.expand(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // previewSize is always landscape (width > height)
                  final previewSize = _controller!.value.previewSize!;
                  // In portrait mode, the actual rendered aspect ratio is
                  // portrait: previewSize.height / previewSize.width -> e.g. 720/1280
                  final previewW = previewSize.height; // portrait width
                  final previewH = previewSize.width;  // portrait height

                  final screenW = constraints.maxWidth;
                  final screenH = constraints.maxHeight;

                  // BoxFit.cover scaling: scale to fill, crop excess
                  final scale = math.max(screenW / previewW, screenH / previewH);
                  final displayW = previewW * scale;
                  final displayH = previewH * scale;
                  final offsetX = (screenW - displayW) / 2;
                  final offsetY = (screenH - displayH) / 2;

                  return Stack(
                    children: [
                      // Camera preview
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: previewW,
                            height: previewH,
                            child: CameraPreview(_controller!),
                          ),
                        ),
                      ),
                      // Bounding box overlay
                      if (_detections.isNotEmpty)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: BoundingBoxPainter(
                              detections: _detections,
                              sourceWidth: _sourceImageWidth,
                              sourceHeight: _sourceImageHeight,
                              displayWidth: displayW,
                              displayHeight: displayH,
                              offsetX: offsetX,
                              offsetY: offsetY,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // App title
          Positioned(
            top: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'وريني',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),

          // Detection count badge
          if (_detections.isNotEmpty)
            Positioned(
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
                  '${_detections.length} detected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // ── Action buttons row ──
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Row(
              children: [
                // "Read Text" OCR button — left (tap = read, long press = switch language)
                Expanded(
                  child: GestureDetector(
                    onTap: (_isOCRProcessing || _isDescribing) ? null : _triggerOCR,
                    onLongPress: (_isOCRProcessing || _isDescribing) ? null : () {
                      setState(() {
                        _ocrLanguage = _ocrLanguage == OCRLanguage.english
                            ? OCRLanguage.arabic
                            : OCRLanguage.english;
                      });
                      HapticFeedback.mediumImpact();
                      _tts.speak(_ocrLanguage == OCRLanguage.arabic
                          ? 'وَضْع عَرَبِي'
                          : 'وَضْع إِنْجِلِيزِي');
                    },
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isOCRProcessing
                            ? Colors.grey.withAlpha(180)
                            : Colors.green.withAlpha(200),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isOCRProcessing)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              else
                                const Icon(Icons.text_fields, color: Colors.white, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                _isOCRProcessing
                                    ? 'جاري...'
                                    : (_ocrLanguage == OCRLanguage.arabic ? 'اقرأ عربي' : 'Read EN'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Small hint: long press to switch
                          if (!_isOCRProcessing)
                            Text(
                              'اضغط مطولاً للتبديل',
                              style: TextStyle(
                                color: Colors.white.withAlpha(160),
                                fontSize: 9,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // "Describe Scene" button — right
                Expanded(
                  child: GestureDetector(
                    onTap: (_isDescribing || _isOCRProcessing) ? null : _describeScene,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isDescribing
                            ? Colors.orange.withAlpha(180)
                            : Colors.blue.withAlpha(200),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(100),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isDescribing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          else
                            const Icon(Icons.image_search, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            _isDescribing ? 'جاري الوصف...' : 'وصف المشهد',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // OCR / Describe loading overlay
          if (_isOCRProcessing || _isDescribing)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withAlpha(100),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          _isOCRProcessing ? 'جاري القراءة...' : 'جاري الوصف...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Gemini status indicator
          if (_gemini.isReady)
            Positioned(
              top: 48,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Gemini ✓',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Mode switch button
          Positioned(
            top: 100,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: _toggleDetectionMode,
              label: Text(_detector.currentModel == DetectionModel.general ? 'عادي' : 'فلوس'),
              icon: Icon(_detector.currentModel == DetectionModel.general ? Icons.visibility : Icons.attach_money),
              backgroundColor: Colors.blueGrey.withAlpha(200),
            ),
          ),

          // Status bar
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bounding box painter ────────────────────────────────────────────
class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final int sourceWidth;    // captured JPEG width  (e.g. 720)
  final int sourceHeight;   // captured JPEG height (e.g. 1280)
  final double displayWidth;  // scaled preview width on screen
  final double displayHeight; // scaled preview height on screen
  final double offsetX;       // horizontal offset (negative = cropped)
  final double offsetY;       // vertical offset (negative = cropped)

  // Predefined colors for different classes
  static const List<Color> _boxColors = [
    Color(0xFF00FF00), // green
    Color(0xFF00BFFF), // deep sky blue
    Color(0xFFFF6347), // tomato
    Color(0xFFFFD700), // gold
    Color(0xFFFF69B4), // hot pink
    Color(0xFF7B68EE), // medium slate blue
    Color(0xFFFF8C00), // dark orange
    Color(0xFF00CED1), // dark turquoise
  ];

  BoundingBoxPainter({
    required this.detections,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.displayWidth,
    required this.displayHeight,
    required this.offsetX,
    required this.offsetY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Map detection coordinates from source image space to screen space.
    //
    // Source image is from takePicture() — same scene as the camera preview.
    // Both are in portrait orientation on this device (720x1280).
    // The display is the BoxFit.cover scaled preview.
    //
    // Scale factors: displayWidth/sourceWidth, displayHeight/sourceHeight
    // Offset: offsetX, offsetY (from BoxFit.cover centering)
    final scaleX = displayWidth / sourceWidth;
    final scaleY = displayHeight / sourceHeight;

    for (int i = 0; i < detections.length; i++) {
      final d = detections[i];
      final color = _boxColors[i % _boxColors.length];

      final left = d.bbox[0] * scaleX + offsetX;
      final top = d.bbox[1] * scaleY + offsetY;
      final right = d.bbox[2] * scaleX + offsetX;
      final bottom = d.bbox[3] * scaleY + offsetY;

      final rect = Rect.fromLTRB(left, top, right, bottom);

      // Draw box outline
      final boxPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawRect(rect, boxPaint);

      // Semi-transparent fill
      final fillPaint = Paint()
        ..color = color.withAlpha(30)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, fillPaint);

      // Draw label background + text
      final label =
          '${d.arabicLabel} ${(d.confidence * 100).toStringAsFixed(0)}%';

      final textStyle = ui.TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      );

      // Use LTR for positioning — Arabic glyphs render correctly
      // regardless of paragraph direction. RTL was causing the text
      // to right-align inside the 300px paragraph, shifting it left.
      final paragraphBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textDirection: ui.TextDirection.ltr,
          fontSize: 13,
          maxLines: 1,
        ),
      )
        ..pushStyle(textStyle)
        ..addText(label);

      final paragraph = paragraphBuilder.build();
      paragraph.layout(ui.ParagraphConstraints(width: (right - left).clamp(80, 300)));

      final textWidth = paragraph.longestLine + 10;
      final textHeight = paragraph.height + 6;

      // Position label above the box, clamped to screen top
      final labelTop = (top - textHeight - 2).clamp(0.0, size.height - textHeight);

      // Label background
      final labelBg = Rect.fromLTWH(left, labelTop, textWidth, textHeight);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBg, const Radius.circular(4)),
        Paint()..color = color.withAlpha(200),
      );

      // Label text — centered vertically in background
      canvas.drawParagraph(paragraph, Offset(left + 5, labelTop + 3));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections;
  }
}