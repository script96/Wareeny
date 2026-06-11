import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/core/emergency/emergency_controller.dart';
import 'package:wareeny/core/emergency/location_service.dart';
import 'package:wareeny/core/emergency/shake_detector_service.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/battery_thermal_bridge.dart';
import 'package:wareeny/shared/bridges/camera_bridge.dart';
import 'package:wareeny/shared/bridges/file_download_bridge.dart';
import 'package:wareeny/shared/bridges/local_ai_runtime_bridge.dart';
import 'package:wareeny/shared/bridges/ocr_bridge.dart';
import 'package:wareeny/shared/object_detection/object_detection_source.dart';

class ServiceRegistry {
  ServiceRegistry({
    required this.config,
    required this.settings,
    required this.cameraBridge,
    required this.audioHapticsBridge,
    required this.batteryThermalBridge,
    required this.fileDownloadBridge,
    required this.localAiRuntimeBridge,
    required this.ocrBridge,
    required this.objectDetectionSource,
    required this.shakeDetectorService,
    required this.locationService,
    required this.emergencyController,
  });

  final AppConfig config;
  final SettingsController settings;
  final CameraBridge cameraBridge;
  final AudioHapticsBridge audioHapticsBridge;
  final BatteryThermalBridge batteryThermalBridge;
  final FileDownloadBridge fileDownloadBridge;
  final LocalAiRuntimeBridge localAiRuntimeBridge;
  final OcrBridge ocrBridge;
  final ObjectDetectionSource objectDetectionSource;
  final ShakeDetectorService shakeDetectorService;
  final LocationService locationService;
  final EmergencyController emergencyController;

  /// Use [ServiceRegistry.createAsync] during bootstrap instead of this factory,
  /// because [SettingsController] must be loaded from SharedPreferences first.
  static Future<ServiceRegistry> createAsync(AppConfig config) async {
    final settings = await SettingsController.load();
    final audioHapticsBridge = AudioHapticsBridge();
    final shakeDetector = ShakeDetectorService();
    final locationService = LocationService();
    final emergencyController = EmergencyController(
      settings: settings,
      shakeDetector: shakeDetector,
      locationService: locationService,
      audioHaptics: audioHapticsBridge,
    );
    return ServiceRegistry(
      config: config,
      settings: settings,
      cameraBridge: const CameraBridge(),
      audioHapticsBridge: audioHapticsBridge,
      batteryThermalBridge: const BatteryThermalBridge(),
      fileDownloadBridge: const FileDownloadBridge(),
      localAiRuntimeBridge: const LocalAiRuntimeBridge(),
      ocrBridge: OcrBridge(),
      objectDetectionSource: UltralyticsYoloDetectionSource(),
      shakeDetectorService: shakeDetector,
      locationService: locationService,
      emergencyController: emergencyController,
    );
  }
}
