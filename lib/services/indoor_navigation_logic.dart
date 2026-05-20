import 'dart:math' as math;

import '../detector.dart';
import 'depth_provider.dart';
import 'indoor_navigation_types.dart';

class IndoorNavigationLogic {
  static const CorridorSnapshot corridor = CorridorSnapshot();

  static IndoorNavigationDecision evaluate({
    required List<Detection> detections,
    required int imageWidth,
    required int imageHeight,
    required DepthFrame depthFrame,
  }) {
    final hazards = <NavigationHazard>[];
    final highlighted = <Detection>[];

    for (final detection in detections) {
      final overlap = _corridorOverlap(
        detection: detection,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
      );
      if (overlap < 0.18) continue;

      final bboxHeightRatio =
          ((detection.bbox[3] - detection.bbox[1]).abs() / imageHeight).clamp(
            0.0,
            1.0,
          );
      final bboxAreaRatio =
          (((detection.bbox[2] - detection.bbox[0]).abs() *
                      (detection.bbox[3] - detection.bbox[1]).abs()) /
                  (imageWidth * imageHeight))
              .clamp(0.0, 1.0);
      final bottomRatio = (detection.bbox[3] / imageHeight).clamp(0.0, 1.0);
      final proximity =
          ((bboxAreaRatio * 1.4) +
                  (bboxHeightRatio * 0.7) +
                  (bottomRatio * 0.4))
              .clamp(0.0, 1.0);
      final position = _detectionPosition(detection, imageWidth);

      hazards.add(
        NavigationHazard(
          arabicLabel: detection.arabicLabel,
          position: position,
          overlapScore: overlap,
          proximityScore: proximity,
          isWallLike: false,
          detection: detection,
        ),
      );
      highlighted.add(detection);
    }

    final depthStats = _analyzeDepth(depthFrame);
    final strongestHazard = hazards.isEmpty
        ? null
        : (hazards
                ..sort((a, b) => b.proximityScore.compareTo(a.proximityScore)))
              .first;

    if (depthStats.wallLikely) {
      hazards.insert(
        0,
        NavigationHazard(
          arabicLabel: 'حيطة',
          position: depthStats.wallSide,
          overlapScore: depthStats.centerNearRatio,
          proximityScore: depthStats.maxCloseness,
          isWallLike: true,
        ),
      );
    }

    final maxThreat = math.max(
      strongestHazard?.proximityScore ?? 0.0,
      depthStats.maxCloseness,
    );

    DangerLevel level = DangerLevel.safe;
    if (depthStats.wallLikely && maxThreat >= 0.82) {
      level = DangerLevel.stop;
    } else if (maxThreat >= 0.76 || depthStats.centerNearRatio >= 0.48) {
      level = DangerLevel.danger;
    } else if (maxThreat >= 0.58 ||
        depthStats.leftNearRatio >= 0.32 ||
        depthStats.rightNearRatio >= 0.32) {
      level = DangerLevel.caution;
    }

    NavigationCue cue = NavigationCue.keepGoing;
    if (level == DangerLevel.stop) {
      cue = NavigationCue.stop;
    } else if (depthStats.wallLikely && level != DangerLevel.safe) {
      if (depthStats.freeRight > depthStats.freeLeft + 0.12) {
        cue = NavigationCue.moveRight;
      } else if (depthStats.freeLeft > depthStats.freeRight + 0.12) {
        cue = NavigationCue.moveLeft;
      } else {
        cue = NavigationCue.wallAhead;
      }
    } else if ((strongestHazard?.position == 'left' &&
            strongestHazard!.proximityScore >= 0.38) ||
        depthStats.leftNearRatio > depthStats.rightNearRatio + 0.12) {
      cue = NavigationCue.moveRight;
    } else if ((strongestHazard?.position == 'right' &&
            strongestHazard!.proximityScore >= 0.38) ||
        depthStats.rightNearRatio > depthStats.leftNearRatio + 0.12) {
      cue = NavigationCue.moveLeft;
    } else if (level != DangerLevel.safe) {
      cue = NavigationCue.obstacleAhead;
    }

    final spokenText = _spokenTextForCue(cue, depthStats.wallLikely, level);
    final statusText = _statusTextForCue(cue, level, depthStats, hazards);

    return IndoorNavigationDecision(
      dangerLevel: level,
      cue: cue,
      spokenText: spokenText,
      statusText: statusText,
      hazards: hazards,
      highlightedDetections: highlighted,
      wallLikely: depthStats.wallLikely,
      freeSpaceRatio: depthStats.freeRatio,
      depthSource: depthFrame.source,
    );
  }

  static double _corridorOverlap({
    required Detection detection,
    required int imageWidth,
    required int imageHeight,
  }) {
    final x1 = detection.bbox[0] / imageWidth;
    final y1 = detection.bbox[1] / imageHeight;
    final x2 = detection.bbox[2] / imageWidth;
    final y2 = detection.bbox[3] / imageHeight;

    final verticalOverlap = _rangeOverlap(
      y1,
      y2,
      corridor.top,
      corridor.bottom,
    );
    if (verticalOverlap <= 0) return 0;

    final centerY = ((y1 + y2) / 2).clamp(0.0, 1.0);
    final left = _corridorLeft(centerY);
    final right = _corridorRight(centerY);
    final horizontalOverlap = _rangeOverlap(x1, x2, left, right);
    if (horizontalOverlap <= 0) return 0;

    final bboxWidth = (x2 - x1).abs().clamp(0.0001, 1.0);
    final bboxHeight = (y2 - y1).abs().clamp(0.0001, 1.0);
    return ((horizontalOverlap / bboxWidth) * (verticalOverlap / bboxHeight))
        .clamp(0.0, 1.0);
  }

