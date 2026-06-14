import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/camera/light_condition_service.dart';

void main() {
  test('reads average brightness and dark ratio from a Y plane', () {
    final service = LightConditionService(
      config: const LightConditionConfig(sampleStride: 1, pathWeight: 1),
    );

    final stats = service.analyzeYPlane(
      bytes: Uint8List.fromList([10, 20, 100, 110]),
      width: 2,
      height: 2,
      bytesPerRow: 2,
    );

    expect(stats.averageBrightness, 60);
    expect(stats.darkPixelRatio, 0.5);
  });

  test('very dark scene requests flash after five continuous seconds', () {
    final service = LightConditionService();
    final start = DateTime(2026);
    const dark = LightFrameStats(
      averageBrightness: 20,
      darkPixelRatio: 0.95,
      sampleCount: 100,
    );

    service.addSample(dark, timestamp: start);
    service.addSample(dark, timestamp: start.add(const Duration(seconds: 2)));
    final before = service.addSample(
      dark,
      timestamp: start.add(const Duration(seconds: 4)),
    );
    final trigger = service.addSample(
      dark,
      timestamp: start.add(const Duration(seconds: 5)),
    );

    expect(before.flashRequested, isFalse);
    expect(trigger.flashRequested, isTrue);
    expect(trigger.shouldSpeak, isTrue);
  });

  test('low light requests flash after ten continuous seconds', () {
    final service = LightConditionService();
    final start = DateTime(2026);
    const low = LightFrameStats(
      averageBrightness: 45,
      darkPixelRatio: 0.75,
      sampleCount: 100,
    );

    service.addSample(low, timestamp: start);
    service.addSample(low, timestamp: start.add(const Duration(seconds: 5)));
    final trigger = service.addSample(
      low,
      timestamp: start.add(const Duration(seconds: 10)),
    );

    expect(trigger.condition, LightCondition.lowLight);
    expect(trigger.flashRequested, isTrue);
  });

  test('brief normal sample does not reset a dark episode', () {
    final service = LightConditionService(
      config: const LightConditionConfig(smoothingWindow: 1),
    );
    final start = DateTime(2026);
    const low = LightFrameStats(
      averageBrightness: 45,
      darkPixelRatio: 0.75,
      sampleCount: 100,
    );
    const normal = LightFrameStats(
      averageBrightness: 120,
      darkPixelRatio: 0.1,
      sampleCount: 100,
    );

    service.addSample(low, timestamp: start);
    service.addSample(low, timestamp: start.add(const Duration(seconds: 4)));
    service.addSample(normal, timestamp: start.add(const Duration(seconds: 5)));
    service.addSample(low, timestamp: start.add(const Duration(seconds: 6)));
    final trigger = service.addSample(
      low,
      timestamp: start.add(const Duration(seconds: 10)),
    );

    expect(trigger.flashRequested, isTrue);
  });

  test('unstable darkness still triggers by the fifteen-second hard limit', () {
    final service = LightConditionService(
      config: const LightConditionConfig(
        smoothingWindow: 1,
        lowLightDelay: Duration(seconds: 30),
      ),
    );
    final start = DateTime(2026);
    const low = LightFrameStats(
      averageBrightness: 45,
      darkPixelRatio: 0.75,
      sampleCount: 100,
    );
    const normal = LightFrameStats(
      averageBrightness: 120,
      darkPixelRatio: 0.1,
      sampleCount: 100,
    );

    service.addSample(low, timestamp: start);
    service.addSample(low, timestamp: start.add(const Duration(seconds: 6)));
    service.addSample(normal, timestamp: start.add(const Duration(seconds: 8)));
    service.addSample(low, timestamp: start.add(const Duration(seconds: 9)));
    final trigger = service.addSample(
      low,
      timestamp: start.add(const Duration(seconds: 15)),
    );

    expect(trigger.flashRequested, isTrue);
  });

  test('stable normal light resets the episode and warning is cooled down', () {
    final service = LightConditionService(
      config: const LightConditionConfig(smoothingWindow: 1),
    );
    final start = DateTime(2026);
    const dark = LightFrameStats(
      averageBrightness: 20,
      darkPixelRatio: 0.95,
      sampleCount: 100,
    );
    const normal = LightFrameStats(
      averageBrightness: 120,
      darkPixelRatio: 0.1,
      sampleCount: 100,
    );

    service.addSample(dark, timestamp: start);
    service.addSample(dark, timestamp: start.add(const Duration(seconds: 2)));
    service.addSample(dark, timestamp: start.add(const Duration(seconds: 5)));
    service.addSample(normal, timestamp: start.add(const Duration(seconds: 6)));
    final recovered = service.addSample(
      normal,
      timestamp: start.add(const Duration(seconds: 9)),
    );
    service.addSample(dark, timestamp: start.add(const Duration(seconds: 10)));
    service.addSample(dark, timestamp: start.add(const Duration(seconds: 12)));
    final secondTrigger = service.addSample(
      dark,
      timestamp: start.add(const Duration(seconds: 15)),
    );

    expect(recovered.recovered, isTrue);
    expect(secondTrigger.flashRequested, isTrue);
    expect(secondTrigger.shouldSpeak, isFalse);
  });
}
