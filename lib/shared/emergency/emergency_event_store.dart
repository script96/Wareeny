import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:wareeny/shared/emergency/emergency_event.dart';

class EmergencyEventStore {
  static const _key = 'emergency.pendingEvents';
  Future<void> _tail = Future.value();

  Future<void> append(EmergencyEvent event) => _runExclusive(() async {
    final prefs = await SharedPreferences.getInstance();
    final events = prefs.getStringList(_key) ?? <String>[];
    events.add(jsonEncode(event.toJson()));
    await prefs.setStringList(_key, events);
  });

  Future<List<Map<String, dynamic>>> takePending() => _runExclusive(() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getStringList(_key) ?? <String>[];
    await prefs.setStringList(_key, const []);
    return encoded
        .map((value) => jsonDecode(value) as Map<String, dynamic>)
        .toList(growable: false);
  });

  Future<void> prependPending(List<Map<String, dynamic>> events) =>
      _runExclusive(() async {
        if (events.isEmpty) return;
        final prefs = await SharedPreferences.getInstance();
        final current = prefs.getStringList(_key) ?? <String>[];
        await prefs.setStringList(_key, [
          ...events.map(jsonEncode),
          ...current,
        ]);
      });

  Future<T> _runExclusive<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
