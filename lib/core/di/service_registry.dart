import 'package:wareny/core/config/app_config.dart';
import 'package:wareny/core/detection/detection_config.dart';
import 'package:wareny/core/detection/detection_feedback_controller.dart';
import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/mock_object_detector.dart';
import 'package:wareny/core/tts/tts_service.dart';
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
    required this.ttsService,
    required this.detectionPipeline,
    required this.detectionFeedbackController,
  });

  final AppConfig config;
  final CameraBridge cameraBridge;
  final AudioHapticsBridge audioHapticsBridge;
  final BatteryThermalBridge batteryThermalBridge;
  final FileDownloadBridge fileDownloadBridge;
  final LocalAiRuntimeBridge localAiRuntimeBridge;
  final TtsService ttsService;
  final DetectionPipeline detectionPipeline;
  final DetectionFeedbackController detectionFeedbackController;

  factory ServiceRegistry.create(AppConfig config) {
    const detectionConfig = DetectionConfig();
    const audioHapticsBridge = AudioHapticsBridge();
    final ttsService = TtsService();
    final detectionPipeline = DetectionPipeline(
      detector: MockObjectDetector(),
      config: detectionConfig,
      enableDiagnostics: config.enableDiagnostics,
    );

    return ServiceRegistry(
      config: config,
      cameraBridge: const CameraBridge(),
      audioHapticsBridge: audioHapticsBridge,
      batteryThermalBridge: const BatteryThermalBridge(),
      fileDownloadBridge: const FileDownloadBridge(),
      localAiRuntimeBridge: const LocalAiRuntimeBridge(),
      ttsService: ttsService,
      detectionPipeline: detectionPipeline,
      detectionFeedbackController: DetectionFeedbackController(
        pipeline: detectionPipeline,
        audioHapticsBridge: audioHapticsBridge,
        ttsService: ttsService,
        config: detectionConfig,
        enableDiagnostics: config.enableDiagnostics,
      ),
    );
  }
}
