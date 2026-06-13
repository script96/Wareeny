import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wareeny/shared/emergency/emergency_event.dart';
import 'package:wareeny/shared/emergency/emergency_event_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('preserves events appended while a failed batch is restored', () async {
    final store = EmergencyEventStore();
    final first = EmergencyEvent(
      id: 'event-0000000001',
      trigger: EmergencyTrigger.manualSos,
      outcome: EmergencyOutcome.detected,
      occurredAt: DateTime.utc(2026),
    );
    final second = EmergencyEvent(
      id: 'event-0000000002',
      trigger: EmergencyTrigger.probableFall,
      outcome: EmergencyOutcome.cancelled,
      occurredAt: DateTime.utc(2026, 1, 2),
    );

    await Future.wait([store.append(first), store.append(second)]);
    final batch = await store.takePending();
    expect(batch.map((event) => event['eventId']), [
      'event-0000000001',
      'event-0000000002',
    ]);

    final newEvent = EmergencyEvent(
      id: 'event-0000000003',
      trigger: EmergencyTrigger.manualSos,
      outcome: EmergencyOutcome.callAttempted,
      occurredAt: DateTime.utc(2026, 1, 3),
    );
    await store.append(newEvent);
    await store.prependPending([batch.first]);

    final pending = await store.takePending();
    expect(pending.map((event) => event['eventId']), [
      'event-0000000001',
      'event-0000000003',
    ]);
  });
}
