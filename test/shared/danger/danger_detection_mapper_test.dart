import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/danger/danger_detection_result.dart';
import 'package:wareeny/shared/danger/danger_label_mapper.dart';

void main() {
  const labels = [
    'Fire',
    'Smoke',
    'Stop',
    'Emergency exit indicator light',
    'wet_floor_sign',
  ];

  test('maps danger model labels to canonical warning classes', () {
    const mapper = DangerLabelMapper();

    expect(mapper.classify('Fire', labels: labels), DangerKind.fire);
    expect(mapper.classify('Smoke', labels: labels), isNull);
    expect(mapper.classify('flame', labels: labels), DangerKind.fire);
    expect(mapper.classify('Stop', labels: labels), DangerKind.stopSign);
    expect(
      mapper.classify('Emergency exit indicator light', labels: labels),
      DangerKind.exitSign,
    );
    expect(
      mapper.classify('wet_floor_sign', labels: labels),
      DangerKind.wetFloorSign,
    );
    expect(
      mapper.classify('slippery floor sign', labels: labels),
      DangerKind.wetFloorSign,
    );
  });

  test('maps unlabeled TFLite class indices using bundled label order', () {
    const mapper = DangerLabelMapper();

    expect(mapper.classify('class 0', labels: labels), DangerKind.fire);
    expect(mapper.classify('class 1', labels: labels), isNull);
    expect(mapper.classify('class 2', labels: labels), DangerKind.stopSign);
    expect(mapper.classify('class 3', labels: labels), DangerKind.exitSign);
    expect(mapper.classify('class 4', labels: labels), DangerKind.wetFloorSign);
  });

  test('unknown labels do not become generic danger alerts', () {
    const mapper = DangerLabelMapper();

    expect(mapper.classify('chair', labels: labels), isNull);
  });
}
