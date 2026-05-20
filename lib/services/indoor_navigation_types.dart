import '../detector.dart';
import 'depth_provider.dart';

enum DangerLevel { safe, caution, danger, stop }

enum NavigationCue {
  keepGoing,
  moveLeft,
  moveRight,
  obstacleAhead,
  wallAhead,
  stop,
}

class CorridorSnapshot {
  final double nearLeft;
  final double nearRight;
  final double farLeft;
  final double farRight;
  final double top;
  final double bottom;

  const CorridorSnapshot({
    this.nearLeft = 0.18,
    this.nearRight = 0.82,
    this.farLeft = 0.38,
    this.farRight = 0.62,
    this.top = 0.35,
    this.bottom = 0.95,
  });
}

class NavigationHazard {
  final String arabicLabel;
  final String position;
  final double overlapScore;
  final double proximityScore;
  final bool isWallLike;
  final Detection? detection;

  const NavigationHazard({
    required this.arabicLabel,
    required this.position,
    required this.overlapScore,
    required this.proximityScore,
    required this.isWallLike,
    this.detection,
  });
}

class IndoorNavigationDecision {
  final DangerLevel dangerLevel;
  final NavigationCue cue;
  final String spokenText;
  final String statusText;
  final List<NavigationHazard> hazards;
  final List<Detection> highlightedDetections;
  final bool wallLikely;
  final double freeSpaceRatio;
  final DepthSource depthSource;

  const IndoorNavigationDecision({
    required this.dangerLevel,
    required this.cue,
    required this.spokenText,
    required this.statusText,
    required this.hazards,
    required this.highlightedDetections,
    required this.wallLikely,
    required this.freeSpaceRatio,
    required this.depthSource,
  });
}
