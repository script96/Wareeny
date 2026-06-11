import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/battery_thermal_bridge.dart';
import 'package:wareeny/shared/bridges/camera_bridge.dart';
import 'package:wareeny/shared/bridges/file_download_bridge.dart';
import 'package:wareeny/shared/bridges/local_ai_runtime_bridge.dart';
import 'package:wareeny/shared/vlm/cloud_vlm_provider.dart';
import 'package:wareeny/shared/vlm/local_vlm_provider.dart';
import 'package:wareeny/shared/vlm/model_router.dart';
import 'package:wareeny/shared/vlm/vlm_assistant.dart';

class ServiceRegistry {
  ServiceRegistry({
    required this.config,
    required this.cameraBridge,
    required this.audioHapticsBridge,
    required this.batteryThermalBridge,
    required this.fileDownloadBridge,
    required this.localAiRuntimeBridge,
    required this.vlmAssistant,
  });

  final AppConfig config;
  final CameraBridge cameraBridge;
  final AudioHapticsBridge audioHapticsBridge;
  final BatteryThermalBridge batteryThermalBridge;
  final FileDownloadBridge fileDownloadBridge;
  final LocalAiRuntimeBridge localAiRuntimeBridge;
  final VlmAssistant vlmAssistant;

  factory ServiceRegistry.create(AppConfig config) {
    const localAiRuntimeBridge = LocalAiRuntimeBridge();

    final local = LocalVlmProvider(
      runtime: localAiRuntimeBridge,
      modelId: config.localModelRegistryName,
    );
    final cloud = CloudVlmProvider(
      apiBaseUrl: config.apiBaseUrl,
      modelId: config.cloudModelId,
    );
    final router = ModelRouter(local: local, cloud: cloud);

    return ServiceRegistry(
      config: config,
      cameraBridge: const CameraBridge(),
      audioHapticsBridge: const AudioHapticsBridge(),
      batteryThermalBridge: const BatteryThermalBridge(),
      fileDownloadBridge: const FileDownloadBridge(),
      localAiRuntimeBridge: localAiRuntimeBridge,
      vlmAssistant: VlmAssistant(router: router),
    );
  }
}
