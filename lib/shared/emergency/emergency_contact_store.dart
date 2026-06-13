import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:wareeny/shared/emergency/emergency_contact.dart';

class EmergencyContactStore {
  EmergencyContactStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'emergency.primaryContact';
  final FlutterSecureStorage _storage;

  Future<EmergencyContact?> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    return EmergencyContact.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> write(EmergencyContact contact) async {
    final value = jsonEncode(contact.toJson());
    await _storage.write(key: _key, value: value);
  }

  Future<void> delete() => _storage.delete(key: _key);
}
