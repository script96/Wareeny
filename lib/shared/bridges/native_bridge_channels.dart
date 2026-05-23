class NativeBridgeChannels {
  const NativeBridgeChannels._();

  static const camera = 'com.wareeny.bridge/camera';
  static const audioHaptics = 'com.wareeny.bridge/audio_haptics';
  static const batteryThermal = 'com.wareeny.bridge/battery_thermal';
  static const fileDownload = 'com.wareeny.bridge/file_download';
  static const localAiRuntime = 'com.wareeny.bridge/local_ai_runtime';
  // Reserved for future Arabic OCR native bridge (iOS Vision / Android cloud ML Kit)
  static const ocr = 'com.wareeny.bridge/ocr';
}
