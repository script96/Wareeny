import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wareeny/core/emergency/emergency_contact.dart';
import 'package:wareeny/core/emergency/location_service.dart';
import 'package:wareeny/core/emergency/shake_detector_service.dart';
import 'package:wareeny/presentation/settings/settings_controller.dart';
import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/bridges/native_bridge_channels.dart';

/// Fallback number dialed when no contacts have been saved.
const _fallbackEmergencyNumber = '112';

/// Fixed speech rate for emergency countdown — slightly faster than normal
/// to sound crisp and clear without being robotic.
const _countdownSpeechRate = 0.6;

/// Manages the full emergency flow:
///
/// 1. Listens to [ShakeDetectorService.onShake].
/// 2. Plays a 5-second audio countdown (via [AudioHapticsBridge]).
/// 3. If not cancelled: auto-dials first contact (or 112), sends SMS silently,
///    then opens WhatsApp with pre-filled message.
///
/// Call [arm] to start listening, [disarm] to stop.
/// [onCountdownStarted] → show overlay
/// [onCountdownCancelled] → dismiss overlay
/// [onEmergencyTriggered] → dismiss overlay (call in progress)
class EmergencyController {
  EmergencyController({
    required this.settings,
    required this.shakeDetector,
    required this.locationService,
    required this.audioHaptics,
  }) : _smsChannel = const MethodChannel(NativeBridgeChannels.emergency);

  final SettingsController settings;
  final ShakeDetectorService shakeDetector;
  final LocationService locationService;
  final AudioHapticsBridge audioHaptics;
  final MethodChannel _smsChannel;

  // ── Callbacks set by the UI layer ────────────────────────────────────────────
  VoidCallback? onCountdownStarted;
  VoidCallback? onCountdownCancelled;
  VoidCallback? onEmergencyTriggered;

  // ── State ────────────────────────────────────────────────────────────────────
  StreamSubscription<void>? _shakeSub;
  Timer? _countdownTimer;
  int _secondsLeft = 5;
  bool _countdownActive = false;

  bool get isCountdownActive => _countdownActive;
  int get secondsLeft => _secondsLeft;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  void arm() {
    shakeDetector.start();
    _shakeSub ??= shakeDetector.onShake.listen((_) => _onShake());
    debugPrint('[EmergencyController] Armed.');
  }

  void disarm() {
    _shakeSub?.cancel();
    _shakeSub = null;
    shakeDetector.stop();
    _cancelCountdown(silent: true);
    debugPrint('[EmergencyController] Disarmed.');
  }

  // ── Trigger ───────────────────────────────────────────────────────────────────

  void _onShake() {
    if (_countdownActive) return;
    _startCountdown();
  }

