import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects a device shake using the accelerometer stream.
///
/// A "shake" is fired when the combined acceleration magnitude exceeds
/// [_thresholdMs2] for [_requiredSamples] consecutive samples.
/// After firing, a [cooldownDuration] lockout is enforced.
class ShakeDetectorService {
  ShakeDetectorService({
    this.cooldownDuration = const Duration(seconds: 30),
  });

  /// How long to block re-triggering after a shake event.
  final Duration cooldownDuration;

  // ── Constants ───────────────────────────────────────────────────────────────
  // 15 m/s² is roughly a firm wrist shake; typical resting device is ~9.8 m/s²
  static const double _thresholdMs2 = 15.0;

  // A single shake usually shows up across 2–3 consecutive samples.
  static const int _requiredSamples = 2;

  // ── State ───────────────────────────────────────────────────────────────────
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final StreamController<void> _shakeController =
      StreamController<void>.broadcast();
  int _consecutiveSamples = 0;
  DateTime? _lastShakeTime;

  /// Emits an event each time a qualifying shake is detected (after cooldown).
  Stream<void> get onShake => _shakeController.stream;

  bool get isRunning => _subscription != null;

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Begin listening to the accelerometer.
  void start() {
    if (_subscription != null) return;
    debugPrint('[ShakeDetector] Started.');

    _subscription = userAccelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50),
    ).listen(_onAccelerometerEvent, onError: (dynamic e) {
      debugPrint('[ShakeDetector] Error: $e');
    });
  }

  /// Stop listening. Call this when the app is paused or the feature is no
  /// longer needed to save battery.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _consecutiveSamples = 0;
    debugPrint('[ShakeDetector] Stopped.');
  }

  void dispose() {
    stop();
    _shakeController.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _onAccelerometerEvent(UserAccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude >= _thresholdMs2) {
      _consecutiveSamples++;
      if (_consecutiveSamples >= _requiredSamples) {
        _consecutiveSamples = 0;
        _tryFire();
      }
    } else {
      _consecutiveSamples = 0;
    }
  }

  void _tryFire() {
    final now = DateTime.now();
    if (_lastShakeTime != null &&
        now.difference(_lastShakeTime!) < cooldownDuration) {
      debugPrint('[ShakeDetector] Cooldown active — ignoring shake.');
      return;
    }
    _lastShakeTime = now;
    debugPrint('[ShakeDetector] Shake detected! Emitting event.');
    _shakeController.add(null);
  }

  /// Manually reset the cooldown timer (e.g., after a cancelled emergency).
  /// This does NOT shorten the cooldown — it is reset from [when] onwards.
  void resetCooldown() {
    _lastShakeTime = DateTime.now();
    debugPrint('[ShakeDetector] Cooldown reset.');
  }
}
