import 'dart:ui';

import 'package:wareeny/shared/danger/danger_config.dart';

enum DangerNavigationMode { indoor, outdoor }

enum DangerKind {
  fire,
  wetFloorSign,
  stopSign,
  exitSign;

  int get priority => switch (this) {
    DangerKind.fire => 300,
    DangerKind.wetFloorSign || DangerKind.stopSign => 200,
    DangerKind.exitSign => 50,
  };

  String get debugLabel => switch (this) {
    DangerKind.fire => 'fire',
    DangerKind.wetFloorSign => 'wet floor sign',
    DangerKind.stopSign => 'stop sign',
    DangerKind.exitSign => 'exit sign',
  };

  double get confidenceThreshold => switch (this) {
    DangerKind.fire => DangerModeConfig.fireConfidence,
    DangerKind.stopSign => DangerModeConfig.stopSignConfidence,
    DangerKind.wetFloorSign => DangerModeConfig.wetFloorConfidence,
    DangerKind.exitSign => DangerModeConfig.exitSignConfidence,
  };

  Duration get cooldown => switch (this) {
    DangerKind.fire => DangerModeConfig.fireRepeatCooldown,
    DangerKind.stopSign => DangerModeConfig.stopSignCooldown,
    DangerKind.wetFloorSign => DangerModeConfig.wetFloorCooldown,
    DangerKind.exitSign => DangerModeConfig.exitSignCooldown,
  };

  int get hapticPulses => switch (this) {
    DangerKind.fire => 4,
    DangerKind.wetFloorSign || DangerKind.stopSign => 2,
    DangerKind.exitSign => 1,
  };
}

enum FireSeverity {
  none,
  normal,
  high,
  panic;

  String get debugLabel => switch (this) {
    FireSeverity.none => 'none',
    FireSeverity.normal => 'normal',
    FireSeverity.high => 'high',
    FireSeverity.panic => 'panic',
  };
}

class DangerRawDetection {
  const DangerRawDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.trackingId,
  });

  final String label;
  final double confidence;
  final Rect boundingBox;
  final String? trackingId;
}

class DangerDetectionResult {
  const DangerDetectionResult({
    required this.kind,
    required this.rawLabel,
    required this.mappedLabel,
    required this.confidence,
    required this.boundingBox,
    required this.sourceSize,
    required this.navigationMode,
    this.trackingId,
    this.ignoredReason,
    this.cooldownBlocked = false,
    this.cooldownRemaining,
  });

  final DangerKind kind;
  final String rawLabel;
  final String mappedLabel;
  final double confidence;
  final Rect boundingBox;
  final Size sourceSize;
  final DangerNavigationMode navigationMode;
  final String? trackingId;
  final String? ignoredReason;
  final bool cooldownBlocked;
  final Duration? cooldownRemaining;

  bool get isIgnored => ignoredReason != null;
  bool get isAlertCandidate => !isIgnored;
  int get priority => kind.priority;

  double get frameArea {
    final total = sourceSize.width * sourceSize.height;
    if (total <= 0) return 0;
    return (boundingBox.width * boundingBox.height / total).clamp(0.0, 1.0);
  }

  FireSeverity get fireSeverity {
    if (kind != DangerKind.fire) return FireSeverity.none;
    if (frameArea > DangerModeConfig.firePanicAreaThreshold) {
      return FireSeverity.panic;
    }
    if (frameArea >= DangerModeConfig.fireSmallAreaThreshold) {
      return FireSeverity.high;
    }
    return FireSeverity.normal;
  }

  String get warning => switch (kind) {
    DangerKind.fire => switch (fireSeverity) {
      FireSeverity.panic =>
        'خطر شديد، في نار قريبة جداً. ابعد فوراً وخلي بالك.',
      FireSeverity.high => 'خطر عالي، النار قريبة. ابعد فوراً وخلي بالك.',
      FireSeverity.normal ||
      FireSeverity.none => 'خطر، في نار قريبة منك. ابعد فوراً وخلي بالك.',
    },
    DangerKind.stopSign => 'قدامك علامة توقف. وقف وخلي بالك من الطريق حواليك.',
    DangerKind.wetFloorSign => 'خلي بالك، في علامة أرض مبلولة. امشي ببطء.',
    DangerKind.exitSign => 'علامة الخروج قريبة منك.',
  };

  String get fingerprint => '${kind.name}:${fireSeverity.name}';

  DangerDetectionResult copyWith({
    String? ignoredReason,
    bool? cooldownBlocked,
    Duration? cooldownRemaining,
  }) {
    return DangerDetectionResult(
      kind: kind,
      rawLabel: rawLabel,
      mappedLabel: mappedLabel,
      confidence: confidence,
      boundingBox: boundingBox,
      sourceSize: sourceSize,
      navigationMode: navigationMode,
      trackingId: trackingId,
      ignoredReason: ignoredReason ?? this.ignoredReason,
      cooldownBlocked: cooldownBlocked ?? this.cooldownBlocked,
      cooldownRemaining: cooldownRemaining ?? this.cooldownRemaining,
    );
  }
}

class DangerDetectionFrame {
  const DangerDetectionFrame({
    required this.frameId,
    required this.sourceSize,
    required this.detections,
    required this.timestamp,
    required this.modelSource,
    this.inferenceTime,
  });

  final int frameId;
  final Size sourceSize;
  final List<DangerDetectionResult> detections;
  final DateTime timestamp;
  final String modelSource;
  final Duration? inferenceTime;

  List<DangerDetectionResult> get alertCandidates =>
      detections.where((item) => item.isAlertCandidate).toList(growable: false);
}
