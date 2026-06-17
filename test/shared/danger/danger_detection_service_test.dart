import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/danger/danger_alert_manager.dart';
import 'package:wareeny/shared/danger/danger_detection_result.dart';
import 'package:wareeny/shared/danger/danger_model_service.dart';

void main() {
  test('runs danger inference only after service starts', () async {
    final engine = _FakeDangerEngine(label: 'Fire');
    final feedback = _FakeDangerFeedback();
    final service = _service(engine, feedback);

    await service.runOnce();
    expect(engine.predictCalls, 0);

    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => DangerNavigationMode.indoor,
      exitSearchActive: () => false,
    );
    await _flushAsync();

    expect(engine.loaded, isTrue);
    expect(engine.predictCalls, 1);
    expect(feedback.spoken, ['خطر، في نار قريبة منك. ابعد فوراً وخلي بالك.']);

    service.dispose();
  });

  test('drops danger ticks while inference is already in flight', () async {
    final engine = _BlockingDangerEngine(label: 'Fire');
    final feedback = _FakeDangerFeedback();
    final service = _service(engine, feedback);

    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => DangerNavigationMode.indoor,
      exitSearchActive: () => false,
    );
    await engine.started.future;

    await service.runOnce();
    expect(service.droppedTicks, 1);

    engine.complete();
    await _flushAsync();

    service.dispose();
  });

  test('stop sign is ignored indoor and alerts outdoor', () async {
    var mode = DangerNavigationMode.indoor;
    final engine = _FakeDangerEngine(label: 'Stop');
    final feedback = _FakeDangerFeedback();
    final service = _service(engine, feedback);

    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => mode,
      exitSearchActive: () => false,
    );
    await _flushAsync();

    expect(feedback.spoken, isEmpty);
    expect(service.latestDetections.single.ignoredReason, contains('Outdoor'));

    mode = DangerNavigationMode.outdoor;
    await service.runOnce();
    await _flushAsync();

    expect(feedback.spoken, [
      'قدامك علامة توقف. وقف وخلي بالك من الطريق حواليك.',
    ]);
    service.dispose();
  });

  test('exit sign speaks only while indoor find-exit is active', () async {
    var findExit = false;
    final engine = _FakeDangerEngine(label: 'Emergency exit indicator light');
    final feedback = _FakeDangerFeedback();
    final service = _service(engine, feedback);

    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => DangerNavigationMode.indoor,
      exitSearchActive: () => findExit,
    );
    await _flushAsync();

    expect(feedback.spoken, isEmpty);
    expect(service.latestDetections.single.ignoredReason, contains('inactive'));

    findExit = true;
    await service.runOnce();
    await _flushAsync();

    expect(feedback.spoken, ['علامة الخروج قريبة منك.']);
    service.dispose();
  });

  test('model load failure is spoken only once', () async {
    final engine = _FailingDangerEngine();
    final feedback = _FakeDangerFeedback();
    final service = _service(engine, feedback);

    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => DangerNavigationMode.indoor,
      exitSearchActive: () => false,
    );
    await service.start(
      captureFrame: () async => Uint8List.fromList([1, 2, 3]),
      navigationMode: () => DangerNavigationMode.indoor,
      exitSearchActive: () => false,
    );

    expect(feedback.statusMessages, hasLength(1));
    service.dispose();
  });
}

DangerModelService _service(
  DangerInferenceEngine engine,
  _FakeDangerFeedback feedback,
) {
  return DangerModelService(
    alertManager: DangerAlertManager(
      feedback: feedback,
      clock: () => DateTime(2026),
    ),
    inferenceEngine: engine,
    inferenceInterval: const Duration(days: 1),
  );
}

Future<void> _flushAsync() {
  return Future<void>.delayed(Duration.zero);
}

class _FakeDangerEngine implements DangerInferenceEngine {
  _FakeDangerEngine({required this.label});

  final String label;
  bool loaded = false;
  int predictCalls = 0;

  @override
  Future<void> load() async {
    loaded = true;
  }

  @override
  Future<DangerModelFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
  }) async {
    predictCalls++;
    return DangerModelFrame(
      frameId: frameId,
      sourceSize: const Size(100, 100),
      detections: [
        DangerRawDetection(
          label: label,
          confidence: 0.9,
          boundingBox: const Rect.fromLTWH(10, 10, 20, 20),
        ),
      ],
      timestamp: DateTime(2026),
      inferenceTime: const Duration(milliseconds: 20),
    );
  }

  @override
  Future<void> dispose() async {}
}

class _BlockingDangerEngine extends _FakeDangerEngine {
  _BlockingDangerEngine({required super.label});

  final Completer<void> started = Completer<void>();
  final Completer<void> _release = Completer<void>();

  @override
  Future<DangerModelFrame> predict(
    Uint8List imageBytes, {
    required int frameId,
  }) async {
    predictCalls++;
    if (!started.isCompleted) started.complete();
    await _release.future;
    return super.predict(imageBytes, frameId: frameId);
  }

  void complete() {
    if (!_release.isCompleted) _release.complete();
  }
}

class _FailingDangerEngine extends _FakeDangerEngine {
  _FailingDangerEngine() : super(label: 'Fire');

  @override
  Future<void> load() async {
    throw StateError('boom');
  }
}

class _FakeDangerFeedback implements DangerAlertFeedback {
  final List<String> spoken = [];
  final List<String> statusMessages = [];

  @override
  Future<void> playDangerHaptic() async {}

  @override
  Future<void> resumeNormalInput() async {}

  @override
  Future<void> speakCritical(String message) async {
    spoken.add(message);
  }

  @override
  Future<void> speakStatusOnce(String message) async {
    statusMessages.add(message);
  }

  @override
  Future<void> stopNormalSpeechAndInput() async {}
}
