import 'package:flutter/material.dart';

import 'package:wareeny/core/theme/app_colors.dart';
import 'package:wareeny/shared/navigation/navigation_models.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';

class NavigationOverlay extends StatelessWidget {
  const NavigationOverlay({
    required this.path,
    required this.frame,
    required this.assessment,
    required this.showDebug,
    required this.logProjection,
    super.key,
  });

  final NavigationPath path;
  final UprightDetectionFrame? frame;
  final NavigationAssessment assessment;
  final bool showDebug;
  final bool logProjection;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: _NavigationOverlayPainter(
          path: path,
          frame: frame,
          assessment: assessment,
          showDebug: showDebug,
          logProjection: logProjection,
        ),
      ),
    );
  }
}

class _NavigationOverlayPainter extends CustomPainter {
  const _NavigationOverlayPainter({
    required this.path,
    required this.frame,
    required this.assessment,
    required this.showDebug,
    required this.logProjection,
  });

  final NavigationPath path;
  final UprightDetectionFrame? frame;
  final NavigationAssessment assessment;
  final bool showDebug;
  final bool logProjection;

  static const _mapper = DetectionCoordinateMapper();

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = frame?.imageSize ?? size;
    final pathPoints = path.polygon
        .map(
          (point) => _mapper.projectPoint(
            normalizedPoint: point,
            imageSize: imageSize,
            viewportSize: size,
          ),
        )
        .toList(growable: false);

    _drawPath(canvas, size, imageSize, pathPoints);
    if (frame != null) {
      _drawDetections(canvas, size, frame!);
    }
  }

  void _drawPath(
    Canvas canvas,
    Size size,
    Size imageSize,
    List<Offset> points,
  ) {
    final polygon = Path()..addPolygon(points, true);
    canvas.drawPath(
      polygon,
      Paint()
        ..color = AppColors.electricGreen.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      polygon,
      Paint()
        ..color = AppColors.electricGreen.withValues(alpha: 0.9)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );

    final dangerBounds = path.boundsAt(path.bottomDangerY);
    final danger =
        [
          Offset(dangerBounds.left, path.bottomDangerY),
          Offset(dangerBounds.right, path.bottomDangerY),
          Offset(path.bottomRight, 1),
          Offset(path.bottomLeft, 1),
        ].map(
          (point) => _mapper.projectPoint(
            normalizedPoint: point,
            imageSize: imageSize,
            viewportSize: size,
          ),
        );
    canvas.drawPath(
      Path()..addPolygon(danger.toList(growable: false), true),
      Paint()
        ..color = AppColors.alertRed.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    if (!showDebug) return;
    for (final fraction in const [1 / 3, 2 / 3]) {
      final topX = path.topLeft + (path.topRight - path.topLeft) * fraction;
      final bottomX =
          path.bottomLeft + (path.bottomRight - path.bottomLeft) * fraction;
      final start = _mapper.projectPoint(
        normalizedPoint: Offset(topX, path.topY),
        imageSize: imageSize,
        viewportSize: size,
      );
      final end = _mapper.projectPoint(
        normalizedPoint: Offset(bottomX, 1),
        imageSize: imageSize,
        viewportSize: size,
      );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.white38
          ..strokeWidth = 1,
      );
    }
  }

  void _drawDetections(
    Canvas canvas,
    Size size,
    UprightDetectionFrame uprightFrame,
  ) {
    for (final item in assessment.objects) {
      final screenBox = _mapper.projectRect(
        normalizedRect: item.detection.normalizedBox,
        imageSize: uprightFrame.imageSize,
        viewportSize: size,
      );
      final color = switch (item.risk) {
        NavigationRisk.safe => Colors.white70,
        NavigationRisk.caution => AppColors.signalAmber,
        NavigationRisk.danger => AppColors.alertRed,
      };
      canvas.drawRect(
        screenBox,
        Paint()
          ..color = color
          ..strokeWidth = item.risk == NavigationRisk.danger ? 4 : 2
          ..style = PaintingStyle.stroke,
      );
      _drawLabel(canvas, screenBox, item, color);

      if (logProjection) {
        debugPrint(
          '[Navigation] screen box label=${item.detection.source.label} '
          'box=$screenBox viewport=$size',
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Rect box,
    NavigationObjectRisk item,
    Color color,
  ) {
    final confidence = (item.detection.source.confidence * 100).round();
    final inside = item.insidePath ? 'IN PATH' : 'OUTSIDE PATH';
    final trackingId = item.detection.source.trackingId;
    final details = showDebug
        ? [
            '$confidence%',
            item.risk.name.toUpperCase(),
            inside,
            if (trackingId != null) 'ID $trackingId',
          ].join('  ')
        : '$confidence%';
    final painter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: item.detection.source.label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          TextSpan(
            text: '\n$details',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '...',
    )..layout(maxWidth: 300);
    const padding = EdgeInsets.symmetric(horizontal: 7, vertical: 5);
    final labelSize = Size(
      painter.width + padding.horizontal,
      painter.height + padding.vertical,
    );
    final origin = Offset(
      box.left,
      (box.top - labelSize.height - 3).clamp(0, double.infinity),
    );
    canvas.drawRect(
      origin & labelSize,
      Paint()..color = color.withValues(alpha: 0.92),
    );
    painter.paint(canvas, origin + padding.topLeft);
  }

  @override
  bool shouldRepaint(_NavigationOverlayPainter oldDelegate) {
    return frame?.source.frameId != oldDelegate.frame?.source.frameId ||
        showDebug != oldDelegate.showDebug ||
        assessment != oldDelegate.assessment;
  }
}
