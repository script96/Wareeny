import 'package:uuid/uuid.dart';
import 'package:wareeny/shared/emergency/emergency_location_service.dart';

enum EmergencyTrigger { manualSos, probableFall }

enum EmergencyOutcome { detected, cancelled, callAttempted, callFailed }

class EmergencyEvent {
  EmergencyEvent({
    required this.trigger,
    required this.outcome,
    required this.occurredAt,
    String? id,
    this.sensorSummary,
    this.location,
  }) : id = id ?? const Uuid().v4();

  final String id;
  final EmergencyTrigger trigger;
  final EmergencyOutcome outcome;
  final DateTime occurredAt;
  final Map<String, double>? sensorSummary;
  final EmergencyLocation? location;

  Map<String, dynamic> toJson() => {
    'eventId': id,
    'trigger': switch (trigger) {
      EmergencyTrigger.manualSos => 'manual_sos',
      EmergencyTrigger.probableFall => 'probable_fall',
    },
    'outcome': outcome.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    if (sensorSummary != null) 'sensorSummary': sensorSummary,
    if (location != null) 'location': location!.toJson(),
  };
}
