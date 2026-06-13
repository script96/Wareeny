import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wareeny/core/localization/app_localizations.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/emergency_call_bridge.dart';
import 'package:wareeny/shared/emergency/emergency_contact.dart';
import 'package:wareeny/shared/emergency/emergency_contact_store.dart';
import 'package:wareeny/shared/emergency/emergency_event.dart';
import 'package:wareeny/shared/emergency/emergency_event_store.dart';
import 'package:wareeny/shared/emergency/emergency_location_service.dart';
import 'package:wareeny/shared/emergency/emergency_sync_service.dart';
import 'package:wareeny/shared/emergency/fall_detection_engine.dart';
import 'package:wareeny/shared/emergency/motion_monitoring_service.dart';

enum EmergencyAlertState { idle, countingDown, calling, callFailed }

class EmergencyController extends ChangeNotifier {
  EmergencyController({
    required EmergencyContactStore contactStore,
    required EmergencyEventStore eventStore,
    required EmergencySyncService syncService,
    required MotionMonitoringService motionMonitoring,
    required EmergencyCallBridge callBridge,
    required AudioHapticsBridge audioHaptics,
    required SettingsController settings,
    required EmergencyLocationService locationService,
  }) : _contactStore = contactStore,
       _eventStore = eventStore,
       _syncService = syncService,
       _motionMonitoring = motionMonitoring,
       _callBridge = callBridge,
       _audioHaptics = audioHaptics,
       _settings = settings,
       _locationService = locationService;

  static const _monitoringKey = 'emergency.monitoringEnabled';
  static const _locationSharingKey = 'emergency.locationSharingEnabled';
  static const countdownDuration = 10;

  final EmergencyContactStore _contactStore;
  final EmergencyEventStore _eventStore;
  final EmergencySyncService _syncService;
  final MotionMonitoringService _motionMonitoring;
  final EmergencyCallBridge _callBridge;
  final AudioHapticsBridge _audioHaptics;
  final SettingsController _settings;
  final EmergencyLocationService _locationService;

  EmergencyContact? _contact;
  EmergencyAlertState _alertState = EmergencyAlertState.idle;
  EmergencyTrigger _activeTrigger = EmergencyTrigger.manualSos;
  Timer? _timer;
  int _secondsRemaining = countdownDuration;
  bool _monitoringEnabled = false;
  Map<String, double>? _activeSensorSummary;
  EmergencyLocation? _activeLocation;
  bool _locationSharingEnabled = false;

  EmergencyContact? get contact => _contact;
  EmergencyAlertState get alertState => _alertState;
  int get secondsRemaining => _secondsRemaining;
  bool get monitoringEnabled => _monitoringEnabled;
  bool get isAlertActive => _alertState != EmergencyAlertState.idle;
  bool get locationSharingEnabled => _locationSharingEnabled;

  Future<void> initialize() async {
    _contact = await _contactStore.read();
    final prefs = await SharedPreferences.getInstance();
    _monitoringEnabled = prefs.getBool(_monitoringKey) ?? false;
    _locationSharingEnabled = prefs.getBool(_locationSharingKey) ?? false;
    if (_monitoringEnabled && _contact != null) await _startMonitoring();
    notifyListeners();
  }

  Future<void> saveContact(EmergencyContact contact) async {
    await _contactStore.write(contact);
    _contact = contact;
    notifyListeners();
    unawaited(_syncService.syncContact(contact));
    if (_monitoringEnabled) await _startMonitoring();
  }

  Future<void> restoreContactFromCloud() async {
    if (_contact != null) return;
    final contact = await _syncService.fetchContact();
    if (contact == null) return;
    await _contactStore.write(contact);
    _contact = contact;
    notifyListeners();
  }

  Future<void> removeContact() async {
    cancelAlert();
    await _motionMonitoring.stop();
    await _contactStore.delete();
    _contact = null;
    notifyListeners();
    unawaited(_syncService.removeContact());
  }

