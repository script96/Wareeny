import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../detector.dart';
import '../../../widgets/overlays/bounding_box_painter.dart';

class CameraDetectionOverlay extends StatelessWidget {
  final Stream<List<Detection>> detectionStream;
  final CameraController? controller;
  final int sourceWidth;
  final int sourceHeight;
  final String? highlightLabel;
  final bool isVisible;

  const CameraDetectionOverlay({
    super.key,
    required this.detectionStream,
    required this.controller,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.highlightLabel,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: StreamBuilder<List<Detection>>(
        stream: detectionStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final currentController = controller;
              if (currentController == null ||
                  !currentController.value.isInitialized ||
                  currentController.value.previewSize == null) {
                return const SizedBox.shrink();
              }

              final metrics = _OverlayMetrics.from(
                currentController.value.previewSize!,
                Size(constraints.maxWidth, constraints.maxHeight),
              );

              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: BoundingBoxPainter(
                  detections: snapshot.data!,
                  sourceWidth: sourceWidth,
                  sourceHeight: sourceHeight,
                  displayWidth: metrics.displayWidth,
                  displayHeight: metrics.displayHeight,
                  offsetX: metrics.offsetX,
                  offsetY: metrics.offsetY,
                  highlightLabel: highlightLabel,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OverlayMetrics {
  final double displayWidth;
  final double displayHeight;
  final double offsetX;
  final double offsetY;

  const _OverlayMetrics({
    required this.displayWidth,
    required this.displayHeight,
    required this.offsetX,
    required this.offsetY,
  });

  factory _OverlayMetrics.from(Size previewSize, Size screenSize) {
    final previewWidth = previewSize.height;
    final previewHeight = previewSize.width;
    final scale = math.max(
      screenSize.width / previewWidth,
      screenSize.height / previewHeight,
    );

    final displayWidth = previewWidth * scale;
    final displayHeight = previewHeight * scale;

    return _OverlayMetrics(
      displayWidth: displayWidth,
      displayHeight: displayHeight,
      offsetX: (screenSize.width - displayWidth) / 2,
      offsetY: (screenSize.height - displayHeight) / 2,
    );
  }
}
