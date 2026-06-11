import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user preferences (locale, speech rate, haptics) with persistence.
/// Extend this class via [addListener] to react to any setting change.
class SettingsController extends ChangeNotifier {
  SettingsController._({
    required Locale locale,
    required double speechRate,
    required bool hapticsEnabled,
  })  : _locale = locale,
        _speechRate = speechRate,
        _hapticsEnabled = hapticsEnabled;

  // ── Keys ─────────────────────────────────────────────────────────────────
  static const _keyLocale = 'settings.locale';
  static const _keySpeechRate = 'settings.speechRate';
  static const _keyHaptics = 'settings.hapticsEnabled';

  // Defaults
  static const _defaultLocale = 'en';
  static const _defaultSpeechRate = 0.45;
  static const _defaultHaptics = true;

  // ── State ─────────────────────────────────────────────────────────────────
  Locale _locale;
  double _speechRate;
  bool _hapticsEnabled;

  Locale get locale => _locale;
  double get speechRate => _speechRate;
  bool get hapticsEnabled => _hapticsEnabled;

  bool get isArabic => _locale.languageCode == 'ar';

  // ── Factory: load from SharedPreferences ─────────────────────────────────
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_keyLocale) ?? _defaultLocale;
    final speechRate = prefs.getDouble(_keySpeechRate) ?? _defaultSpeechRate;
    final hapticsEnabled = prefs.getBool(_keyHaptics) ?? _defaultHaptics;

    return SettingsController._(
      locale: Locale(localeCode),
      speechRate: speechRate,
      hapticsEnabled: hapticsEnabled,
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
}
