import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:wareny/presentation/reusable/camera_status_view.dart';

class CameraFrame {
  const CameraFrame({required this.image, required this.rotationDegrees});

  final CameraImage image;
  final int rotationDegrees;
}

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({this.onImage, super.key});

  final ValueChanged<CameraFrame>? onImage;

  @override
  State<CameraFeedView> createState() => _CameraFeedViewState();
}

class _CameraFeedViewState extends State<CameraFeedView> {
  CameraController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _startCamera();
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CameraFeedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (oldWidget.onImage == null && widget.onImage != null) {
      unawaited(
        _startImageStream(controller).catchError((Object error) {
          if (mounted) {
            setState(() => _error = error);
          }
        }),
      );
    } else if (oldWidget.onImage != null && widget.onImage == null) {
      unawaited(_stopImageStream(controller).catchError((_) {}));
    }
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
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() => _controller = controller);

      if (widget.onImage != null) {
        await _startImageStream(controller);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }

  Future<void> _startImageStream(CameraController controller) async {
    if (controller.value.isStreamingImages) {
      return;
    }

    await controller.startImageStream((image) {
      widget.onImage?.call(
        CameraFrame(
          image: image,
          rotationDegrees: controller.description.sensorOrientation,
        ),
      );
    });
  }

  Future<void> _stopImageStream(CameraController controller) async {
    if (!controller.value.isStreamingImages) {
      return;
    }

    await controller.stopImageStream();
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    unawaited(_disposeControllerAsync(controller));
  }

  Future<void> _disposeControllerAsync(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await _stopImageStream(controller);
      }
    } catch (_) {
      // Best-effort cleanup while the widget is leaving the tree.
    }

    try {
      await controller.dispose();
    } catch (_) {
      // Best-effort cleanup while the widget is leaving the tree.
    }
  }
}
