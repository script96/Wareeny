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
  // Reserved for future Arabic OCR native bridge (iOS Vision / Android cloud ML Kit)
  static const ocr = 'com.wareeny.bridge/ocr';
  // Emergency: direct SMS dispatch via Android SmsManager (no UI required)
  static const emergency = 'com.wareeny.bridge/emergency';
}
