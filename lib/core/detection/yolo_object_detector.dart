import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';
import 'package:wareny/core/detection/yolo_inference_worker.dart';

class YoloObjectDetector implements ObjectDetector {
  YoloObjectDetector({
    this.modelAsset = 'assets/models/stuff_finder/yolov8n_coco_float16.tflite',
    this.labelsAsset = 'assets/models/stuff_finder/coco_labels.txt',
  });

  final String modelAsset;
  final String labelsAsset;
  final YoloInferenceWorker _worker = YoloInferenceWorker();

  Interpreter? _interpreter;
  late List<String> _labels;
  var _frameIndex = 0;

  @override
  bool get isReady => _interpreter != null;

  @override
  Future<void> initialize() async {
    if (isReady) {
      return;
    }

    _labels = (await rootBundle.loadString(labelsAsset))
        .split(RegExp(r'\r?\n'))
        .map((label) => label.trim())
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    final options = InterpreterOptions()..threads = 4;
    late final Interpreter interpreter;
    try {
      interpreter = await Interpreter.fromAsset(modelAsset, options: options);
    } finally {
      options.delete();
    }

    try {
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;
      if (inputShape.length != 4 || inputShape[0] != 1 || inputShape[3] != 3) {
        throw StateError('Expected a YOLO input tensor shaped [1, H, W, 3].');
      }
      interpreter.allocateTensors();
      await _worker.start(
        interpreterAddress: interpreter.address,
        inputWidth: inputShape[2],
        inputHeight: inputShape[1],
        outputShape: outputShape,
        classCount: _labels.length,
      );
      _interpreter = interpreter;
    } catch (_) {
      interpreter.close();
      rethrow;
    }
  }

  @override
  Future<DetectionFrame> detect(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('YoloObjectDetector must be initialized before detect.');
    }

    final stopwatch = Stopwatch()..start();
    final inference = await _worker.run(
      image,
      rotationDegrees: rotationDegrees,
    );
    final timestampMs = DateTime.now().millisecondsSinceEpoch;
    final frameSize = Size(
      inference.transform.imageWidth.toDouble(),
      inference.transform.imageHeight.toDouble(),
    );
    final detections = inference.predictions.map((prediction) {
      return DetectionResult.fromNormalizedBox(
        label: _labels[prediction.classIndex],
        confidence: prediction.confidence,
        boundingBox: inference.transform.normalizedImageBox(
          prediction.modelBox,
        ),
        timestampMs: timestampMs,
        frameSize: frameSize,
      );
    });

    stopwatch.stop();
    _frameIndex += 1;
    return DetectionFrame(
      detections: detections,
      latencyMs: stopwatch.elapsedMilliseconds,
      frameIndex: _frameIndex,
    );
  }

  @override
  Future<void> dispose() async {
    await _worker.close();
    _interpreter?.close();
    _interpreter = null;
  }
}
