import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'detector.dart';

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

// ── Permission gate (unchanged logic) ───────────────────────────────
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

  bool _isCameraReady = false;
  bool _isDetecting = false;
  bool _isStreamRunning = false;
  String _statusText = 'Initializing...';
  String _lastSpoken = '';
  DateTime _lastSpeakTime = DateTime.now();

  Timer? _detectionTimer;

  // The latest frame from the always-running image stream.
  CameraImage? _latestFrame;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _initTts();
    _initAll();
  }

  // ── Lifecycle handling — pause/resume camera cleanly ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.paused) {
      _stopDetection();
      _stopStream();
      _controller?.dispose();
      _controller = null;
      _isCameraReady = false;
    } else if (state == AppLifecycleState.resumed) {
      _initAll();
    }
  }

  Future<void> _initAll() async {
    await _initCamera();
    await _initDetector();
    _startStream();
    _startDetectionTimer();
  }

  // ── TTS setup ──
  Future<void> _initTts() async {
    await _tts.setLanguage('ar-EG');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.speak('مرحباً، وارين جاهز');
  }

  // ── Camera init ──
  Future<void> _initCamera() async {
    if (cameras.isEmpty) {
      if (mounted) setState(() => _statusText = 'No camera found');
      return;
    }

    _controller = CameraController(
      cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _statusText = 'Camera ready';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Camera error: $e');
    }
  }

  // ── Model init ──
  Future<void> _initDetector() async {
    if (_detector.isReady) return; // already loaded
    if (mounted) setState(() => _statusText = 'Loading AI...');
    try {
      await _detector.loadModel();
      if (mounted) {
        setState(() => _statusText =
            _detector.isReady ? 'AI Ready ✓' : 'AI Failed');
      }
    } catch (e) {
      if (mounted) setState(() => _statusText = 'AI Error');
    }
  }

  // ── Start the image stream ONCE — never stop it until dispose ──
  void _startStream() {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isStreamRunning) {
      return;
    }

    _controller!.startImageStream((CameraImage image) {
      // Just save the latest frame — no processing here.
      _latestFrame = image;
    });
    _isStreamRunning = true;
    print('✅ Image stream started (always-on)');
  }

  void _stopStream() {
    if (_isStreamRunning && _controller != null) {
      try {
        _controller!.stopImageStream();
      } catch (_) {}
      _isStreamRunning = false;
      _latestFrame = null;
    }
  }

  // ── Timer-based detection — pick up the latest frame every 1500ms ──
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
    print('✅ Detection timer started (1500ms)');
  }

  void _stopDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _runDetection() async {
    // Guard: skip if already running, camera not ready, or no frame yet.
    if (_isDetecting || !_isCameraReady || _latestFrame == null) return;
    _isDetecting = true;

    try {
      final frame = _latestFrame!;

      // detect() runs YUV preprocessing in an Isolate internally.
      final detections = await _detector.detect(frame);

      if (detections.isNotEmpty && mounted) {
        final best = detections.first; // already sorted by confidence in NMS
        final now = DateTime.now();
        final timePassed = now.difference(_lastSpeakTime).inSeconds >= 3;
        final differentObject = best.arabicLabel != _lastSpoken;

        if (differentObject || timePassed) {
          _lastSpoken = best.arabicLabel;
          _lastSpeakTime = now;
          if (mounted) {
            setState(() => _statusText =
                '${best.arabicLabel} (${(best.confidence * 100).toStringAsFixed(0)}%)');
          }
          await _tts.speak(best.arabicLabel);
        }
      }
    } catch (e) {
      print('⚠️ Detection loop error: $e');
    } finally {
      _isDetecting = false;
    }
  }

  // ── Cleanup ──
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _stopDetection();
    _stopStream();
    _controller?.dispose();
    _tts.stop();
    _detector.dispose();
    super.dispose();
  }

  // ── UI ──
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          if (_isCameraReady && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.previewSize!.height,
                  height: _controller!.value.previewSize!.width,
                  child: CameraPreview(_controller!),
                ),
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
                'وارين',
                style: TextStyle(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}