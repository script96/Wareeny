import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:wareeny/core/emergency/emergency_motion_detector.dart';

/// Detects a hard shake or a fall-and-impact using raw accelerometer data.
///
/// After firing, a [cooldownDuration] lockout is enforced.
class ShakeDetectorService {
  ShakeDetectorService({this.cooldownDuration = const Duration(seconds: 30)});

  /// How long to block re-triggering after a shake event.
  final Duration cooldownDuration;

  // ── State ───────────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _subscription;
  final StreamController<void> _shakeController =
      StreamController<void>.broadcast();
  final EmergencyMotionDetector _motionDetector = EmergencyMotionDetector();
  DateTime? _lastShakeTime;

  /// Emits an event each time a qualifying shake is detected (after cooldown).
  Stream<void> get onShake => _shakeController.stream;

  bool get isRunning => _subscription != null;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Begin listening to the accelerometer.
  void start() {
    if (_subscription != null) return;
    debugPrint('[ShakeDetector] Started.');

    _subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 10),
        ).listen(
          _onAccelerometerEvent,
          onError: (dynamic e) {
            debugPrint('[ShakeDetector] Error: $e');
          },
        );
  }

  /// Stop listening. Call this when the app is paused or the feature is no
  /// longer needed to save battery.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _motionDetector.reset();
    debugPrint('[ShakeDetector] Stopped.');
  }

  void dispose() {
    stop();
    _shakeController.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final motion = _motionDetector.addSample(
      x: event.x,
      y: event.y,
      z: event.z,
      timestamp: event.timestamp,
    );
    if (motion != null) {
      _tryFire(motion);
    }
  }

  void _tryFire(EmergencyMotionType motion) {
    final now = DateTime.now();
    if (_lastShakeTime != null &&
        now.difference(_lastShakeTime!) < cooldownDuration) {
      debugPrint('[ShakeDetector] Cooldown active — ignoring $motion.');
      return;
    }
    _lastShakeTime = now;
    debugPrint('[ShakeDetector] Detected $motion. Emitting SOS event.');
    _shakeController.add(null);
  }

  /// Manually reset the cooldown timer (e.g., after a cancelled emergency).
  /// This does NOT shorten the cooldown — it is reset from [when] onwards.
  void resetCooldown() {
    _lastShakeTime = DateTime.now();
    debugPrint('[ShakeDetector] Cooldown reset.');
  }
}
