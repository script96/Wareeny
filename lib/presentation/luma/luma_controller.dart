import 'package:flutter/foundation.dart';

import 'package:wareeny/core/config/app_config.dart';
import 'package:wareeny/presentation/luma/luma_data.dart';
import 'package:wareeny/presentation/luma/luma_models.dart';
import 'package:wareeny/shared/services/luma_placeholder_service.dart';

class LumaController extends ChangeNotifier {
  LumaController({
    required AppConfig config,
    LumaPlaceholderService? service,
  }) : _service =
            service ?? LumaPlaceholderService(backendUrl: config.apiBaseUrl),
       _backendUrl = config.apiBaseUrl;

  final LumaPlaceholderService _service;
  final String _backendUrl;

  bool introCompleted = false;
  LumaSection currentSection = LumaSection.home;
  LumaEnvironment currentEnvironment = LumaEnvironment.indoor;
  AssistantUiState uiState = AssistantUiState.idle;
  LumaModeDefinition? currentMode = lumaModes.first;
  String assistantMessage =
      'Luma is ready. Hold to speak or choose a mode.';
  String lastSpokenMessage = 'Chair ahead, slightly right.';
  bool privacyModeEnabled = true;
  bool askBeforeSensitiveText = true;
  bool hapticsEnabled = true;
  bool shakeToActivateDangerMode = true;
  bool batterySavingMode = false;
  bool locationSharingEnabled = false;
  bool localOnlySavedImages = true;
  String assistantVoice = 'Luma';
  String speechSpeed = 'Normal';
  String language = 'English';
  String backendStatus = 'Unknown';
  String thermalStatus = 'Normal';
  String frameSamplingLevel = 'Balanced';
  DetectionSnapshot detectionSnapshot = const DetectionSnapshot(
    summary: 'Bottle ahead, slightly left.',
    direction: 'Slightly left',
    proximity: 'Near',
    confidence: 'High',
  );
  ReadingSnapshot readingSnapshot = const ReadingSnapshot(
    summary: 'Text detected. Hold steady.',
    resultText: 'Entrance. Floor two. Lift on the right.',
    framingCue: 'Hold steady',
  );
  final List<SavedItemEntry> savedItems = List.of(mockSavedItems);

  String get backendUrl => _backendUrl;

  List<LumaModeDefinition> get visibleModes {
    return lumaModes
        .where((mode) => mode.supports(currentEnvironment))
        .toList(growable: false);
  }

  List<LumaModeDefinition> modesForCategory(LumaModeCategory category) {
    return visibleModes.where((mode) => mode.category == category).toList();
  }

  void completeIntro() {
    introCompleted = true;
    notifyListeners();
  }

  void selectSection(LumaSection section) {
    currentSection = section;
    notifyListeners();
  }

  Future<void> switchEnvironment(LumaEnvironment environment) async {
    currentEnvironment = environment;
    await _service.switchEnvironment(environment.label);
    await _service.triggerHaptic('environment');

    if (currentMode != null && !currentMode!.supports(environment)) {
      final modes = visibleModes;
      currentMode = modes.isEmpty ? null : modes.first;
    }

    assistantMessage =
        '${environment.label} mode selected. Choose manually for better safety and accuracy.';
    lastSpokenMessage = assistantMessage;
    notifyListeners();
  }

  Future<void> switchMode(LumaModeDefinition mode) async {
    currentMode = mode;
    uiState = mode.screenType == ActiveScreenType.objectDetection
        ? AssistantUiState.guiding
        : AssistantUiState.scanning;
    await _service.switchMode(mode.title);
    await _service.speak('${mode.title} ready.');
    assistantMessage = '${mode.title} ready in ${currentEnvironment.label}.';
    lastSpokenMessage = assistantMessage;
    _refreshSnapshotsForMode(mode);
    notifyListeners();
  }

  Future<void> startListening() async {
    uiState = AssistantUiState.listening;
    assistantMessage =
        'Listening. Try saying Find my keys, Read this, or Call emergency.';
    await _service.startListening();
    if (hapticsEnabled) {
      await _service.triggerHaptic('listening');
    }
    notifyListeners();
  }

  Future<void> stopListening() async {
    uiState = AssistantUiState.idle;
    assistantMessage = 'Listening stopped.';
    await _service.stopListening();
    notifyListeners();
  }

