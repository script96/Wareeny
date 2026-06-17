import 'dart:io';

class DangerModeConfig {
  const DangerModeConfig._();

  static const enabled = bool.fromEnvironment(
    'DANGER_MODE_ENABLED',
    defaultValue: true,
  );

  static const androidModelPath = 'assets/models/danger/danger_model.tflite';
  static const iosModelPath = 'assets/models/danger/danger_model.mlpackage.zip';
  static String get modelPath =>
      Platform.isIOS ? iosModelPath : androidModelPath;
  static const labelsPath = 'assets/models/danger/danger_labels.txt';
  static const exportMetadataPath =
      'assets/models/danger/danger_model_export.json';

  static const correctnessModelPath =
      'assets/models/danger/danger_model_float32.tflite';

  static const fireConfidence =
      int.fromEnvironment('DANGER_FIRE_CONFIDENCE_PERCENT', defaultValue: 70) /
      100.0;
  static const stopSignConfidence =
      int.fromEnvironment('DANGER_STOP_CONFIDENCE_PERCENT', defaultValue: 50) /
      100.0;
  static const wetFloorConfidence =
      int.fromEnvironment(
        'DANGER_WET_FLOOR_CONFIDENCE_PERCENT',
        defaultValue: 50,
      ) /
      100.0;
  static const exitSignConfidence =
      int.fromEnvironment('DANGER_EXIT_CONFIDENCE_PERCENT', defaultValue: 50) /
      100.0;

  static const fireSmallAreaThreshold =
      int.fromEnvironment('DANGER_FIRE_SMALL_AREA_PERCENT', defaultValue: 5) /
      100.0;
  static const firePanicAreaThreshold =
      int.fromEnvironment('DANGER_FIRE_PANIC_AREA_PERCENT', defaultValue: 15) /
      100.0;

  static const fireRepeatCooldown = Duration(
    seconds: int.fromEnvironment(
      'DANGER_FIRE_REPEAT_COOLDOWN_SECONDS',
      defaultValue: 3,
    ),
  );
  static const stopSignCooldown = Duration(
    seconds: int.fromEnvironment(
      'DANGER_STOP_COOLDOWN_SECONDS',
      defaultValue: 8,
    ),
  );
  static const wetFloorCooldown = Duration(
    seconds: int.fromEnvironment(
      'DANGER_WET_FLOOR_COOLDOWN_SECONDS',
      defaultValue: 8,
    ),
  );
  static const exitSignCooldown = Duration(
    seconds: int.fromEnvironment(
      'DANGER_EXIT_COOLDOWN_SECONDS',
      defaultValue: 5,
    ),
  );
  static const fireClearTimeout = Duration(
    seconds: int.fromEnvironment(
      'DANGER_FIRE_CLEAR_TIMEOUT_SECONDS',
      defaultValue: 7,
    ),
  );

  static const inferenceInterval = Duration(
    milliseconds: int.fromEnvironment(
      'DANGER_INFERENCE_INTERVAL_MS',
      defaultValue: 333,
    ),
  );
  static const maxDetectionsPerFrame = int.fromEnvironment(
    'DANGER_MAX_DETECTIONS_PER_FRAME',
    defaultValue: 8,
  );
}
