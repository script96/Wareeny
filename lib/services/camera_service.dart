import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

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
  bool _isStreaming = false;
  bool _isConvertingFrame = false;
  int _lastFrameCaptureMs = 0;
  Uint8List? _latestAnalysisBytes;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  /// Initialize the camera. Safe to call multiple times.
  ///
  /// If a dispose is still in progress, waits up to 1 second for it
  /// to finish before attempting init (avoids silent failures caused
  /// by paused→resumed race conditions).
  Future<bool> init() async {
    if (_isInitialized && _controller != null) {
      return true; // Already initialized
    }

    // If currently disposing, wait for it to finish (up to 1s)
    if (_isDisposing) {
      const pollInterval = Duration(milliseconds: 50);
      const maxWait = Duration(seconds: 1);
      final deadline = DateTime.now().add(maxWait);
      while (_isDisposing && DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
      }
      if (_isDisposing) {
        print('⚠️ Camera init skipped — still disposing after 1s wait');
        return false;
      }
    }

    if (_isInitializing) {
      print('⚠️ Camera init skipped — already initializing');
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
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      if (Platform.isIOS) {
        await _startImageStream();
      }
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

  /// Take a snapshot. Returns null if camera is not ready.
  Future<XFile?> takeSnapshot() async {
    if (!_isInitialized || _controller == null) return null;
    if (_isTakingPicture || _isDisposing || _isInitializing) return null;

    _isTakingPicture = true;
    final shouldResumeStream = Platform.isIOS && _isStreaming;
    try {
      if (shouldResumeStream) {
        await _stopImageStream();
      }
      return await _controller!.takePicture();
    } catch (e) {
      print('⚠️ takeSnapshot error: $e');
      return null;
    } finally {
      if (shouldResumeStream &&
          !_isDisposing &&
          _controller != null &&
          _controller!.value.isInitialized) {
        await _startImageStream();
      }
      _isTakingPicture = false;
    }
  }

  Future<Uint8List?> takeAnalysisBytes() async {
    if (!_isInitialized || _controller == null) return null;

    if (Platform.isIOS) {
      if (_latestAnalysisBytes != null) {
        return _latestAnalysisBytes;
      }

      const pollInterval = Duration(milliseconds: 100);
      const maxWait = Duration(seconds: 1);
      final deadline = DateTime.now().add(maxWait);
      while (_latestAnalysisBytes == null && DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
      }
      return _latestAnalysisBytes;
    }

    final snapshot = await takeSnapshot();
    if (snapshot == null) return null;

    try {
      return await snapshot.readAsBytes();
    } finally {
      try {
        await File(snapshot.path).delete();
      } catch (_) {}
    }
  }

  Future<void> _startImageStream() async {
    if (!Platform.isIOS || _controller == null || _isStreaming) return;

    await _controller!.startImageStream((image) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_isConvertingFrame || now - _lastFrameCaptureMs < 600) {
        return;
      }
      _lastFrameCaptureMs = now;
      _cacheLatestFrame(image);
    });
    _isStreaming = true;
  }

  Future<void> _stopImageStream() async {
    if (_controller == null || !_isStreaming) return;
    try {
      await _controller!.stopImageStream();
    } catch (e) {
      print('⚠️ Image stream stop error: $e');
    } finally {
      _isStreaming = false;
    }
  }

  Future<void> _cacheLatestFrame(CameraImage image) async {
    _isConvertingFrame = true;
    try {
      final bytes = _cameraImageToJpeg(image);
      if (bytes != null) {
        _latestAnalysisBytes = bytes;
      }
    } catch (e) {
      print('⚠️ Frame conversion error: $e');
    } finally {
      _isConvertingFrame = false;
    }
  }

  Uint8List? _cameraImageToJpeg(CameraImage image) {
    if (image.format.group == ImageFormatGroup.jpeg && image.planes.isNotEmpty) {
      return Uint8List.fromList(image.planes.first.bytes);
    }

    if (image.format.group != ImageFormatGroup.bgra8888 ||
        image.planes.isEmpty) {
      return null;
    }

    final plane = image.planes.first;
    final bytes = plane.bytes;
    final imageBuffer = img.Image(width: image.width, height: image.height);

    for (int y = 0; y < image.height; y++) {
      final rowOffset = y * plane.bytesPerRow;
      for (int x = 0; x < image.width; x++) {
        final offset = rowOffset + (x * 4);
        if (offset + 3 >= bytes.length) continue;
        final b = bytes[offset];
        final g = bytes[offset + 1];
        final r = bytes[offset + 2];
        final a = bytes[offset + 3];
        imageBuffer.setPixelRgba(x, y, r, g, b, a);
      }
    }

    return Uint8List.fromList(img.encodeJpg(imageBuffer, quality: 80));
  }

  /// Release the camera. Safe to call multiple times.
  /// Must be awaited to prevent race conditions with init().
  Future<void> dispose() async {
    if (_isDisposing) return;
    _isDisposing = true;

    try {
      await _stopImageStream();
      if (_controller != null) {
        try {
          await _controller!.dispose();
        } catch (e) {
          print('⚠️ Camera dispose error: $e');
        }
      }
      _controller = null;
      _isInitialized = false;
      _latestAnalysisBytes = null;
    } finally {
      _isDisposing = false;
      _isTakingPicture = false;
      _isConvertingFrame = false;
    }
  }
}