  static String _detectionPosition(Detection detection, int imageWidth) {
    final center = ((detection.bbox[0] + detection.bbox[2]) / 2) / imageWidth;
    if (center < 0.44) return 'left';
    if (center > 0.56) return 'right';
    return 'center';
  }

  static _DepthStats _analyzeDepth(DepthFrame frame) {
    const sampleRows = 18;
    const sampleCols = 18;
    int total = 0;
    int free = 0;
    int leftNear = 0;
    int centerNear = 0;
    int rightNear = 0;
    double maxCloseness = 0;
    double freeLeft = 0;
    double freeRight = 0;

    for (int row = 0; row < sampleRows; row++) {
      final yNorm =
          corridor.top +
          ((corridor.bottom - corridor.top) * (row / (sampleRows - 1)));
      final leftBound = _corridorLeft(yNorm);
      final rightBound = _corridorRight(yNorm);

      int rowFreeLeft = 0;
      int rowFreeRight = 0;
      for (int col = 0; col < sampleCols; col++) {
        final xNorm =
            leftBound + ((rightBound - leftBound) * (col / (sampleCols - 1)));
        final closeness = frame.sampleNormalized(xNorm, yNorm);
        maxCloseness = math.max(maxCloseness, closeness);
        total++;

        final isFree = closeness < 0.58;
        if (isFree) {
          free++;
          if (col < sampleCols / 2) {
            rowFreeLeft++;
          } else {
            rowFreeRight++;
          }
        }

        if (closeness >= 0.66) {
          if (col < sampleCols / 3) {
            leftNear++;
          } else if (col >= (sampleCols * 2 / 3)) {
            rightNear++;
          } else {
            centerNear++;
          }
        }
      }
      freeLeft += rowFreeLeft / (sampleCols / 2);
      freeRight += rowFreeRight / (sampleCols / 2);
    }

    final leftNearRatio = leftNear / (sampleRows * (sampleCols / 3));
    final centerNearRatio = centerNear / (sampleRows * (sampleCols / 3));
    final rightNearRatio = rightNear / (sampleRows * (sampleCols / 3));
    final freeRatio = total == 0 ? 1.0 : free / total;
    freeLeft /= sampleRows;
    freeRight /= sampleRows;

    final wallLikely =
        centerNearRatio >= 0.44 && (leftNearRatio + rightNearRatio) >= 0.72;
    final wallSide = freeRight > freeLeft + 0.12
        ? 'left'
        : (freeLeft > freeRight + 0.12 ? 'right' : 'center');

    return _DepthStats(
      leftNearRatio: leftNearRatio,
      centerNearRatio: centerNearRatio,
      rightNearRatio: rightNearRatio,
      freeRatio: freeRatio,
      maxCloseness: maxCloseness,
      wallLikely: wallLikely,
      wallSide: wallSide,
      freeLeft: freeLeft,
      freeRight: freeRight,
    );
  }

  static String _spokenTextForCue(
    NavigationCue cue,
    bool wallLikely,
    DangerLevel level,
  ) {
    switch (cue) {
      case NavigationCue.keepGoing:
        return 'كمل';
      case NavigationCue.moveLeft:
        return 'اتجه يسار';
      case NavigationCue.moveRight:
        return 'اتجه يمين';
      case NavigationCue.obstacleAhead:
        return 'في عائق قدامك';
      case NavigationCue.wallAhead:
        return wallLikely && level != DangerLevel.stop
            ? 'قربت من الحيطة'
            : 'في عائق قدامك';
      case NavigationCue.stop:
        return 'قف حالاً';
    }
  }

  static String _statusTextForCue(
    NavigationCue cue,
    DangerLevel level,
    _DepthStats depthStats,
    List<NavigationHazard> hazards,
  ) {
    final levelText = switch (level) {
      DangerLevel.safe => 'آمن',
      DangerLevel.caution => 'تنبيه',
      DangerLevel.danger => 'خطر',
      DangerLevel.stop => 'قف',
    };

    final cueText = _spokenTextForCue(cue, depthStats.wallLikely, level);
    final topHazard = hazards.isEmpty ? '' : ' - ${hazards.first.arabicLabel}';
    return 'الملاحة الداخلية: $levelText - $cueText$topHazard';
  }

  static double _rangeOverlap(double a1, double a2, double b1, double b2) {
    final left = math.max(math.min(a1, a2), math.min(b1, b2));
    final right = math.min(math.max(a1, a2), math.max(b1, b2));
    return math.max(0.0, right - left);
  }

  static double _corridorLeft(double yNorm) {
    final t = ((yNorm - corridor.top) / (corridor.bottom - corridor.top)).clamp(
      0.0,
      1.0,
    );
    return corridor.farLeft + ((corridor.nearLeft - corridor.farLeft) * t);
  }

  static double _corridorRight(double yNorm) {
    final t = ((yNorm - corridor.top) / (corridor.bottom - corridor.top)).clamp(
      0.0,
      1.0,
    );
    return corridor.farRight + ((corridor.nearRight - corridor.farRight) * t);
  }
}

class _DepthStats {
  final double leftNearRatio;
  final double centerNearRatio;
  final double rightNearRatio;
  final double freeRatio;
  final double maxCloseness;
  final bool wallLikely;
  final String wallSide;
  final double freeLeft;
  final double freeRight;

  const _DepthStats({
    required this.leftNearRatio,
    required this.centerNearRatio,
    required this.rightNearRatio,
    required this.freeRatio,
    required this.maxCloseness,
    required this.wallLikely,
    required this.wallSide,
    required this.freeLeft,
    required this.freeRight,
  });
}
