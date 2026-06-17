import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wareeny/shared/danger/danger_config.dart';
import 'package:wareeny/shared/danger/danger_detection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundles the danger assets used by the YOLO loader', () async {
    final labels = await rootBundle.loadString(DangerModeConfig.labelsPath);
    expect(labels.split('\n').map((line) => line.trim()), contains('Fire'));

    final androidRuntimeModel = await rootBundle.load(
      DangerModeConfig.androidModelPath,
    );
    expect(androidRuntimeModel.lengthInBytes, greaterThan(1024 * 1024));

    final iosRuntimeModel = await rootBundle.load(
      DangerModeConfig.iosModelPath,
    );
    expect(iosRuntimeModel.lengthInBytes, greaterThan(100 * 1024));

    final correctnessModel = await rootBundle.load(
      DangerModeConfig.correctnessModelPath,
    );
    expect(
      correctnessModel.lengthInBytes,
      greaterThan(androidRuntimeModel.lengthInBytes),
    );
  });

  test(
    'materializes the danger model asset as a native-readable file',
    () async {
      final engine = YoloDangerInferenceEngine();
      final path = await engine.prepareBundledModelFileForTesting(
        DangerModeConfig.modelPath,
      );

      final bytes = await rootBundle.load(DangerModeConfig.modelPath);
      if (Platform.isIOS) {
        expect(path, DangerModeConfig.iosModelPath);
      } else {
        expect(path, isNot(startsWith('assets/')));
        expect(path, endsWith('danger_model.tflite'));
        expect(await File(path).length(), bytes.lengthInBytes);
      }
      expect(bytes.lengthInBytes, greaterThan(1024 * 1024));
    },
  );

  test('keeps the iOS Core ML archive on the Flutter asset path', () async {
    final engine = YoloDangerInferenceEngine(
      modelPath: DangerModeConfig.iosModelPath,
    );
    final path = await engine.prepareBundledModelFileForTesting(
      DangerModeConfig.iosModelPath,
    );

    expect(path, DangerModeConfig.iosModelPath);
    final bytes = await rootBundle.load(path);
    expect(bytes.lengthInBytes, greaterThan(100 * 1024));
  });
}