  void _startCountdown() {
    _countdownActive = true;
    _secondsLeft = 5;
    onCountdownStarted?.call();

    // Speak first count immediately and clearly.
    _speakCountdown(_secondsLeft);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _secondsLeft--;
      if (_secondsLeft > 0) {
        _speakCountdown(_secondsLeft);
      } else {
        timer.cancel();
        _countdownActive = false;
        _triggerEmergency();
      }
    });
  }

  /// Speaks each countdown number clearly at a fixed, crisp speech rate.
  void _speakCountdown(int seconds) {
    final isAr = settings.isArabic;
    // Use short, punchy text — fewer syllables = less muffling.
    final text = isAr ? '$seconds' : '$seconds';
    audioHaptics.speak(
      text,
      interrupt: true,
      languageCode: settings.locale.languageCode,
      speechRate: _countdownSpeechRate,
    );
    debugPrint('[EmergencyController] Countdown: $seconds');
  }

  // ── Cancel ────────────────────────────────────────────────────────────────────

  void cancelCountdown() {
    if (!_countdownActive) return;
    _cancelCountdown(silent: false);
  }

  void _cancelCountdown({required bool silent}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdownActive = false;
    _secondsLeft = 5;
    shakeDetector.resetCooldown();
    if (!silent) {
      onCountdownCancelled?.call();
      final isAr = settings.isArabic;
      audioHaptics.speak(
        isAr ? 'تم الإلغاء' : 'Cancelled',
        interrupt: true,
        languageCode: settings.locale.languageCode,
        speechRate: _countdownSpeechRate,
      );
    }
  }

  // ── Emergency dispatch ────────────────────────────────────────────────────────

  Future<void> _triggerEmergency() async {
    debugPrint('[EmergencyController] Triggering emergency!');
    onEmergencyTriggered?.call();

    final isAr = settings.isArabic;
    audioHaptics.speak(
      isAr ? 'جارٍ الاتصال' : 'Calling',
      interrupt: true,
      languageCode: settings.locale.languageCode,
      speechRate: _countdownSpeechRate,
    );

    final contacts = settings.emergencyContacts;
    final dialNumber =
        contacts.isNotEmpty ? contacts.first.phone : _fallbackEmergencyNumber;

    // Fetch GPS + auto-dial simultaneously for speed.
    final locationFuture = locationService.getCurrentPosition();
    await _autoCall(dialNumber);

    final position = await locationFuture;
    final mapsLink =
        position != null ? locationService.toGoogleMapsLink(position) : null;

    // Send SMS silently (Android: SmsManager; iOS: falls back to sms: URI).
    for (final contact in contacts) {
      await _sendSmsAuto(contact, mapsLink);
    }

    // Open WhatsApp for each contact with pre-filled message.
    // (WhatsApp has no silent-send API — the app will open and the message
    // is pre-filled; the user taps Send once inside WhatsApp.)
    for (final contact in contacts) {
      await _openWhatsApp(contact, mapsLink);
    }
  }

  // ── Call ──────────────────────────────────────────────────────────────────────

  /// Dials [number] automatically using ACTION_CALL (no dialer UI).
  /// Requires CALL_PHONE permission.
  Future<void> _autoCall(String number) async {
    debugPrint('[EmergencyController] Auto-dialing $number');
    try {
      // Request CALL_PHONE permission if not yet granted.
      final status = await Permission.phone.request();
      if (status.isGranted) {
        await FlutterPhoneDirectCaller.callNumber(number);
      } else {
        // Fallback: open dialer pre-filled (user taps call).
        debugPrint('[EmergencyController] CALL_PHONE denied — fallback to tel:');
        final uri = Uri(scheme: 'tel', path: number);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[EmergencyController] Call error: $e');
      // Last-resort fallback.
      final uri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  // ── SMS ───────────────────────────────────────────────────────────────────────

  /// Sends an SMS directly via the native SmsManager on Android (no UI).
  /// On iOS, falls back to opening the SMS composer (OS limitation).
  Future<void> _sendSmsAuto(EmergencyContact contact, String? mapsLink) async {
    final isAr = settings.isArabic;
    final body = isAr
        ? 'طوارئ: أحتاج مساعدة!${mapsLink != null ? '\nموقعي: $mapsLink' : ''}'
        : 'EMERGENCY: I need help!${mapsLink != null ? '\nMy location: $mapsLink' : ''}';

    debugPrint('[EmergencyController] Sending SMS to ${contact.name}');

    // Try native silent send first (Android only).
    try {
      await _smsChannel.invokeMethod<bool>('sms.send', {
        'phone': contact.phone,
        'body': body,
      });
      debugPrint('[EmergencyController] SMS sent natively to ${contact.name}');
      return;
    } on MissingPluginException {
      // iOS or channel not wired up — fall through to sms: URI.
      debugPrint('[EmergencyController] Native SMS unavailable — using sms: URI');
    } catch (e) {
      debugPrint('[EmergencyController] Native SMS error: $e — using sms: URI');
    }

    // iOS fallback: open SMS composer pre-filled.
    final uri = Uri(
      scheme: 'sms',
      path: contact.phone,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── WhatsApp ──────────────────────────────────────────────────────────────────

  /// Opens WhatsApp with a pre-filled message.
  /// NOTE: Silent sending via WhatsApp is not possible without the
  /// WhatsApp Business API — this is an OS/WhatsApp limitation.
  Future<void> _openWhatsApp(EmergencyContact contact, String? mapsLink) async {
    final isAr = settings.isArabic;
    final message = isAr
        ? 'طوارئ: أحتاج مساعدة!${mapsLink != null ? ' موقعي: $mapsLink' : ''}'
        : 'EMERGENCY: I need help!${mapsLink != null ? ' My location: $mapsLink' : ''}';

    final phone = contact.phone.replaceAll('+', '').replaceAll(' ', '');
    final uri = Uri.parse(
      'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );
    debugPrint('[EmergencyController] Opening WhatsApp for ${contact.name}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[EmergencyController] WhatsApp error: $e');
    }
  }
}
