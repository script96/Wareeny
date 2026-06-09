import 'package:flutter/foundation.dart';

class LumaPlaceholderService {
  const LumaPlaceholderService({required this.backendUrl});

  final String backendUrl;

  Future<void> speak(String text) async {
    debugPrint('Luma speak: $text');
  }

  Future<void> repeatLastMessage(String text) async {
    debugPrint('Luma repeat: $text');
  }

  Future<void> triggerHaptic(String type) async {
    debugPrint('Luma haptic: $type');
  }

  Future<void> switchMode(String mode) async {
    debugPrint('Switch mode: $mode');
  }

  Future<void> switchEnvironment(String environment) async {
    debugPrint('Switch environment: $environment');
  }

  Future<void> startListening() async {
    debugPrint('Start listening');
  }

  Future<void> stopListening() async {
    debugPrint('Stop listening');
  }

  Future<void> startCameraMode(String mode) async {
    debugPrint('Start camera mode: $mode');
  }

  Future<void> stopCameraMode() async {
    debugPrint('Stop camera mode');
  }

  Future<void> scanText() async {
    debugPrint('Scan text');
  }

  Future<void> callEmergencyContact() async {
    debugPrint('Call emergency contact');
  }

  Future<String> checkBackendHealth() async {
    debugPrint('Check backend health: $backendUrl/health');
    return 'Healthy (placeholder)';
  }
}
