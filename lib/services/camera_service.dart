import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

class CameraService {
  static const int _analysisFrameIntervalMs = 180;
  static const int _analysisMaxDimension = 640;
  static const int _analysisJpegQuality = 72;

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
  bool _analysisStreamRequested = false;
  final StreamController<Uint8List> _analysisFrameController =
      StreamController<Uint8List>.broadcast();

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  Uint8List? get latestAnalysisBytes => _latestAnalysisBytes;
  bool get isAnalysisStreaming => _analysisStreamRequested;
  Stream<Uint8List> get analysisFrameStream => _analysisFrameController.stream;

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
            : ImageFormatGroup.yuv420,
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

  /// Take a snapshot. Returns null if camera is not ready.
  Future<XFile?> takeSnapshot() async {
    if (!_isInitialized || _controller == null) return null;
    if (_isTakingPicture || _isDisposing || _isInitializing) return null;

    _isTakingPicture = true;
    final shouldResumeStream = _isStreaming;
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

  Future<Uint8List?> takeAnalysisBytes({
    bool allowSnapshotFallback = true,
  }) async {
    if (!_isInitialized || _controller == null) return null;

    if (_analysisStreamRequested) {
      if (_latestAnalysisBytes != null) {
        return _latestAnalysisBytes;
      }

      const pollInterval = Duration(milliseconds: 100);
      const maxWait = Duration(seconds: 1);
      final deadline = DateTime.now().add(maxWait);
      while (_latestAnalysisBytes == null &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);
      }
      return _latestAnalysisBytes;
    }

    if (!allowSnapshotFallback) {
      return null;
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

  Future<void> startAnalysisStream() async {
    _analysisStreamRequested = true;
    await _startImageStream();
  }

  Future<void> stopAnalysisStream() async {
    _analysisStreamRequested = false;
    await _stopImageStream();
  }

  Future<void> _startImageStream() async {
    if (_controller == null || _isStreaming) return;

    await _controller!.startImageStream((image) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_isConvertingFrame ||
          now - _lastFrameCaptureMs < _analysisFrameIntervalMs) {
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
        if (!_analysisFrameController.isClosed) {
          _analysisFrameController.add(bytes);
        }
      }
    } catch (e) {
      print('⚠️ Frame conversion error: $e');
    } finally {
      _isConvertingFrame = false;
    }
  }

  Uint8List? _cameraImageToJpeg(CameraImage image) {
    if (image.format.group == ImageFormatGroup.jpeg &&
        image.planes.isNotEmpty) {
      return Uint8List.fromList(image.planes.first.bytes);
    }

    final sampleStep = _analysisSampleStep(image.width, image.height);
    final outputWidth = math.max(1, image.width ~/ sampleStep);
    final outputHeight = math.max(1, image.height ~/ sampleStep);

    if (image.format.group == ImageFormatGroup.bgra8888 &&
        image.planes.isNotEmpty) {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      final imageBuffer = img.Image(width: outputWidth, height: outputHeight);

      for (int y = 0; y < outputHeight; y++) {
        final sourceY = math.min(image.height - 1, y * sampleStep);
        final rowOffset = sourceY * plane.bytesPerRow;
        for (int x = 0; x < outputWidth; x++) {
          final sourceX = math.min(image.width - 1, x * sampleStep);
          final offset = rowOffset + (sourceX * 4);
          if (offset + 3 >= bytes.length) continue;
          final b = bytes[offset];
          final g = bytes[offset + 1];
          final r = bytes[offset + 2];
          final a = bytes[offset + 3];
          imageBuffer.setPixelRgba(x, y, r, g, b, a);
        }
      }

      return Uint8List.fromList(
        img.encodeJpg(imageBuffer, quality: _analysisJpegQuality),
      );
    }

    if (image.format.group != ImageFormatGroup.yuv420 ||
        image.planes.length < 3) {
      return null;
    }

    final imageBuffer = img.Image(width: outputWidth, height: outputHeight);
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < outputHeight; y++) {
      final sourceY = math.min(image.height - 1, y * sampleStep);
      for (int x = 0; x < outputWidth; x++) {
        final sourceX = math.min(image.width - 1, x * sampleStep);
        final uvIndex =
            (uvPixelStride * (sourceX ~/ 2)) + (uvRowStride * (sourceY ~/ 2));
        final index = (sourceY * yPlane.bytesPerRow) + sourceX;

        final yp = yPlane.bytes[index];
        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        final r = (yp + (1.370705 * (vp - 128))).round();
        final g = (yp - (0.337633 * (up - 128)) - (0.698001 * (vp - 128)))
            .round();
        final b = (yp + (1.732446 * (up - 128))).round();

        imageBuffer.setPixelRgb(
          x,
          y,
          math.max(0, math.min(255, r)),
          math.max(0, math.min(255, g)),
          math.max(0, math.min(255, b)),
        );
      }
    }

    return Uint8List.fromList(
      img.encodeJpg(imageBuffer, quality: _analysisJpegQuality),
    );
  }

  int _analysisSampleStep(int width, int height) {
    final longestSide = math.max(width, height);
    if (longestSide <= _analysisMaxDimension) {
      return 1;
    }
    return math.max(1, (longestSide / _analysisMaxDimension).ceil());
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