  Future<void> startCameraMode(LumaModeDefinition mode) async {
    currentMode = mode;
    uiState = mode.screenType == ActiveScreenType.objectDetection
        ? AssistantUiState.guiding
        : AssistantUiState.scanning;
    await _service.startCameraMode(mode.title);
    _refreshSnapshotsForMode(mode);
    notifyListeners();
  }

  Future<void> stopCameraMode() async {
    uiState = AssistantUiState.idle;
    assistantMessage = 'Luma stopped the current mode.';
    await _service.stopCameraMode();
    notifyListeners();
  }

  Future<void> repeatLastMessage() async {
    await _service.repeatLastMessage(lastSpokenMessage);
  }

  Future<void> speak(String text) async {
    lastSpokenMessage = text;
    assistantMessage = text;
    await _service.speak(text);
    notifyListeners();
  }

  Future<void> triggerHaptic(String type) async {
    if (!hapticsEnabled) {
      return;
    }
    await _service.triggerHaptic(type);
  }

  Future<void> scanText() async {
    uiState = AssistantUiState.reading;
    await _service.scanText();
    readingSnapshot = const ReadingSnapshot(
      summary: 'Text detected. Hold steady.',
      resultText:
          'Entrance. Floor two. Lift on the right. Emergency stairs behind the glass door.',
      framingCue: 'Text detected',
    );
    assistantMessage = readingSnapshot.summary;
    lastSpokenMessage = readingSnapshot.resultText;
    notifyListeners();
  }

  Future<void> pauseReading() async {
    uiState = AssistantUiState.idle;
    assistantMessage = 'Reading paused.';
    notifyListeners();
  }

  Future<void> triggerDanger([String? message]) async {
    uiState = AssistantUiState.danger;
    assistantMessage = message ?? 'Obstacle very close ahead.';
    lastSpokenMessage = assistantMessage;
    await _service.triggerHaptic('danger');
    await _service.speak(assistantMessage);
    notifyListeners();
  }

  Future<void> callEmergencyContact() async {
    uiState = AssistantUiState.emergency;
    assistantMessage =
        'Calling your emergency contact and preparing location sharing.';
    lastSpokenMessage = assistantMessage;
    await _service.callEmergencyContact();
    notifyListeners();
  }

  Future<void> cancelDangerMode() async {
    uiState = AssistantUiState.warning;
    assistantMessage = 'Danger mode cancelled. Stay alert.';
    notifyListeners();
  }

  void togglePrivacyMode(bool value) {
    privacyModeEnabled = value;
    assistantMessage = value ? 'Privacy mode is on.' : 'Privacy mode is off.';
    notifyListeners();
  }

  void toggleAskBeforeSensitiveText(bool value) {
    askBeforeSensitiveText = value;
    notifyListeners();
  }

  void toggleHaptics(bool value) {
    hapticsEnabled = value;
    notifyListeners();
  }

  void toggleShakeToActivate(bool value) {
    shakeToActivateDangerMode = value;
    notifyListeners();
  }

  void toggleBatterySaving(bool value) {
    batterySavingMode = value;
    frameSamplingLevel = value ? 'Low' : 'Balanced';
    notifyListeners();
  }

  void toggleLocationSharing(bool value) {
    locationSharingEnabled = value;
    notifyListeners();
  }

  void toggleLocalOnlySavedImages(bool value) {
    localOnlySavedImages = value;
    notifyListeners();
  }

  void updateAssistantVoice(String value) {
    assistantVoice = value;
    notifyListeners();
  }

  void updateSpeechSpeed(String value) {
    speechSpeed = value;
    notifyListeners();
  }

  void updateLanguage(String value) {
    language = value;
    notifyListeners();
  }

  void updateFrameSampling(String value) {
    frameSamplingLevel = value;
    notifyListeners();
  }

  Future<void> handleSuggestedCommand(SuggestedCommand command) async {
    if (command.environment != null) {
      await switchEnvironment(command.environment!);
    }
    if (command.opensDanger) {
      await triggerDanger('Emergency command requested.');
      return;
    }

    final matches = lumaModes.where((item) => item.kind == command.modeKind);
    final mode = matches.isEmpty ? null : matches.first;
    if (mode != null) {
      await switchMode(mode);
    }
  }

  Future<void> checkBackendHealth() async {
    backendStatus = await _service.checkBackendHealth();
    notifyListeners();
  }

