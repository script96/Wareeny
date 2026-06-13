import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'package:wareeny/shared/emergency/fall_detection_engine.dart';

class MotionMonitoringService {
  MotionMonitoringService({FallDetectionEngine? engine})
    : _engine = engine ?? FallDetectionEngine();

  final FallDetectionEngine _engine;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  double _rotationMagnitude = 0;

  bool get isRunning => _accelerometerSubscription != null;

  Future<void> start({required void Function(MotionSample) onFall}) async {
    if (isRunning) return;
    _engine.reset();

    _gyroscopeSubscription =
        gyroscopeEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen((event) {
          _rotationMagnitude = math.sqrt(
            event.x * event.x + event.y * event.y + event.z * event.z,
          );
        }, onError: (_) {});

    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.gameInterval,
        ).listen(
          (event) {
            final sample = MotionSample(
              timestamp: DateTime.now(),
              accelerationX: event.x,
              accelerationY: event.y,
              accelerationZ: event.z,
              rotationMagnitude: _rotationMagnitude,
            );
            if (_engine.add(sample)) onFall(sample);
          },
          onError: (_) => stop(),
          cancelOnError: true,
        );
  }

  Future<void> stop() async {
    await _accelerometerSubscription?.cancel();
    await _gyroscopeSubscription?.cancel();
    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _engine.reset();
  }
}
