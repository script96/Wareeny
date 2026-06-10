import 'dart:ui';

import 'package:wareeny/shared/object_detection/detection_coordinate_mapper.dart';

enum NavigationRisk { safe, caution, danger }

enum NavigationZone { left, center, right }

class NavigationPath {
  const NavigationPath({
    this.topY = 0.48,
    this.topLeft = 0.46,
    this.topRight = 0.54,
    this.bottomLeft = 0.30,
    this.bottomRight = 0.70,
    this.bottomDangerY = 0.78,
  });

  final double topY;
  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
  final double bottomDangerY;

  List<Offset> get polygon => [
    Offset(topLeft, topY),
    Offset(topRight, topY),
    Offset(bottomRight, 1),
    Offset(bottomLeft, 1),
  ];

  ({double left, double right}) boundsAt(double y) {
    final progress = ((y - topY) / (1 - topY)).clamp(0.0, 1.0);
    return (
      left: topLeft + (bottomLeft - topLeft) * progress,
      right: topRight + (bottomRight - topRight) * progress,
    );
  }
}

class NavigationObjectRisk {
  const NavigationObjectRisk({
    required this.detection,
    required this.risk,
    required this.zone,
    required this.insidePath,
    required this.centerInsidePath,
    required this.overlapRatio,
    required this.isBottomDanger,
    required this.isIgnored,
    this.ignoreReason,
  });

  final UprightDetection detection;
  final NavigationRisk risk;
  final NavigationZone zone;
  final bool insidePath;
  final bool centerInsidePath;
  final double overlapRatio;
  final bool isBottomDanger;
  final bool isIgnored;
  final String? ignoreReason;

  double get area =>
      detection.normalizedBox.width * detection.normalizedBox.height;

  String get fingerprint {
    final center = detection.normalizedBox.center;
    final location = '${(center.dx * 5).floor()}:${(center.dy * 5).floor()}';
    final id =
        detection.source.trackingId ?? '${detection.source.label}:$location';
    return '$id:${zone.name}:${risk.name}';
  }
}

class NavigationAssessment {
  const NavigationAssessment({required this.objects, required this.selected});

  final List<NavigationObjectRisk> objects;
  final NavigationObjectRisk? selected;

  NavigationRisk get highestRisk => selected?.risk ?? NavigationRisk.safe;
}
