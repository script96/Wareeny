class NativeBridgeChannels {
  const NativeBridgeChannels._();

  static const camera = 'com.wareeny.bridge/camera';
  static const objectDetection = 'com.wareeny.bridge/object_detection';
  static const objectDetectionEvents =
      'com.wareeny.bridge/object_detection_events';
  static const audioHaptics = 'com.wareeny.bridge/audio_haptics';
  static const batteryThermal = 'com.wareeny.bridge/battery_thermal';
  static const fileDownload = 'com.wareeny.bridge/file_download';
  static const localAiRuntime = 'com.wareeny.bridge/local_ai_runtime';
  // Event channel for streamed on-device VLM token deltas (MediaPipe LLM Inference).
  static const localAiRuntimeStream =
      'com.wareeny.bridge/local_ai_runtime/stream';
}
