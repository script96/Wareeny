import 'dart:math' as math;
import 'dart:ui';

import 'package:wareeny/shared/object_detection/detection_models.dart';

class UprightDetection {
  const UprightDetection({required this.source, required this.normalizedBox});

  final ObjectDetection source;

  /// Display-oriented coordinates normalized to the range 0..1.
  final Rect normalizedBox;
}

class UprightDetectionFrame {
  const UprightDetectionFrame({
    required this.source,
    required this.imageSize,
    required this.detections,
  });

  final ObjectDetectionFrame source;
  final Size imageSize;
  final List<UprightDetection> detections;
}

class DetectionCoordinateMapper {
  const DetectionCoordinateMapper();

  UprightDetectionFrame orient(ObjectDetectionFrame frame) {
    final rotation = _normalizedRotation(frame.rotationDegrees);
    final rotated = rotation == 90 || rotation == 270;
    final imageSize = rotated
        ? Size(frame.sourceSize.height, frame.sourceSize.width)
        : frame.sourceSize;

    return UprightDetectionFrame(
      source: frame,
      imageSize: imageSize,
      detections: frame.detections
          .map((detection) {
            final box = detection.boundingBox;
            final corners =
                <Offset>[
                      box.topLeft,
                      box.topRight,
                      box.bottomLeft,
                      box.bottomRight,
                    ]
                    .map((point) {
                      final normalized = Offset(
                        point.dx / frame.sourceSize.width,
                        point.dy / frame.sourceSize.height,
                      );
                      var oriented = _rotate(normalized, rotation);
                      if (frame.mirrored) {
                        oriented = Offset(1 - oriented.dx, oriented.dy);
                      }
                      return oriented;
                    })
                    .toList(growable: false);

            final left = corners.map((point) => point.dx).reduce(math.min);
            final top = corners.map((point) => point.dy).reduce(math.min);
            final right = corners.map((point) => point.dx).reduce(math.max);
            final bottom = corners.map((point) => point.dy).reduce(math.max);

            return UprightDetection(
              source: detection,
              normalizedBox: Rect.fromLTRB(
                left.clamp(0, 1),
                top.clamp(0, 1),
                right.clamp(0, 1),
                bottom.clamp(0, 1),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Rect projectRect({
    required Rect normalizedRect,
    required Size imageSize,
    required Size viewportSize,
  }) {
    if (imageSize.isEmpty || viewportSize.isEmpty) return Rect.zero;

    final scale = math.max(
      viewportSize.width / imageSize.width,
      viewportSize.height / imageSize.height,
    );
    final renderedSize = Size(
      imageSize.width * scale,
      imageSize.height * scale,
    );
    final offset = Offset(
      (viewportSize.width - renderedSize.width) / 2,
      (viewportSize.height - renderedSize.height) / 2,
    );

    return Rect.fromLTRB(
      offset.dx + normalizedRect.left * renderedSize.width,
      offset.dy + normalizedRect.top * renderedSize.height,
      offset.dx + normalizedRect.right * renderedSize.width,
      offset.dy + normalizedRect.bottom * renderedSize.height,
    );
  }

  Offset projectPoint({
    required Offset normalizedPoint,
    required Size imageSize,
    required Size viewportSize,
  }) {
    final projected = projectRect(
      normalizedRect: Rect.fromLTWH(
        normalizedPoint.dx,
        normalizedPoint.dy,
        0,
        0,
      ),
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    return projected.topLeft;
  }

  int _normalizedRotation(int degrees) {
    final normalized = degrees % 360;
    return normalized < 0 ? normalized + 360 : normalized;
  }

  Offset _rotate(Offset point, int degrees) {
    return switch (degrees) {
      90 => Offset(1 - point.dy, point.dx),
      180 => Offset(1 - point.dx, 1 - point.dy),
      270 => Offset(point.dy, 1 - point.dx),
      _ => point,
    };
  }
}
