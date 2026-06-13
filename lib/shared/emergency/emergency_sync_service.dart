import 'package:wareeny/shared/emergency/emergency_api_client.dart';
import 'package:wareeny/shared/emergency/emergency_contact.dart';
import 'package:wareeny/shared/emergency/emergency_event_store.dart';

class EmergencySyncService {
  const EmergencySyncService({
    required EmergencyApiClient api,
    required EmergencyEventStore eventStore,
  }) : _api = api,
       _eventStore = eventStore;

  final EmergencyApiClient _api;
  final EmergencyEventStore _eventStore;

  void setTokenProvider(SessionTokenProvider? provider) {
    _api.setTokenProvider(provider);
  }

  Future<void> onSignedIn() async {
    try {
      await _api.bootstrap();
      await flushEvents();
    } catch (_) {
      // Cloud synchronization is best effort. Local safety must stay available.
    }
  }

  Future<void> syncContact(EmergencyContact contact) async {
    try {
      await _api.saveContact(contact);
    } catch (_) {
      // The confirmed contact is already stored locally.
    }
  }

  Future<EmergencyContact?> fetchContact() async {
    try {
      return await _api.getContact();
    } catch (_) {
      return null;
    }
  }

  Future<void> removeContact() async {
    try {
      await _api.deleteContact();
    } catch (_) {
      // Local removal still succeeds while offline.
    }
  }

  Future<void> flushEvents() async {
    final pending = await _eventStore.takePending();
    if (pending.isEmpty) return;

    final failed = <Map<String, dynamic>>[];
    for (final event in pending) {
      try {
        await _api.uploadEvent(event);
      } catch (_) {
        failed.add(event);
      }
    }
    await _eventStore.prependPending(failed);
  }
}
