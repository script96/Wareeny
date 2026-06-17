import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:wareeny/shared/bridges/native_bridge_channels.dart';
import 'package:wareeny/shared/object_detection/detection_models.dart';

abstract interface class ObjectDetectionSource {
  String get displayName;

  Stream<ObjectDetectionFrame> get frames;

  Future<void> start({required String mode});

  Future<void> stop();
}

abstract interface class YoloStreamingObjectDetectionSource
    implements ObjectDetectionSource {
  String modelPathForMode(String mode, {bool useCustomModel = false});

  void processStreamingData(Map<String, dynamic> data);
}

class NativeObjectDetectionSource implements ObjectDetectionSource {
  const NativeObjectDetectionSource()
    : _methodChannel = const MethodChannel(
        NativeBridgeChannels.objectDetection,
      ),
      _eventChannel = const EventChannel(
        NativeBridgeChannels.objectDetectionEvents,
      );

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  static const startMethod = 'objectDetection.start';
  static const stopMethod = 'objectDetection.stop';

  @override
  String get displayName => 'YOLO/LiteRT';

  @override
  Stream<ObjectDetectionFrame> get frames {
    return _eventChannel.receiveBroadcastStream().map((event) {
      if (event is! Map) {
        throw const FormatException('Invalid object detection frame.');
      }
      return ObjectDetectionFrame.fromMap(Map<Object?, Object?>.from(event));
    });
  }

  @override
  Future<void> start({required String mode}) {
    return _methodChannel.invokeMethod<void>(startMethod, {'mode': mode});
  }

  @override
  Future<void> stop() {
    return _methodChannel.invokeMethod<void>(stopMethod);
  }
}

class UltralyticsYoloDetectionSource
    implements YoloStreamingObjectDetectionSource {
  UltralyticsYoloDetectionSource();

  static const homeAndroidModelPath =
      'assets/models/home/home_object_detector_int8.tflite';
  static const homeIosModelPath =
      'assets/models/home/home_object_detector.mlpackage.zip';
  static const indoorNavigationAndroidModelPath =
      'assets/models/navigation/indoor/indoor_navigation_int8.tflite';
  static const indoorNavigationIosModelPath =
      'assets/models/navigation/indoor/indoor_navigation.mlpackage.zip';
  static const outdoorNavigationAndroidModelPath =
      'assets/models/navigation/outdoor/outdoor_navigation_int8.tflite';
  static const outdoorNavigationIosModelPath =
      'assets/models/navigation/outdoor/outdoor_navigation.mlpackage.zip';
  static const dangerAndroidModelPath =
      'assets/models/danger/danger_model.tflite';
  static const dangerIosModelPath =
      'assets/models/danger/danger_model.mlpackage.zip';
  static const dangerLabelsPath = 'assets/models/danger/danger_labels.txt';
  static const stuffFinderAndroidModelPath =
      'assets/models/stuff_finder/stuff_finder_int8.tflite';
  static const stuffFinderAndroidFloatModelPath =
      'assets/models/stuff_finder/stuff_finder_float32.tflite';
  static const stuffFinderIosModelPath =
      'assets/models/stuff_finder/stuff_finder.mlpackage.zip';

  final StreamController<ObjectDetectionFrame> _frames =
      StreamController<ObjectDetectionFrame>.broadcast();

  int _frameId = 0;

  @override
  String get displayName => 'YOLOv8n';

  @override
  String modelPathForMode(String mode, {bool useCustomModel = false}) {
    if (mode == 'stuff_finder' && useCustomModel) {
      return Platform.isIOS
          ? stuffFinderIosModelPath
          : stuffFinderAndroidFloatModelPath;
    }
    if (mode == 'navigation_indoor') {
      return Platform.isIOS
          ? indoorNavigationIosModelPath
          : indoorNavigationAndroidModelPath;
    }
    if (mode == 'navigation_outdoor') {
      return Platform.isIOS
          ? outdoorNavigationIosModelPath
          : outdoorNavigationAndroidModelPath;
    }
    if (mode == 'danger') {
      return Platform.isIOS ? dangerIosModelPath : dangerAndroidModelPath;
    }
    return Platform.isIOS ? homeIosModelPath : homeAndroidModelPath;
  }

  @override
  Stream<ObjectDetectionFrame> get frames => _frames.stream;

  @override
  Future<void> start({required String mode}) async {}

  @override
  void processStreamingData(Map<String, dynamic> data) {
    try {
      final width = _number(data['imageWidth']);
      final height = _number(data['imageHeight']);
      if (width <= 0 || height <= 0) return;

      final sourceSize = Size(width, height);
      final rawDetections = data['detections'];
      final detections = rawDetections is List
          ? rawDetections
                .whereType<Map>()
                .map(
                  (item) => _mapDetection(
                    Map<Object?, Object?>.from(item),
                    sourceSize,
                  ),
                )
                .whereType<ObjectDetection>()
                .toList(growable: false)
          : const <ObjectDetection>[];
      final timestampMs = _integer(
        data['timestamp'],
        fallback: DateTime.now().millisecondsSinceEpoch,
      );
      final processingTimeMs = _numberOrNull(data['processingTimeMs']);
      final nativeFrameId = data['frameNumber'];
      final parsedFrameId = nativeFrameId == null
          ? -1
          : _integer(nativeFrameId, fallback: -1);
      final frameId = parsedFrameId >= 0 ? parsedFrameId : _frameId + 1;
      if (frameId > _frameId) _frameId = frameId;

      _frames.add(
        ObjectDetectionFrame(
          frameId: frameId,
          sourceSize: sourceSize,
          detections: detections,
          timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
          inferenceTime: processingTimeMs == null
              ? null
              : Duration(microseconds: (processingTimeMs * 1000).round()),
          framesPerSecond: _numberOrNull(data['fps']),
          modelSource: data['modelSource']?.toString() ?? 'unknown',
        ),
      );
    } catch (error, stackTrace) {
      _frames.addError(error, stackTrace);
    }
  }

  @override
  Future<void> stop() async {}

  ObjectDetection? _mapDetection(Map<Object?, Object?> data, Size sourceSize) {
    final boxData = data['normalizedBox'];
    if (boxData is! Map) return null;
    final box = Map<Object?, Object?>.from(boxData);
    final left = _number(box['left']).clamp(0, 1).toDouble();
    final top = _number(box['top']).clamp(0, 1).toDouble();
    final right = _number(box['right']).clamp(0, 1).toDouble();
    final bottom = _number(box['bottom']).clamp(0, 1).toDouble();
    if (right <= left || bottom <= top) return null;

    final label = data['className']?.toString().trim();
    return ObjectDetection(
      label: label?.isNotEmpty == true ? label! : 'unknown',
      confidence: _number(data['confidence']).clamp(0, 1),
      boundingBox: Rect.fromLTRB(
        left * sourceSize.width,
        top * sourceSize.height,
        right * sourceSize.width,
        bottom * sourceSize.height,
      ),
      trackingId: data['trackingId']?.toString(),
    );
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double? _numberOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int _integer(Object? value, {required int fallback}) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
