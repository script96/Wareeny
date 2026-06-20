import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/danger/danger_alert_manager.dart';
import 'package:wareeny/shared/danger/danger_detection_result.dart';

void main() {
  test('fire alert stops normal speech and cools down repeats', () async {
    var now = DateTime(2026);
    final feedback = _FakeDangerFeedback();
    final manager = DangerAlertManager(feedback: feedback, clock: () => now);
    final fire = _detection(DangerKind.fire, label: 'Fire');

    expect(await manager.trigger(fire), isTrue);
    expect(feedback.stops, 1);
    expect(feedback.haptics, DangerKind.fire.hapticPulses);
    expect(feedback.spoken, ['خطر، في نار قريبة منك. ابعد فوراً وخلي بالك.']);

    now = now.add(const Duration(seconds: 1));
    expect(await manager.trigger(fire), isFalse);
    expect(feedback.spoken, hasLength(1));
    expect(manager.status, contains('Cooldown'));

    now = now.add(const Duration(seconds: 3));
    expect(await manager.trigger(fire), isTrue);
    expect(feedback.spoken, hasLength(2));
  });

  test('fire interrupts active stop-sign cooldown', () async {
    var now = DateTime(2026);
    final feedback = _FakeDangerFeedback();
    final manager = DangerAlertManager(feedback: feedback, clock: () => now);

    expect(await manager.trigger(_detection(DangerKind.stopSign)), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(await manager.trigger(_detection(DangerKind.fire)), isTrue);
    expect(feedback.spoken, [
      'قدامك علامة توقف. وقف وخلي بالك من الطريق حواليك.',
      'خطر، في نار قريبة منك. ابعد فوراً وخلي بالك.',
    ]);
    expect(
      feedback.haptics,
      DangerKind.stopSign.hapticPulses + DangerKind.fire.hapticPulses,
    );
  });

  test('chooses fire before exit and warning signs', () {
    final manager = DangerAlertManager(
      feedback: _FakeDangerFeedback(),
      clock: () => DateTime(2026),
    );

    final selected = manager.chooseAlert([
      _detection(DangerKind.exitSign, confidence: 0.99),
      _detection(DangerKind.wetFloorSign, confidence: 0.95),
      _detection(DangerKind.fire, confidence: 0.60),
    ]);

    expect(selected?.kind, DangerKind.fire);
  });

  test(
    'large fire enters panic until the fire clear timeout elapses',
    () async {
      var now = DateTime(2026);
      final manager = DangerAlertManager(
        feedback: _FakeDangerFeedback(),
        clock: () => now,
      );
      final largeFire = _detection(
        DangerKind.fire,
        box: const Rect.fromLTWH(0, 0, 50, 50),
      );

      await manager.handleFrame([largeFire]);
      expect(manager.panicMode, isTrue);

      now = now.add(const Duration(seconds: 8));
      await manager.handleFrame(const []);
      expect(manager.panicMode, isFalse);
    },
  );
}

DangerDetectionResult _detection(
  DangerKind kind, {
  String? label,
  double confidence = 0.9,
  Rect box = const Rect.fromLTWH(10, 10, 20, 20),
}) {
  return DangerDetectionResult(
    kind: kind,
    rawLabel: label ?? kind.debugLabel,
    mappedLabel: label ?? kind.debugLabel,
    confidence: confidence,
    boundingBox: box,
    sourceSize: const Size(100, 100),
    navigationMode: DangerNavigationMode.outdoor,
  );
}

class _FakeDangerFeedback implements DangerAlertFeedback {
  final List<String> spoken = [];
  final List<String> statusMessages = [];
  int stops = 0;
  int resumes = 0;
  int haptics = 0;

  @override
  Future<void> playDangerHaptic() async {
    haptics++;
  }

  @override
  Future<void> resumeNormalInput() async {
    resumes++;
  }

  @override
  Future<void> speakCritical(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> speakStatusOnce(String message) async {
    statusMessages.add(message);
  }

  @override
  Future<void> stopNormalSpeechAndInput() async {
    stops++;
  }
}
