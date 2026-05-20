import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:warene/detector.dart';
import 'package:warene/services/depth_provider.dart';
import 'package:warene/services/indoor_navigation_logic.dart';
import 'package:warene/services/indoor_navigation_types.dart';

void main() {
  DepthFrame frameFromGrid(List<List<double>> grid) {
    final height = grid.length;
    final width = grid.first.length;
    final values = Float32List(width * height);
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        values[(y * width) + x] = grid[y][x];
      }
    }
    return DepthFrame(
      width: width,
      height: height,
      values: values,
      source: DepthSource.monocular,
    );
  }

  test('ignores object outside the safe corridor', () {
    final depth = frameFromGrid(List.generate(18, (_) => List.filled(18, 0.2)));
    final detections = [
      Detection(
        label: 'chair',
        arabicLabel: 'كرسي',
        confidence: 0.9,
        bbox: [0, 500, 80, 900],
      ),
    ];

    final decision = IndoorNavigationLogic.evaluate(
      detections: detections,
      imageWidth: 1000,
      imageHeight: 1000,
      depthFrame: depth,
    );

    expect(decision.dangerLevel, DangerLevel.safe);
    expect(decision.highlightedDetections, isEmpty);
  });

  test('left-side corridor obstacle cues moving right', () {
    final depth = frameFromGrid(
      List.generate(18, (_) => List.filled(18, 0.25)),
    );
    final detections = [
      Detection(
        label: 'chair',
        arabicLabel: 'كرسي',
        confidence: 0.93,
        bbox: [180, 420, 470, 980],
      ),
    ];

    final decision = IndoorNavigationLogic.evaluate(
      detections: detections,
      imageWidth: 1000,
      imageHeight: 1000,
      depthFrame: depth,
    );

    expect(decision.cue, NavigationCue.moveRight);
    expect(decision.spokenText, 'اتجه يمين');
  });

  test('center wall-like depth escalates to stop', () {
    final grid = List.generate(
      18,
      (y) => List.generate(18, (x) {
        if (y < 6) return 0.2;
        if (x >= 4 && x <= 13) return 0.9;
        return 0.78;
      }),
    );
    final depth = frameFromGrid(grid);

    final decision = IndoorNavigationLogic.evaluate(
      detections: const [],
      imageWidth: 1000,
      imageHeight: 1000,
      depthFrame: depth,
    );

    expect(decision.wallLikely, true);
    expect(decision.dangerLevel, DangerLevel.stop);
    expect(decision.spokenText, 'قف حالاً');
  });

  test('clear path keeps calm guidance', () {
    final depth = frameFromGrid(
      List.generate(18, (y) {
        final near = y > 12 ? 0.45 : 0.15;
        return List.filled(18, near);
      }),
    );

    final decision = IndoorNavigationLogic.evaluate(
      detections: const [],
      imageWidth: 1000,
      imageHeight: 1000,
      depthFrame: depth,
    );

    expect(decision.dangerLevel, DangerLevel.safe);
    expect(decision.cue, NavigationCue.keepGoing);
    expect(decision.spokenText, 'كمل');
  });
}
