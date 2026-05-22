import 'package:wareny/core/config/app_config.dart';
import 'package:wareny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareny/shared/bridges/battery_thermal_bridge.dart';
import 'package:wareny/shared/bridges/camera_bridge.dart';
import 'package:wareny/shared/bridges/file_download_bridge.dart';
import 'package:wareny/shared/bridges/local_ai_runtime_bridge.dart';

class ServiceRegistry {
  const ServiceRegistry({
    required this.config,
    required this.cameraBridge,
    required this.audioHapticsBridge,
    required this.batteryThermalBridge,
    required this.fileDownloadBridge,
    required this.localAiRuntimeBridge,
  });

  final AppConfig config;
  final CameraBridge cameraBridge;
  final AudioHapticsBridge audioHapticsBridge;
  final BatteryThermalBridge batteryThermalBridge;
  final FileDownloadBridge fileDownloadBridge;
  final LocalAiRuntimeBridge localAiRuntimeBridge;

  factory ServiceRegistry.create(AppConfig config) {
    return ServiceRegistry(
      config: config,
      cameraBridge: const CameraBridge(),
      audioHapticsBridge: const AudioHapticsBridge(),
      batteryThermalBridge: const BatteryThermalBridge(),
      fileDownloadBridge: const FileDownloadBridge(),
      localAiRuntimeBridge: const LocalAiRuntimeBridge(),
    );
  }
}