  Future<void> setMonitoringEnabled(bool enabled) async {
    _monitoringEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_monitoringKey, enabled);
    if (enabled && _contact != null) {
      await _startMonitoring();
    } else {
      await _motionMonitoring.stop();
    }
    notifyListeners();
  }

  Future<void> setLocationSharingEnabled(bool enabled) async {
    if (enabled) {
      enabled = await _locationService.requestWhenInUsePermission();
    }
    _locationSharingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationSharingKey, enabled);
    notifyListeners();
  }

  void startManualSos() => _startCountdown(EmergencyTrigger.manualSos);

  void _onProbableFall(MotionSample sample) {
    _activeSensorSummary = {
      'peakAcceleration': sample.accelerationMagnitude,
      'peakRotation': sample.rotationMagnitude,
    };
    _startCountdown(EmergencyTrigger.probableFall);
  }

  void _startCountdown(EmergencyTrigger trigger) {
    if (_contact == null || isAlertActive) return;
    _activeTrigger = trigger;
    if (trigger == EmergencyTrigger.manualSos) {
      _activeSensorSummary = null;
    }
    _alertState = EmergencyAlertState.countingDown;
    _secondsRemaining = countdownDuration;
    _activeLocation = null;
    if (_locationSharingEnabled) {
      unawaited(_captureLocation());
    }
    _announceWarning();
    unawaited(_record(EmergencyOutcome.detected));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsRemaining -= 1;
      if (_secondsRemaining <= 0) {
        unawaited(callNow());
      } else {
        unawaited(_pulse());
        notifyListeners();
      }
    });
    notifyListeners();
  }

  Future<void> callNow() async {
    final contact = _contact;
    if (contact == null || _alertState == EmergencyAlertState.calling) return;
    _timer?.cancel();
    _alertState = EmergencyAlertState.calling;
    notifyListeners();
    await _audioHaptics.stopSpeech();

    final opened = await _callBridge.call(contact.phoneNumber);
    await _record(
      opened ? EmergencyOutcome.callAttempted : EmergencyOutcome.callFailed,
    );
    _alertState = opened
        ? EmergencyAlertState.idle
        : EmergencyAlertState.callFailed;
    notifyListeners();
  }

  void cancelAlert() {
    if (_alertState == EmergencyAlertState.idle) return;
    _timer?.cancel();
    _timer = null;
    _alertState = EmergencyAlertState.idle;
    unawaited(_audioHaptics.stopSpeech());
    unawaited(_record(EmergencyOutcome.cancelled));
    notifyListeners();
  }

  void dismissError() {
    _alertState = EmergencyAlertState.idle;
    notifyListeners();
  }

  Future<void> _startMonitoring() {
    return _motionMonitoring.start(onFall: _onProbableFall);
  }

  Future<void> _announceWarning() async {
    final l10n = AppLocalizations(_settings.locale);
    await SystemSound.play(SystemSoundType.alert);
    await _audioHaptics.playHaptic(HapticSignal.danger);
    await _audioHaptics.speak(
      l10n.possibleFallWarning,
      languageCode: _settings.locale.languageCode,
      speechRate: _settings.speechRate,
    );
  }

  Future<void> _pulse() async {
    await SystemSound.play(SystemSoundType.alert);
    await _audioHaptics.playHaptic(HapticSignal.danger);
  }

  Future<void> _captureLocation() async {
    _activeLocation = await _locationService.tryCapture();
  }

  Future<void> _record(EmergencyOutcome outcome) async {
    final event = EmergencyEvent(
      trigger: _activeTrigger,
      outcome: outcome,
      occurredAt: DateTime.now(),
      sensorSummary: _activeSensorSummary,
      location: _activeLocation,
    );
    await _eventStore.append(event);
    unawaited(_syncService.flushEvents());
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_motionMonitoring.stop());
    super.dispose();
  }
}
