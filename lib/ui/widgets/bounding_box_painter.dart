import 'package:flutter/material.dart';
import '../../detector.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final int sourceWidth;
  final int sourceHeight;
  final double displayWidth;
  final double displayHeight;
  final double offsetX;
  final double offsetY;

  /// When set, the detection matching this label is drawn in amber
  /// with a thicker stroke to highlight the found target.
  final String? highlightLabel;

  BoundingBoxPainter({
    required this.detections,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.displayWidth,
    required this.displayHeight,
    required this.offsetX,
    required this.offsetY,
    this.highlightLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final normalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.amber;

    final textPainter = TextPainter(
      textDirection: TextDirection.rtl,
    );

    for (final d in detections) {
      final isHighlighted =
          highlightLabel != null && d.label == highlightLabel;
      final paint = isHighlighted ? highlightPaint : normalPaint;
      final accentColor = isHighlighted ? Colors.amber : Colors.greenAccent;

      // Map coordinates from original image to display size
      final x1 = (d.bbox[0] / sourceWidth) * displayWidth + offsetX;
      final y1 = (d.bbox[1] / sourceHeight) * displayHeight + offsetY;
      final x2 = (d.bbox[2] / sourceWidth) * displayWidth + offsetX;
      final y2 = (d.bbox[3] / sourceHeight) * displayHeight + offsetY;

      // Clamp to screen bounds so boxes and labels don't draw offscreen
      final clampedX1 = x1.clamp(0.0, size.width);
      final clampedY1 = y1.clamp(0.0, size.height);
      final clampedX2 = x2.clamp(0.0, size.width);
      final clampedY2 = y2.clamp(0.0, size.height);

      final rect = Rect.fromLTRB(clampedX1, clampedY1, clampedX2, clampedY2);
      canvas.drawRect(rect, paint);

      // Label text
      final labelText = '${d.arabicLabel} ${(d.confidence * 100).toStringAsFixed(0)}%';
      textPainter.text = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      textPainter.layout();

      // Clamp label position so it stays on screen
      final labelWidth = textPainter.width + 10;
      final labelHeight = 25.0;
      final labelX = clampedX1.clamp(0.0, (size.width - labelWidth).clamp(0.0, size.width));
      // If label would go above screen, push it below the top of the box
      final labelY = (clampedY1 - labelHeight) < 0
          ? clampedY1 + 2
          : clampedY1 - labelHeight;

      // Label background
      final bgPaint = Paint()..color = accentColor.withAlpha(180);
      canvas.drawRect(
        Rect.fromLTWH(labelX, labelY, labelWidth, labelHeight),
        bgPaint,
      );

      textPainter.paint(canvas, Offset(labelX + 5, labelY + 3));
    }
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}
