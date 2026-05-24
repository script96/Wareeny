import 'dart:async';

import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

enum IndoorPathSeverity { clear, navigationCue, obstacle, danger, uncertain }

enum IndoorPathCode {
  clearPath('clear_path', 'CLEAR PATH'),
  cautionLeft('caution_left', 'CAUTION LEFT'),
  cautionRight('caution_right', 'CAUTION RIGHT'),
  obstacleAhead('obstacle_ahead', 'OBSTACLE AHEAD'),
  tripHazardCenter('trip_hazard_center', 'TRIP HAZARD CENTER'),
  moveLeft('move_left', 'MOVE LEFT'),
  moveRight('move_right', 'MOVE RIGHT'),
  forwardKeepCenter('forward_keep_center', 'FORWARD A LITTLE'),
  forwardThenSlightLeft(
    'forward_then_slight_left',
    'FORWARD THEN SLIGHT LEFT',
  ),
  forwardThenSlightRight(
    'forward_then_slight_right',
    'FORWARD THEN SLIGHT RIGHT',
  ),
  keepLeft('keep_left', 'KEEP LEFT'),
  keepRight('keep_right', 'KEEP RIGHT'),
  narrowPath('narrow_path', 'NARROW PATH'),
  pathBlocked('path_blocked', 'PATH BLOCKED'),
  lowLightUncertain('low_light_uncertain', 'LOW LIGHT - UNCERTAIN');

  const IndoorPathCode(this.value, this.prototypeText);

  final String value;
  final String prototypeText;

  static IndoorPathCode? fromValue(String value) {
    for (final code in values) {
      if (code.value == value) {
        return code;
      }
    }
    return null;
  }

  static IndoorPathCode? fromPrototypeText(String text) {
    final normalized = text.trim().toUpperCase();
    for (final code in values) {
      if (code.prototypeText == normalized) {
        return code;
      }
    }
    return null;
  }
}

class IndoorPathState {
  const IndoorPathState({
    required this.code,
    required this.severity,
    required this.score,
    required this.timestamp,
    required this.stateText,
    this.objectLabel,
  });

  final IndoorPathCode code;
  final IndoorPathSeverity severity;
  final double score;
  final DateTime timestamp;
  final String stateText;
  final String? objectLabel;

  factory IndoorPathState.fromMap(Map<dynamic, dynamic> map) {
    final rawStateText = map['stateText'] as String?;
    final rawCode = map['code'] as String? ?? '';
    final code =
        IndoorPathCode.fromValue(rawCode) ??
        IndoorPathCode.fromPrototypeText(rawStateText ?? '');

    final rawSeverity = map['severity'] as String? ?? 'uncertain';
    final severity = IndoorPathSeverity.values.firstWhere(
      (item) => item.name == rawSeverity,
      orElse: () => IndoorPathSeverity.uncertain,
    );
    final timestampMillis =
        (map['timestampMillis'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;

    return IndoorPathState(
      code: code ?? IndoorPathCode.lowLightUncertain,
      severity: severity,
      score: (map['score'] as num?)?.toDouble() ?? 0,
      stateText:
          rawStateText ??
          (code?.prototypeText ?? IndoorPathCode.lowLightUncertain.prototypeText),
      objectLabel: map['objectLabel'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
    );
  }
}

class IndoorNavigationBridge {
  const IndoorNavigationBridge()
    : _methodChannel = const MethodChannel(
        NativeBridgeChannels.indoorNavigation,
      ),
      _eventChannel = const EventChannel(
        NativeBridgeChannels.indoorNavigationEvents,
      );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  static const startMethod = 'indoorNav.start';
  static const stopMethod = 'indoorNav.stop';
  static const processFrameMethod = 'indoorNav.processFrame';

  Future<void> start() {
    return _methodChannel.invokeMethod<void>(startMethod);
  }

  Future<void> stop() {
    return _methodChannel.invokeMethod<void>(stopMethod);
  }

  Future<void> processFrame(IndoorCameraFrame frame) {
    return _methodChannel.invokeMethod<void>(processFrameMethod, frame.toMap());
  }

  Stream<IndoorPathState> states() {
    return _eventChannel.receiveBroadcastStream().map((event) {
      return IndoorPathState.fromMap(event as Map<dynamic, dynamic>);
    });
  }
}

class IndoorCameraFrame {
  const IndoorCameraFrame({
    required this.width,
    required this.height,
    required this.format,
    required this.planes,
    required this.timestampMillis,
  });

  final int width;
  final int height;
  final String format;
  final List<IndoorCameraPlane> planes;
  final int timestampMillis;

  Map<String, Object?> toMap() {
    return {
      'width': width,
      'height': height,
      'format': format,
      'timestampMillis': timestampMillis,
      'planes': planes.map((plane) => plane.toMap()).toList(growable: false),
    };
  }
}

class IndoorCameraPlane {
  const IndoorCameraPlane({
    required this.bytes,
    required this.bytesPerRow,
    this.bytesPerPixel,
  });

  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;

  Map<String, Object?> toMap() {
    return {
      'bytes': bytes,
      'bytesPerRow': bytesPerRow,
      'bytesPerPixel': bytesPerPixel,
    };
  }
}
