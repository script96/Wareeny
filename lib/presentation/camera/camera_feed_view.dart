import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:wareeny/presentation/reusable/camera_status_view.dart';

class CameraFeedView extends StatefulWidget {
  const CameraFeedView({super.key});

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
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    }
  }
}
