import 'package:flutter/material.dart';

import '../../../detector.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final int sourceWidth;
  final int sourceHeight;
  final double displayWidth;
  final double displayHeight;
  final double offsetX;
  final double offsetY;
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
      ..strokeWidth = 3
      ..color = Colors.greenAccent;
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.amber;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (final detection in detections) {
      final isHighlighted =
          highlightLabel != null && detection.label == highlightLabel;
      final rect = _scaledRect(detection, size);
      final accentColor = isHighlighted ? Colors.amber : Colors.greenAccent;

      canvas.drawRect(rect, isHighlighted ? highlightPaint : normalPaint);
      _paintLabel(
        canvas: canvas,
        size: size,
        rect: rect,
        accentColor: accentColor,
        textPainter: textPainter,
        text:
            '${detection.arabicLabel} ${(detection.confidence * 100).toStringAsFixed(0)}%',
      );
    }
  }

  Rect _scaledRect(Detection detection, Size size) {
    final x1 = (detection.bbox[0] / sourceWidth) * displayWidth + offsetX;
    final y1 = (detection.bbox[1] / sourceHeight) * displayHeight + offsetY;
    final x2 = (detection.bbox[2] / sourceWidth) * displayWidth + offsetX;
    final y2 = (detection.bbox[3] / sourceHeight) * displayHeight + offsetY;

    return Rect.fromLTRB(
      x1.clamp(0.0, size.width),
      y1.clamp(0.0, size.height),
      x2.clamp(0.0, size.width),
      y2.clamp(0.0, size.height),
    );
  }

  void _paintLabel({
    required Canvas canvas,
    required Size size,
    required Rect rect,
    required Color accentColor,
    required TextPainter textPainter,
    required String text,
  }) {
    textPainter.text = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.black,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();

    final labelWidth = textPainter.width + 10;
    final labelHeight = 25.0;
    final labelX = rect.left.clamp(
      0.0,
      (size.width - labelWidth).clamp(0.0, size.width),
    );
    final labelY = (rect.top - labelHeight) < 0
        ? rect.top + 2
        : rect.top - labelHeight;
    final labelRect = Rect.fromLTWH(labelX, labelY, labelWidth, labelHeight);

    canvas.drawRect(labelRect, Paint()..color = accentColor.withAlpha(180));
    textPainter.paint(canvas, Offset(labelX + 5, labelY + 3));
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) => true;
}
