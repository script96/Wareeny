import 'dart:ui';

class ObjectDetection {
  const ObjectDetection({
    required this.label,
    required this.confidence,
    required this.boundingBox,
    this.trackingId,
  });

  final String label;
  final double confidence;

  /// Bounding box in source-frame pixels.
  final Rect boundingBox;
  final String? trackingId;

  factory ObjectDetection.fromMap(Map<Object?, Object?> map) {
    final box = map['box'];
    if (box is! Map) {
      throw const FormatException('Detection is missing a box map.');
    }

    final left = _number(box['left']);
    final top = _number(box['top']);
    final right = box.containsKey('right')
        ? _number(box['right'])
        : left + _number(box['width']);
    final bottom = box.containsKey('bottom')
        ? _number(box['bottom'])
        : top + _number(box['height']);

    return ObjectDetection(
      label: map['label']?.toString() ?? 'unknown',
      confidence: _number(map['confidence']),
      boundingBox: Rect.fromLTRB(left, top, right, bottom),
      trackingId: map['trackingId']?.toString(),
    );
  }
}

class ObjectDetectionFrame {
  const ObjectDetectionFrame({
    required this.frameId,
    required this.sourceSize,
    required this.detections,
    required this.timestamp,
    this.rotationDegrees = 0,
    this.mirrored = false,
    this.inferenceTime,
    this.framesPerSecond,
    this.isLowLight = false,
    this.modelSource = 'unknown',
  });

  final int frameId;
  final Size sourceSize;
  final List<ObjectDetection> detections;
  final DateTime timestamp;

  /// Clockwise rotation needed to match the displayed camera preview.
  final int rotationDegrees;
  final bool mirrored;
  final Duration? inferenceTime;
  final double? framesPerSecond;
  final bool isLowLight;
  final String modelSource;

  factory ObjectDetectionFrame.fromMap(Map<Object?, Object?> map) {
    final sourceSize = Size(
      _number(map['imageWidth']),
      _number(map['imageHeight']),
    );
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      throw const FormatException(
        'Detection frame image dimensions must be positive.',
      );
    }

    final rawDetections = map['detections'];
    final detections = rawDetections is List
        ? rawDetections
              .whereType<Map>()
              .map(
                (item) =>
                    ObjectDetection.fromMap(Map<Object?, Object?>.from(item)),
              )
              .toList(growable: false)
        : const <ObjectDetection>[];

    return ObjectDetectionFrame(
      frameId: _integer(map['frameId']),
      sourceSize: sourceSize,
      detections: detections,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        _integer(
          map['timestampMs'],
          fallback: DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      rotationDegrees: _integer(map['rotationDegrees']),
      mirrored: map['mirrored'] == true,
      inferenceTime: map['inferenceTimeMs'] == null
          ? null
          : Duration(milliseconds: _integer(map['inferenceTimeMs'])),
      framesPerSecond: map['fps'] == null ? null : _number(map['fps']),
      isLowLight: map['isLowLight'] == true,
      modelSource: map['modelSource']?.toString() ?? 'unknown',
    );
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _integer(Object? value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
