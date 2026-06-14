import 'dart:ui';

import 'package:wareeny/shared/navigation/navigation_models.dart';
import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';

class NavigationRiskConfig {
  const NavigationRiskConfig({
    this.minimumConfidence = 0.45,
    this.minimumBoxArea = 0.003,
    this.minimumOverlapRatio = 0.08,
    this.largeBoxArea = 0.18,
  });

  final double minimumConfidence;
  final double minimumBoxArea;
  final double minimumOverlapRatio;
  final double largeBoxArea;
}

class NavigationRiskEngine {
  const NavigationRiskEngine({
    this.path = const NavigationPath(),
    this.config = const NavigationRiskConfig(),
  });

  final NavigationPath path;
  final NavigationRiskConfig config;

  NavigationAssessment assess(
    UprightDetectionFrame frame, {
    bool indoorMode = false,
  }) {
    final objects = frame.detections
        .map((detection) => _assessDetection(detection, indoorMode: indoorMode))
        .toList(growable: false);
    final candidates = objects.where(
      (item) => !item.isIgnored && item.risk != NavigationRisk.safe,
    );
    final selected = candidates.isEmpty
        ? null
        : candidates.reduce(
            (current, next) =>
                _priority(next) > _priority(current) ? next : current,
          );

    return NavigationAssessment(objects: objects, selected: selected);
  }

  NavigationObjectRisk _assessDetection(
    UprightDetection detection, {
    required bool indoorMode,
  }) {
    final box = detection.normalizedBox;
    final area = box.width * box.height;
    final confidence = detection.source.confidence;
    final zone = _zoneFor(box.center);

    if (confidence < config.minimumConfidence) {
      return _ignored(detection, zone, 'low confidence');
    }
    if (area < config.minimumBoxArea) {
      return _ignored(detection, zone, 'tiny bounding box');
    }

    final isSlipHazard =
        indoorMode &&
        indoorSlipHazardLabels.contains(
          detection.source.label.trim().toLowerCase(),
        );
    final centerInside = _pointInPolygon(box.center, path.polygon);
    final intersectionArea = _polygonArea(
      _clipPolygonToRect(path.polygon, box),
    );
    final overlapRatio = area == 0 ? 0.0 : intersectionArea / area;
    final overlaps = overlapRatio >= config.minimumOverlapRatio;
    final bottomDanger =
        overlaps &&
        box.bottom >= path.bottomDangerY &&
        zone == NavigationZone.center;
    final largeInside = overlaps && area >= config.largeBoxArea;

    final risk = isSlipHazard
        ? NavigationRisk.caution
        : centerInside || bottomDanger || largeInside
        ? NavigationRisk.danger
        : overlaps
        ? NavigationRisk.caution
        : NavigationRisk.safe;

    return NavigationObjectRisk(
      detection: detection,
      risk: risk,
      zone: zone,
      insidePath: isSlipHazard || overlaps || centerInside,
      centerInsidePath: centerInside,
      overlapRatio: overlapRatio.clamp(0, 1),
      isBottomDanger: isSlipHazard ? false : bottomDanger,
      isIgnored: false,
    );
  }

  NavigationObjectRisk _ignored(
    UprightDetection detection,
    NavigationZone zone,
    String reason,
  ) {
    return NavigationObjectRisk(
      detection: detection,
      risk: NavigationRisk.safe,
      zone: zone,
      insidePath: false,
      centerInsidePath: false,
      overlapRatio: 0,
      isBottomDanger: false,
      isIgnored: true,
      ignoreReason: reason,
    );
  }

  NavigationZone _zoneFor(Offset point) {
    final bounds = path.boundsAt(point.dy);
    final width = bounds.right - bounds.left;
    if (point.dx < bounds.left + width / 3) return NavigationZone.left;
    if (point.dx > bounds.right - width / 3) return NavigationZone.right;
    return NavigationZone.center;
  }

  double _priority(NavigationObjectRisk item) {
    final risk = item.risk == NavigationRisk.danger ? 1000 : 100;
    final bottom = item.isBottomDanger ? 200 : 0;
    final center = item.zone == NavigationZone.center ? 50 : 0;
    return risk +
        bottom +
        center +
        item.area * 100 +
        item.detection.source.confidence;
  }

  bool _pointInPolygon(Offset point, List<Offset> polygon) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final intersects =
          ((a.dy > point.dy) != (b.dy > point.dy)) &&
          (point.dx < (b.dx - a.dx) * (point.dy - a.dy) / (b.dy - a.dy) + a.dx);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  List<Offset> _clipPolygonToRect(List<Offset> polygon, Rect rect) {
    var output = polygon;
    output = _clip(output, (p) => p.dx >= rect.left, (a, b) {
      final t = (rect.left - a.dx) / (b.dx - a.dx);
      return Offset(rect.left, a.dy + (b.dy - a.dy) * t);
    });
    output = _clip(output, (p) => p.dx <= rect.right, (a, b) {
      final t = (rect.right - a.dx) / (b.dx - a.dx);
      return Offset(rect.right, a.dy + (b.dy - a.dy) * t);
    });
    output = _clip(output, (p) => p.dy >= rect.top, (a, b) {
      final t = (rect.top - a.dy) / (b.dy - a.dy);
      return Offset(a.dx + (b.dx - a.dx) * t, rect.top);
    });
    output = _clip(output, (p) => p.dy <= rect.bottom, (a, b) {
      final t = (rect.bottom - a.dy) / (b.dy - a.dy);
      return Offset(a.dx + (b.dx - a.dx) * t, rect.bottom);
    });
    return output;
  }

  List<Offset> _clip(
    List<Offset> input,
    bool Function(Offset point) isInside,
    Offset Function(Offset start, Offset end) intersection,
  ) {
    if (input.isEmpty) return const [];
    final output = <Offset>[];
    var start = input.last;
    for (final end in input) {
      final startInside = isInside(start);
      final endInside = isInside(end);
      if (endInside) {
        if (!startInside) output.add(intersection(start, end));
        output.add(end);
      } else if (startInside) {
        output.add(intersection(start, end));
      }
      start = end;
    }
    return output;
  }

  double _polygonArea(List<Offset> polygon) {
    if (polygon.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final next = polygon[(i + 1) % polygon.length];
      sum += polygon[i].dx * next.dy - next.dx * polygon[i].dy;
    }
    return sum.abs() / 2;
  }
}
