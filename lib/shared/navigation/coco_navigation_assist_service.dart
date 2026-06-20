import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'package:wareeny/shared/object_detection/detection_models.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

typedef CocoNavigationFrameCallback = void Function(ObjectDetectionFrame frame);

abstract interface class CocoNavigationInferenceEngine {
  Future<void> load();

  Future<ObjectDetectionFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
    required DateTime timestamp,
  });

  Future<void> dispose();
}

class YoloCocoNavigationInferenceEngine
    implements CocoNavigationInferenceEngine {
  YoloCocoNavigationInferenceEngine({
    String? modelPath,
    this.confidenceThreshold = 0.35,
    this.iouThreshold = 0.45,
    this.diagnosticsEnabled = false,
  }) : modelPath =
           modelPath ??
           (Platform.isIOS
               ? UltralyticsYoloDetectionSource.outdoorNavigationIosModelPath
               : UltralyticsYoloDetectionSource
                     .outdoorNavigationAndroidModelPath);

  final String modelPath;
  final double confidenceThreshold;
  final double iouThreshold;
  final bool diagnosticsEnabled;

  YOLO? _yolo;
  bool _loaded = false;

  @override
  Future<void> load() async {
    if (_loaded) return;
    final resolvedModelPath = await _prepareBundledModelFile(modelPath);
    final yolo = YOLO(
      modelPath: resolvedModelPath,
      task: YOLOTask.detect,
      useGpu: false,
      useMultiInstance: true,
    );
    _yolo = yolo;
    final loaded = await yolo.loadModel();
    if (!loaded) {
      throw StateError(
        'Indoor COCO assist model failed to load: $resolvedModelPath',
      );
    }
    _loaded = true;
    _log('indoor COCO assist model loaded');
  }

  Future<String> _prepareBundledModelFile(String assetPath) async {
    if (!assetPath.startsWith('assets/')) return assetPath;
    if (assetPath.endsWith('.mlpackage.zip')) {
      return assetPath;
    }

    final assetData = await rootBundle.load(assetPath);
    final bytes = assetData.buffer.asUint8List(
      assetData.offsetInBytes,
      assetData.lengthInBytes,
    );
    if (bytes.isEmpty) {
      throw StateError('Indoor COCO assist asset is empty: $assetPath');
    }

    final safeName = assetPath.split('/').last;
    final directory = Directory('${Directory.systemTemp.path}/wareeny_models');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final file = File('${directory.path}/$safeName');
    if (!file.existsSync() || file.lengthSync() != bytes.length) {
      file.writeAsBytesSync(bytes, flush: true);
    }
    return file.path;
  }

  @override
  Future<ObjectDetectionFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
    required DateTime timestamp,
  }) async {
    final yolo = _yolo;
    if (!_loaded || yolo == null) {
      throw StateError('Indoor COCO assist model is not loaded.');
    }

    final stopwatch = Stopwatch()..start();
    final result = await yolo.predict(
      imageBytes,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: iouThreshold,
    );
    stopwatch.stop();

    final sourceSize = _sourceSizeFromResult(result);
    final detections = _parseDetections(result, sourceSize)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return ObjectDetectionFrame(
      frameId: frameId,
      sourceSize: sourceSize,
      detections: detections,
      timestamp: timestamp,
      inferenceTime: stopwatch.elapsed,
      modelSource: 'coco',
    );
  }

  Size _sourceSizeFromResult(Map<String, dynamic> result) {
    final imageSize = result['imageSize'];
    if (imageSize is Map) {
      final width = _number(imageSize['width']);
      final height = _number(imageSize['height']);
      if (width > 0 && height > 0) return Size(width, height);
    }
    return const Size(1, 1);
  }

  List<ObjectDetection> _parseDetections(
    Map<String, dynamic> result,
    Size sourceSize,
  ) {
    final rawDetections = result['detections'];
    if (rawDetections is! List) return const <ObjectDetection>[];
    final parsed = <ObjectDetection>[];
    for (final item in rawDetections.whereType<Map>()) {
      final detection = _detectionFromMap(
        Map<Object?, Object?>.from(item),
        sourceSize,
      );
      if (detection != null) parsed.add(detection);
    }
    return parsed;
  }

  ObjectDetection? _detectionFromMap(
    Map<Object?, Object?> data,
    Size sourceSize,
  ) {
    final label = data['className']?.toString().trim();
    final confidence = _number(data['confidence']).clamp(0, 1).toDouble();
    final boxData = data['boundingBox'];
    final normalizedBoxData = data['normalizedBox'];

    Rect? box;
    if (boxData is Map) {
      final raw = Map<Object?, Object?>.from(boxData);
      box = Rect.fromLTRB(
        _number(raw['left']),
        _number(raw['top']),
        _number(raw['right']),
        _number(raw['bottom']),
      );
    } else if (normalizedBoxData is Map) {
      final raw = Map<Object?, Object?>.from(normalizedBoxData);
      box = Rect.fromLTRB(
        _number(raw['left']) * sourceSize.width,
        _number(raw['top']) * sourceSize.height,
        _number(raw['right']) * sourceSize.width,
        _number(raw['bottom']) * sourceSize.height,
      );
    }
    if (box == null || box.width <= 0 || box.height <= 0) return null;

    return ObjectDetection(
      label: label?.isNotEmpty == true ? label! : 'unknown',
      confidence: confidence,
      boundingBox: box,
      trackingId: data['trackingId']?.toString(),
    );
  }

  @override
  Future<void> dispose() async {
    await _yolo?.dispose();
    _yolo = null;
    _loaded = false;
    _log('indoor COCO assist model disposed');
  }

  void _log(String message) {
    if (diagnosticsEnabled) {
      debugPrint('[IndoorCocoAssist] $message');
    }
  }
}

class CocoNavigationAssistService {
  CocoNavigationAssistService({
    required this._onFrame,
    CocoNavigationInferenceEngine? inferenceEngine,
    this.diagnosticsEnabled = false,
  }) : _engine =
           inferenceEngine ??
           YoloCocoNavigationInferenceEngine(
             diagnosticsEnabled: diagnosticsEnabled,
           );

  final CocoNavigationFrameCallback _onFrame;
  final CocoNavigationInferenceEngine _engine;
  final bool diagnosticsEnabled;

  bool _started = false;
  bool _loading = false;
  bool _ready = false;
  bool _inferenceInFlight = false;
  int _nextFrameId = 1;

  Future<void> start() async {
    if (_started || _loading) return;
    _started = true;
    _loading = true;
    try {
      await _engine.load();
      _ready = true;
    } finally {
      _loading = false;
    }
  }

  Future<void> stop() async {
    _started = false;
    _ready = false;
    _inferenceInFlight = false;
    await _engine.dispose();
  }

  Future<void> analyzeFrame(
    Uint8List imageBytes, {
    required DateTime timestamp,
  }) async {
    if (!_started || !_ready || _inferenceInFlight || imageBytes.isEmpty) {
      return;
    }

    _inferenceInFlight = true;
    try {
      final frame = await _engine.predict(
        imageBytes,
        frameId: _nextFrameId++,
        timestamp: timestamp,
      );
      _onFrame(frame);
    } catch (error) {
      _log('COCO assist inference failed: $error');
    } finally {
      _inferenceInFlight = false;
    }
  }

  void _log(String message) {
    if (diagnosticsEnabled) {
      debugPrint('[IndoorCocoAssist] $message');
    }
  }
}

double _number(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
