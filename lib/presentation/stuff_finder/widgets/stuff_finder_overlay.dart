import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';

class StuffFinderOverlay extends StatelessWidget {
  const StuffFinderOverlay({required this.frame, super.key});

  final UprightDetectionFrame? frame;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(painter: _StuffFinderOverlayPainter(frame)),
    );
  }
}

class _StuffFinderOverlayPainter extends CustomPainter {
  const _StuffFinderOverlayPainter(this.frame);

  final UprightDetectionFrame? frame;

  static const _mapper = DetectionCoordinateMapper();

  @override
  void paint(Canvas canvas, Size size) {
    final currentFrame = frame;
    if (currentFrame == null) return;

    for (final detection in currentFrame.detections) {
      final box = _mapper.projectRect(
        normalizedRect: detection.normalizedBox,
        imageSize: currentFrame.imageSize,
        viewportSize: size,
      );
      canvas.drawRect(
        box,
        Paint()
          ..color = AppColors.electricGreen
          ..strokeWidth = 4
          ..style = PaintingStyle.stroke,
      );
      _drawLabel(
        canvas,
        box,
        detection.source.label,
        detection.source.confidence,
      );
    }
  }

  void _drawLabel(Canvas canvas, Rect box, String label, double confidence) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '${label.toUpperCase()}  ${(confidence * 100).round()}%',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 280);
    const padding = EdgeInsets.symmetric(horizontal: 8, vertical: 5);
    final labelSize = Size(
      textPainter.width + padding.horizontal,
      textPainter.height + padding.vertical,
    );
    final top = (box.top - labelSize.height)
        .clamp(0, double.infinity)
        .toDouble();
    final origin = Offset(box.left, top);
    canvas.drawRect(
      origin & labelSize,
      Paint()..color = AppColors.electricGreen,
    );
    textPainter.paint(canvas, origin + padding.topLeft);
  }

  @override
  bool shouldRepaint(_StuffFinderOverlayPainter oldDelegate) {
    return frame?.source.frameId != oldDelegate.frame?.source.frameId;
  }
}
