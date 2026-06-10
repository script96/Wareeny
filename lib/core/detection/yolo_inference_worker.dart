import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'package:wareny/core/detection/camera_image_preprocessor.dart';
import 'package:wareny/core/detection/yolo_output_decoder.dart';

class YoloInferenceOutput {
  const YoloInferenceOutput({
    required this.predictions,
    required this.transform,
  });

  final List<YoloPrediction> predictions;
  final YoloImageTransform transform;
}

class YoloInferenceWorker {
  final ReceivePort _receivePort = ReceivePort();
  Isolate? _isolate;
  SendPort? _sendPort;

  Future<void> start({
    required int interpreterAddress,
    required int inputWidth,
    required int inputHeight,
    required List<int> outputShape,
    required int classCount,
  }) async {
    if (_isolate != null) {
      return;
    }

    final ready = Completer<SendPort>();
    late final StreamSubscription<Object?> subscription;
    subscription = _receivePort.listen((message) {
      if (message is SendPort && !ready.isCompleted) {
        ready.complete(message);
      }
    });
    _isolate = await Isolate.spawn(
      _entryPoint,
      _YoloWorkerSetup(
        hostPort: _receivePort.sendPort,
        interpreterAddress: interpreterAddress,
        inputWidth: inputWidth,
        inputHeight: inputHeight,
        outputShape: outputShape,
        classCount: classCount,
      ),
      debugName: 'WareenyYoloInference',
    );
    _sendPort = await ready.future;
    await subscription.cancel();
  }

  Future<YoloInferenceOutput> run(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    final sendPort = _sendPort;
    if (sendPort == null) {
      throw StateError('YOLO inference worker has not started.');
    }

    final responsePort = ReceivePort();
    sendPort.send(
      _YoloWorkerRequest(
        image: image,
        rotationDegrees: rotationDegrees,
        responsePort: responsePort.sendPort,
      ),
    );
    final response = await responsePort.first;
    responsePort.close();
    if (response is YoloInferenceOutput) {
      return response;
    }
    if (response is _YoloWorkerError) {
      Error.throwWithStackTrace(
        StateError(response.message),
        StackTrace.fromString(response.stackTrace),
      );
    }
    throw StateError('YOLO inference worker returned an invalid response.');
  }

  Future<void> close() async {
    _sendPort?.send(null);
    _sendPort = null;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _receivePort.close();
  }

  static Future<void> _entryPoint(_YoloWorkerSetup setup) async {
    final requestPort = ReceivePort();
    setup.hostPort.send(requestPort.sendPort);
    final interpreter = Interpreter.fromAddress(
      setup.interpreterAddress,
      allocated: true,
    );
    final preprocessor = const CameraImagePreprocessor();
    final decoder = YoloOutputDecoder(
      classCount: setup.classCount,
      inputWidth: setup.inputWidth,
      inputHeight: setup.inputHeight,
    );
    final input = Float32List(setup.inputWidth * setup.inputHeight * 3);

    await for (final request in requestPort) {
      if (request == null) {
        requestPort.close();
        return;
      }
      if (request is! _YoloWorkerRequest) {
        continue;
      }

      try {
        final transform = preprocessor.fillInput(
          image: request.image,
          rotationDegrees: request.rotationDegrees,
          inputWidth: setup.inputWidth,
          inputHeight: setup.inputHeight,
          input: input,
        );
        interpreter.getInputTensor(0).data = input.buffer.asUint8List();
        interpreter.invoke();
        final outputBytes = interpreter.getOutputTensor(0).data;
        final output = Float32List.view(
          outputBytes.buffer,
          outputBytes.offsetInBytes,
          outputBytes.lengthInBytes ~/ Float32List.bytesPerElement,
        );
        request.responsePort.send(
          YoloInferenceOutput(
            predictions: decoder.decode(output, setup.outputShape),
            transform: transform,
          ),
        );
      } catch (error, stackTrace) {
        request.responsePort.send(
          _YoloWorkerError(error.toString(), stackTrace.toString()),
        );
      }
    }
  }
}

class _YoloWorkerSetup {
  const _YoloWorkerSetup({
    required this.hostPort,
    required this.interpreterAddress,
    required this.inputWidth,
    required this.inputHeight,
    required this.outputShape,
    required this.classCount,
  });

  final SendPort hostPort;
  final int interpreterAddress;
  final int inputWidth;
  final int inputHeight;
  final List<int> outputShape;
  final int classCount;
}

class _YoloWorkerRequest {
  const _YoloWorkerRequest({
    required this.image,
    required this.rotationDegrees,
    required this.responsePort,
  });

  final CameraImage image;
  final int rotationDegrees;
  final SendPort responsePort;
}

class _YoloWorkerError {
  const _YoloWorkerError(this.message, this.stackTrace);

  final String message;
  final String stackTrace;
}