  void cycleDetectionTarget() {
    final next = switch (currentMode?.kind) {
      LumaModeKind.stuffFinder => const DetectionSnapshot(
          summary: 'Keys ahead, slightly right.',
          direction: 'Slightly right',
          proximity: 'Near',
          confidence: 'Medium',
        ),
      LumaModeKind.savedItemFinder => const DetectionSnapshot(
          summary: 'Saved wallet ahead, center.',
          direction: 'Center',
          proximity: 'Very close',
          confidence: 'High',
        ),
      LumaModeKind.trafficLightStatus => const DetectionSnapshot(
          summary: 'Traffic light green.',
          direction: 'Center',
          proximity: 'Far',
          confidence: 'High',
        ),
      _ => const DetectionSnapshot(
          summary: 'Door ahead, slightly left.',
          direction: 'Slightly left',
          proximity: 'Near',
          confidence: 'Medium',
        ),
    };
    detectionSnapshot = next;
    lastSpokenMessage = next.summary;
    assistantMessage = next.summary;
    notifyListeners();
  }

  void saveItem(String name) {
    final item = SavedItemEntry(
      name: name,
      label: name.toLowerCase(),
      referenceImagePath:
          '/mock/storage/items/${name.toLowerCase().replaceAll(' ', '_')}.jpg',
      createdDate: DateTime.now(),
    );
    savedItems.insert(0, item);
    assistantMessage = 'Saved. You can now ask Luma to find this item.';
    notifyListeners();
  }

  void renameItem(SavedItemEntry item, String newName) {
    final index = savedItems.indexOf(item);
    if (index == -1) {
      return;
    }
    savedItems[index] = item.copyWith(
      name: newName,
      label: newName.toLowerCase(),
    );
    notifyListeners();
  }

  void deleteItem(SavedItemEntry item) {
    savedItems.remove(item);
    notifyListeners();
  }

  void markItemFound(SavedItemEntry item) {
    final index = savedItems.indexOf(item);
    if (index == -1) {
      return;
    }
    savedItems[index] = item.copyWith(lastFoundDate: DateTime.now());
    lastSpokenMessage = '${item.name} found nearby.';
    assistantMessage = lastSpokenMessage;
    notifyListeners();
  }

  void _refreshSnapshotsForMode(LumaModeDefinition mode) {
    switch (mode.screenType) {
      case ActiveScreenType.objectDetection:
        detectionSnapshot = switch (mode.kind) {
          LumaModeKind.whatsInMyHand => const DetectionSnapshot(
              summary: 'Object centered in your hand view.',
              direction: 'Center',
              proximity: 'Very close',
              confidence: 'High',
            ),
          LumaModeKind.obstacleAvoidance => const DetectionSnapshot(
              summary: 'Chair ahead, slightly right.',
              direction: 'Slightly right',
              proximity: 'Near',
              confidence: 'High',
            ),
          LumaModeKind.trafficLightStatus => const DetectionSnapshot(
              summary: 'Traffic light red.',
              direction: 'Center',
              proximity: 'Far',
              confidence: 'High',
            ),
          _ => const DetectionSnapshot(
              summary: 'Bottle ahead, slightly left.',
              direction: 'Slightly left',
              proximity: 'Near',
              confidence: 'High',
            ),
        };
        assistantMessage = detectionSnapshot.summary;
        lastSpokenMessage = detectionSnapshot.summary;
        break;
      case ActiveScreenType.reading:
        readingSnapshot = switch (mode.kind) {
          LumaModeKind.currencyReader => const ReadingSnapshot(
              summary: 'Text detected. Hold steady.',
              resultText: 'Egyptian pound note detected. Fifty pounds.',
              framingCue: 'Move closer',
            ),
          LumaModeKind.privacyMode => const ReadingSnapshot(
              summary: 'Private details may be present.',
              resultText: 'Phone number and address detected.',
              framingCue: 'Hold steady',
            ),
          LumaModeKind.dangerWordAlerts => const ReadingSnapshot(
              summary: 'Danger word detected.',
              resultText: 'Warning. Wet floor.',
              framingCue: 'Text detected',
            ),
          _ => const ReadingSnapshot(
              summary: 'Text detected. Hold steady.',
              resultText: 'Entrance. Floor two.',
              framingCue: 'Move phone slightly up',
            ),
        };
        assistantMessage = readingSnapshot.summary;
        lastSpokenMessage = readingSnapshot.resultText;
        break;
    }
  }
}
