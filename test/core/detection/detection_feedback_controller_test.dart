import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wareny/core/detection/detection_config.dart';
import 'package:wareny/core/detection/detection_feedback_controller.dart';
import 'package:wareny/core/detection/detection_frame.dart';
import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/object_detector.dart';
import 'package:wareny/core/tts/tts_service.dart';
import 'package:wareny/shared/bridges/audio_haptics_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('speaks only the selected menu object name', () async {
    final detector = _SingleFrameDetector(
      DetectionFrame(
        detections: [
          DetectionResult.fromNormalizedBox(
            label: 'cell phone',
            confidence: 0.91,
            boundingBox: const Rect.fromLTWH(0.2, 0.2, 0.2, 0.2),
            timestampMs: 1,
          ),
        ],
        latencyMs: 12,
        frameIndex: 1,
      ),
    );
    const config = DetectionConfig(frameSampleInterval: 1);
    final pipeline = DetectionPipeline(detector: detector, config: config);
    final tts = _RecordingTtsService();
    final feedback = DetectionFeedbackController(
      pipeline: pipeline,
      audioHapticsBridge: const _FakeAudioHapticsBridge(),
      ttsService: tts,
      config: config,
    );

    await pipeline.initialize();
    pipeline.setTargetLabel('phone');
    pipeline.start();
    feedback.start();
    await pipeline.processFrame(_FakeCameraImage());
    await Future<void>.delayed(Duration.zero);

    expect(tts.spoken, ['Phone']);

    feedback.stop();
    pipeline.dispose();
  });
}

class _RecordingTtsService extends TtsService {
  final spoken = <String>[];

  @override
  Future<void> speak(String text, {bool interrupt = true}) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}

class _FakeAudioHapticsBridge extends AudioHapticsBridge {
  const _FakeAudioHapticsBridge();

  @override
  Future<void> playHaptic(HapticSignal signal) async {}
}

class _SingleFrameDetector implements ObjectDetector {
  _SingleFrameDetector(this.frame);

  final DetectionFrame frame;
  var _isReady = false;

  @override
  bool get isReady => _isReady;

  @override
  Future<void> initialize() async {
    _isReady = true;
  }

  @override
  Future<DetectionFrame> detect(
    CameraImage image, {
    int rotationDegrees = 0,
  }) async {
    return frame;
  }

  @override
  Future<void> dispose() async {
    _isReady = false;
  }
}

class _FakeCameraImage implements CameraImage {
  @override
  int get height => 480;

  @override
  int get width => 640;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
