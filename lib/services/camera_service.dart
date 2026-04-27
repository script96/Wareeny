import 'package:camera/camera.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isInitialized = false;

  // ── Operation guards ──
  bool _isInitializing = false;
  bool _isDisposing = false;
  bool _isTakingPicture = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  /// Initialize the camera. Safe to call multiple times — returns
  /// immediately if already initialized. Skips if disposing or
  /// already initializing.
  Future<bool> init() async {
    if (_isInitialized && _controller != null) {
      return true; // Already initialized, don't double-init
    }
    if (_isInitializing || _isDisposing) {
      print('⚠️ Camera init skipped (initializing=$_isInitializing, disposing=$_isDisposing)');
      return false;
    }

    _isInitializing = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      _isInitialized = true;
      print('📷 Camera ready: ${_controller!.value.previewSize}');
      return true;
    } catch (e) {
      print('❌ Camera init error: $e');
      _isInitialized = false;
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  /// Take a snapshot. Returns null if camera is not ready, disposing,
  /// initializing, or already taking a picture.
  Future<XFile?> takeSnapshot() async {
    if (!_isInitialized || _controller == null) return null;
    if (_isTakingPicture || _isDisposing || _isInitializing) return null;

    _isTakingPicture = true;
    try {
      return await _controller!.takePicture();
    } catch (e) {
      print('⚠️ takeSnapshot error: $e');
      return null;
    } finally {
      _isTakingPicture = false;
    }
  }

  /// Release the camera. Safe to call multiple times.
  /// Skips if already disposing.
  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;

    try {
      if (_controller != null) {
        try {
          await _controller!.dispose();
        } catch (e) {
          print('⚠️ Camera dispose error: $e');
        }
      }
      _controller = null;
      _isInitialized = false;
    } finally {
      _isDisposing = false;
      _isTakingPicture = false;
    }
  }
}
