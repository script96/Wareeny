import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wareeny/core/emergency/emergency_contact.dart';

/// Manages user preferences (locale, speech rate, haptics) with persistence.
/// Extend this class via [addListener] to react to any setting change.
class SettingsController extends ChangeNotifier {
  SettingsController._({
    required this._locale,
    required this._speechRate,
    required this._hapticsEnabled,
    required List<EmergencyContact> emergencyContacts,
    required this._shareLocationWithEmergencyContacts,
    required this._hasSeenEmergencyOnboarding,
  }) : _emergencyContacts = List.of(emergencyContacts);

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const _keyLocale = 'settings.locale';
  static const _keySpeechRate = 'settings.speechRate';
  static const _keyHaptics = 'settings.hapticsEnabled';
  static const _keyContacts = 'settings.emergencyContacts';
  static const _keyShareEmergencyLocation = 'settings.shareEmergencyLocation';
  static const _keyOnboardingSeen = 'settings.emergencyOnboardingSeen';

  // Defaults
  static const _defaultLocale = 'en';
  static const _defaultSpeechRate = 0.45;
  static const _defaultHaptics = true;
  static const _defaultShareEmergencyLocation = true;

  // ── State ─────────────────────────────────────────────────────────────────
  Locale _locale;
  double _speechRate;
  bool _hapticsEnabled;
  List<EmergencyContact> _emergencyContacts;
  bool _shareLocationWithEmergencyContacts;
  bool _hasSeenEmergencyOnboarding;

  Locale get locale => _locale;
  double get speechRate => _speechRate;
  bool get hapticsEnabled => _hapticsEnabled;
  List<EmergencyContact> get emergencyContacts =>
      List.unmodifiable(_emergencyContacts);
  bool get shareLocationWithEmergencyContacts =>
      _shareLocationWithEmergencyContacts;
  bool get hasSeenEmergencyOnboarding => _hasSeenEmergencyOnboarding;

  bool get isArabic => _locale.languageCode == 'ar';

  // ── Factory: load from SharedPreferences ─────────────────────────────────
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_keyLocale) ?? _defaultLocale;
    final speechRate = prefs.getDouble(_keySpeechRate) ?? _defaultSpeechRate;
    final hapticsEnabled = prefs.getBool(_keyHaptics) ?? _defaultHaptics;
    final contactsJson = prefs.getString(_keyContacts);
    final contacts = contactsJson != null
        ? EmergencyContact.decodeList(contactsJson)
        : <EmergencyContact>[];
    final shareEmergencyLocation =
        prefs.getBool(_keyShareEmergencyLocation) ??
        _defaultShareEmergencyLocation;
    final onboardingSeen = prefs.getBool(_keyOnboardingSeen) ?? false;

    return SettingsController._(
      locale: Locale(localeCode),
      speechRate: speechRate,
      hapticsEnabled: hapticsEnabled,
      emergencyContacts: contacts,
      shareLocationWithEmergencyContacts: shareEmergencyLocation,
      hasSeenEmergencyOnboarding: onboardingSeen,
    );
  }

  // ── Setters ───────────────────────────────────────────────────────────────
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);
  }

  Future<void> setSpeechRate(double rate) async {
    final clamped = rate.clamp(0.1, 1.0);
    if (_speechRate == clamped) return;
    _speechRate = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keySpeechRate, clamped);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    if (_hapticsEnabled == enabled) return;
    _hapticsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHaptics, enabled);
  }

  Future<void> setEmergencyContacts(List<EmergencyContact> contacts) async {
    _emergencyContacts = List.of(contacts);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyContacts,
      EmergencyContact.encodeList(_emergencyContacts),
    );
  }

  Future<void> setShareLocationWithEmergencyContacts(bool enabled) async {
    if (_shareLocationWithEmergencyContacts == enabled) return;
    _shareLocationWithEmergencyContacts = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShareEmergencyLocation, enabled);
  }

  Future<void> markEmergencyOnboardingSeen() async {
    if (_hasSeenEmergencyOnboarding) return;
    _hasSeenEmergencyOnboarding = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingSeen, true);
  }
}
