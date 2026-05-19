import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

class CameraPreviewLayer extends StatelessWidget {
  final CameraController? controller;

  const CameraPreviewLayer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final currentController = controller;
    if (currentController == null ||
        !currentController.value.isInitialized ||
        currentController.value.previewSize == null) {
      return const Positioned.fill(
        child: ColoredBox(
          color: AppColors.previewUnavailable,
          child: Center(
            child: Text(
              'CAMERA PREVIEW UNAVAILABLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: currentController.value.previewSize!.height,
          height: currentController.value.previewSize!.width,
          child: CameraPreview(
            currentController,
            key: ValueKey(currentController.cameraId),
          ),
        ),
      ),
    );
  }
}
