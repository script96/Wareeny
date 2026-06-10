import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/yolo_output_decoder.dart';

void main() {
  const classCount = 2;
  const anchorCount = 3;
  const featureCount = classCount + 4;
  const decoder = YoloOutputDecoder(
    classCount: classCount,
    inputWidth: 640,
    inputHeight: 640,
    confidenceThreshold: 0.25,
    iouThreshold: 0.5,
  );

  test('decodes feature-first YOLO output and rejects low confidence', () {
    final output = Float32List(featureCount * anchorCount);
    _setFeatureFirst(output, anchorCount, 0, [320, 320, 100, 80, 0.1, 0.9]);
    _setFeatureFirst(output, anchorCount, 1, [100, 100, 50, 50, 0.2, 0.1]);

    final predictions = decoder.decode(output, [1, featureCount, anchorCount]);

    expect(predictions, hasLength(1));
    expect(predictions.single.classIndex, 1);
    expect(predictions.single.confidence, closeTo(0.9, 0.0001));
    expect(predictions.single.modelBox.left, closeTo(270, 0.0001));
    expect(predictions.single.modelBox.top, closeTo(280, 0.0001));
  });

  test('applies NMS only between predictions of the same class', () {
    final output = Float32List(featureCount * anchorCount);
    _setFeatureFirst(output, anchorCount, 0, [320, 320, 100, 100, 0.9, 0.1]);
    _setFeatureFirst(output, anchorCount, 1, [322, 322, 100, 100, 0.8, 0.1]);
    _setFeatureFirst(output, anchorCount, 2, [320, 320, 100, 100, 0.1, 0.85]);

    final predictions = decoder.decode(output, [1, featureCount, anchorCount]);

    expect(predictions, hasLength(2));
    expect(predictions.map((item) => item.classIndex), containsAll([0, 1]));
  });
}

void _setFeatureFirst(
  Float32List output,
  int anchorCount,
  int anchor,
  List<double> values,
) {
  for (var feature = 0; feature < values.length; feature += 1) {
    output[feature * anchorCount + anchor] = values[feature];
  }
}
