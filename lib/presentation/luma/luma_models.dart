import 'package:flutter/material.dart';

enum LumaSection {
  home('Home', Icons.home_rounded),
  modes('Modes', Icons.grid_view_rounded),
  savedItems('Saved Items', Icons.bookmark_rounded),
  settings('Settings', Icons.settings_rounded);

  const LumaSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

enum LumaEnvironment {
  indoor('Indoor'),
  outdoor('Outdoor');

  const LumaEnvironment(this.label);

  final String label;
}

enum AssistantUiState {
  idle('Idle'),
  listening('Listening'),
  scanning('Scanning'),
  guiding('Guiding'),
  reading('Reading'),
  warning('Warning'),
  danger('Danger'),
  emergency('Emergency');

  const AssistantUiState(this.label);

  final String label;
}

enum LumaModeCategory {
  objectDetection('Object Detection'),
  ocr('OCR'),
  safety('Safety'),
  support('Support');

  const LumaModeCategory(this.label);

  final String label;
}

enum LumaModeKind {
  stuffFinder,
  whatsInMyHand,
  savedItemFinder,
  obstacleAvoidance,
  indoorNavigation,
  outdoorDetection,
  outdoorObjectFinder,
  trafficLightStatus,
  documentReader,
  quickTextScanner,
  outdoorReader,
  currencyReader,
  brandDetector,
  privacyMode,
  dangerWordAlerts,
  qaMode,
}

enum ActiveScreenType {
  objectDetection,
  reading,
}

class LumaModeDefinition {
  const LumaModeDefinition({
    required this.kind,
    required this.title,
    required this.description,
    required this.category,
    required this.screenType,
    required this.icon,
    this.supportedEnvironments = const {
      LumaEnvironment.indoor,
      LumaEnvironment.outdoor,
    },
  });

  final LumaModeKind kind;
  final String title;
  final String description;
  final LumaModeCategory category;
  final ActiveScreenType screenType;
  final IconData icon;
  final Set<LumaEnvironment> supportedEnvironments;

  bool supports(LumaEnvironment environment) {
    return supportedEnvironments.contains(environment);
  }
}

class SuggestedCommand {
  const SuggestedCommand({
    required this.label,
    this.modeKind,
    this.environment,
    this.opensDanger = false,
  });

  final String label;
  final LumaModeKind? modeKind;
  final LumaEnvironment? environment;
  final bool opensDanger;
}

class SavedItemEntry {
  const SavedItemEntry({
    required this.name,
    required this.label,
    required this.referenceImagePath,
    required this.createdDate,
    this.lastFoundDate,
  });

  final String name;
  final String label;
  final String referenceImagePath;
  final DateTime createdDate;
  final DateTime? lastFoundDate;

  SavedItemEntry copyWith({
    String? name,
    String? label,
    String? referenceImagePath,
    DateTime? createdDate,
    DateTime? lastFoundDate,
  }) {
    return SavedItemEntry(
      name: name ?? this.name,
      label: label ?? this.label,
      referenceImagePath: referenceImagePath ?? this.referenceImagePath,
      createdDate: createdDate ?? this.createdDate,
      lastFoundDate: lastFoundDate ?? this.lastFoundDate,
    );
  }
}

class DetectionSnapshot {
  const DetectionSnapshot({
    required this.summary,
    required this.direction,
    required this.proximity,
    required this.confidence,
  });

  final String summary;
  final String direction;
  final String proximity;
  final String confidence;
}

class ReadingSnapshot {
  const ReadingSnapshot({
    required this.summary,
    required this.resultText,
    required this.framingCue,
  });

  final String summary;
  final String resultText;
  final String framingCue;
}
