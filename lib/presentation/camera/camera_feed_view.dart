import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:wareeny/shared/bridges/indoor_navigation_bridge.dart';
import 'package:wareeny/presentation/reusable/camera_status_view.dart';

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({
    required this.indoorNavigationActive,
    required this.indoorNavigationBridge,
    super.key,
  });

  final bool indoorNavigationActive;
  final IndoorNavigationBridge indoorNavigationBridge;

  @override
  State<CameraFeedView> createState() => _CameraFeedViewState();
}

class _CameraFeedViewState extends State<CameraFeedView> {
  static const _frameInterval = Duration(milliseconds: 100);

  CameraController? _controller;
  Object? _error;
  DateTime? _lastFrameSentAt;
  var _sendingFrame = false;

  @override
  void didUpdateWidget(CameraFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.indoorNavigationActive != widget.indoorNavigationActive) {
      _syncImageStream();
    }
  }

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _stopImageStream();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_error != null) {
      return const CameraStatusView(
        icon: Icons.videocam_off_outlined,
        title: 'Camera unavailable',
        message: 'Check camera permission or run on a device with a camera.',
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const CameraStatusView(
        icon: Icons.videocam_outlined,
        title: 'Opening camera',
        message: 'Preparing live camera feed.',
      );
    }

    // Fill the full screen without distortion.
    // FittedBox with cover crops to fill, preserving the sensor's native ratio.
    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);
      _syncImageStream();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  void _syncImageStream() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (widget.indoorNavigationActive && !controller.value.isStreamingImages) {
      controller.startImageStream(_handleCameraImage);
    } else if (!widget.indoorNavigationActive &&
        controller.value.isStreamingImages) {
      _stopImageStream();
    }
  }

  Future<void> _stopImageStream() async {
    final controller = _controller;
    if (controller != null && controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    _sendingFrame = false;
    _lastFrameSentAt = null;
  }

  void _handleCameraImage(CameraImage image) {
    final now = DateTime.now();
    final lastSent = _lastFrameSentAt;
    if (_sendingFrame ||
        (lastSent != null && now.difference(lastSent) < _frameInterval)) {
      return;
    }

    _sendingFrame = true;
    _lastFrameSentAt = now;

    final frame = IndoorCameraFrame(
      width: image.width,
      height: image.height,
      format: image.format.group.name,
      timestampMillis: now.millisecondsSinceEpoch,
      planes: image.planes
          .map(
            (plane) => IndoorCameraPlane(
              bytes: plane.bytes,
              bytesPerRow: plane.bytesPerRow,
              bytesPerPixel: plane.bytesPerPixel,
            ),
          )
          .toList(growable: false),
    );

    widget.indoorNavigationBridge
        .processFrame(frame)
        .whenComplete(() => _sendingFrame = false);
  }
}
