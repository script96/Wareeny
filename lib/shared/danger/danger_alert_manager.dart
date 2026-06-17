import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/bridges/audio_haptics_bridge.dart';
import 'package:wareeny/shared/danger/danger_config.dart';
import 'package:wareeny/shared/danger/danger_detection_result.dart';

typedef DangerClock = DateTime Function();
typedef DangerVoiceInputAction = Future<void> Function();

abstract interface class DangerAlertFeedback {
  Future<void> stopNormalSpeechAndInput();

  Future<void> resumeNormalInput();

  Future<void> speakCritical(String message);

  Future<void> speakStatusOnce(String message);

  Future<void> playDangerHaptic();
}

class BridgeDangerAlertFeedback implements DangerAlertFeedback {
  const BridgeDangerAlertFeedback(
    this._bridge, {
    this.stopVoiceInput,
    this.resumeVoiceInput,
  });

  final AudioHapticsBridge _bridge;
  final DangerVoiceInputAction? stopVoiceInput;
  final DangerVoiceInputAction? resumeVoiceInput;

  @override
  Future<void> stopNormalSpeechAndInput() async {
    await _bridge.stopSpeech();
    await stopVoiceInput?.call();
  }

  @override
  Future<void> resumeNormalInput() async {
    await resumeVoiceInput?.call();
  }

  @override
  Future<void> speakCritical(String message) {
    return _bridge.speak(
      message,
      interrupt: true,
      languageCode: 'ar-EG',
      speechRate: 0.52,
      priority: TtsPriority.critical,
    );
  }

  @override
  Future<void> speakStatusOnce(String message) {
    return _bridge.speak(
      message,
      interrupt: false,
      languageCode: 'ar-EG',
      speechRate: 0.48,
      priority: TtsPriority.normal,
    );
  }

  @override
  Future<void> playDangerHaptic() {
    return _bridge.playHaptic(HapticSignal.danger);
  }
}

class DangerAlertManager extends ChangeNotifier {
  DangerAlertManager({
    required this.feedback,
    DangerClock? clock,
    this.fireClearTimeout = DangerModeConfig.fireClearTimeout,
    this.diagnosticsEnabled = false,
  }) : _clock = clock ?? DateTime.now;

  final DangerAlertFeedback feedback;
  final DangerClock _clock;
  final Duration fireClearTimeout;
  final bool diagnosticsEnabled;

  final Map<DangerKind, DateTime> _lastSpokenAt = {};
  DateTime? _lastFireSeenAt;
  bool _fallbackSpoken = false;

  String status = 'No danger alerts yet';
  DangerDetectionResult? latestAlert;
  bool lastAlertSpoken = false;
  bool panicMode = false;

  AlertCooldownState cooldownStateFor(DangerDetectionResult detection) {
    final now = _clock();
    final lastSame = _lastSpokenAt[detection.kind];
    if (lastSame == null) return const AlertCooldownState.clear();
    final elapsed = now.difference(lastSame);
    if (elapsed >= detection.kind.cooldown) {
      return const AlertCooldownState.clear();
    }
    return AlertCooldownState.blocked(detection.kind.cooldown - elapsed);
  }

  DangerDetectionResult? chooseAlert(List<DangerDetectionResult> detections) {
    final candidates = detections
        .where((item) => item.isAlertCandidate)
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    final fire =
        candidates
            .where((item) => item.kind == DangerKind.fire)
            .toList(growable: false)
          ..sort(_highestFirePriorityFirst);
    if (fire.isNotEmpty) return fire.first;

    final warning =
        candidates
            .where(
              (item) =>
                  item.kind == DangerKind.stopSign ||
                  item.kind == DangerKind.wetFloorSign,
            )
            .toList(growable: false)
          ..sort((a, b) => b.confidence.compareTo(a.confidence));
    if (warning.isNotEmpty) return warning.first;

    final exit =
        candidates
            .where((item) => item.kind == DangerKind.exitSign)
            .toList(growable: false)
          ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return exit.isEmpty ? null : exit.first;
  }

  Future<bool> handleFrame(List<DangerDetectionResult> detections) async {
    _updateFireState(detections);
    final selected = chooseAlert(detections);
    if (selected == null) {
      status = panicMode
          ? 'Panic mode active; waiting for fire clear'
          : 'No danger alert candidate';
      lastAlertSpoken = false;
      notifyListeners();
      return false;
    }
    return trigger(selected);
  }

  Future<bool> trigger(DangerDetectionResult detection) async {
    final cooldown = cooldownStateFor(detection);
    if (cooldown.blocked) {
      status =
          'Cooldown blocked ${detection.kind.debugLabel}; ${cooldown.remaining!.inMilliseconds} ms left';
      latestAlert = detection;
      lastAlertSpoken = false;
      _log(
        'cooldown blocked kind=${detection.kind.name} confidence=${detection.confidence.toStringAsFixed(2)} remainingMs=${cooldown.remaining!.inMilliseconds}',
      );
      notifyListeners();
      return false;
    }

    _lastSpokenAt[detection.kind] = _clock();
    latestAlert = detection;
    lastAlertSpoken = true;
    if (detection.kind == DangerKind.fire &&
        detection.fireSeverity == FireSeverity.panic) {
      panicMode = true;
    }
    status =
        'Spoke ${detection.kind.debugLabel} ${(detection.confidence * 100).toStringAsFixed(0)}% severity=${detection.fireSeverity.debugLabel}';
    notifyListeners();

    _log(
      'alert kind=${detection.kind.name} label=${detection.rawLabel} '
      'confidence=${detection.confidence.toStringAsFixed(2)} '
      'area=${detection.frameArea.toStringAsFixed(3)} '
      'severity=${detection.fireSeverity.name} panic=$panicMode',
    );
    try {
      await feedback.stopNormalSpeechAndInput();
      final haptic = _playAlertHaptics(detection.kind);
      await feedback.speakCritical(detection.warning);
      await haptic;
      if (!panicMode) {
        await feedback.resumeNormalInput();
      }
    } catch (error) {
      status = 'Danger alert failed: $error';
      _log(status);
      notifyListeners();
    }
    return true;
  }

  Future<void> speakModelUnavailableOnce(String reason) async {
    if (_fallbackSpoken) return;
    _fallbackSpoken = true;
    status = 'Danger model unavailable: $reason';
    _log(status);
    notifyListeners();
    try {
      await feedback.speakStatusOnce(
        'تنبيه، نظام كشف الخطر غير متاح حالياً، التنقل شغال.',
      );
    } catch (error) {
      _log('fallback speech failed: $error');
    }
  }

  void _updateFireState(List<DangerDetectionResult> detections) {
    final now = _clock();
    final fireSeen = detections.any(
      (item) => item.kind == DangerKind.fire && !item.isIgnored,
    );
    if (fireSeen) {
      _lastFireSeenAt = now;
      return;
    }

    final lastFireSeenAt = _lastFireSeenAt;
    if (panicMode &&
        lastFireSeenAt != null &&
        now.difference(lastFireSeenAt) >= fireClearTimeout) {
      panicMode = false;
      status = 'Fire clear timeout elapsed; panic mode ended';
      _log(status);
    }
  }

  int _highestFirePriorityFirst(
    DangerDetectionResult a,
    DangerDetectionResult b,
  ) {
    final severity = b.fireSeverity.index.compareTo(a.fireSeverity.index);
    if (severity != 0) return severity;
    final area = b.frameArea.compareTo(a.frameArea);
    if (area != 0) return area;
    return b.confidence.compareTo(a.confidence);
  }

  Future<void> _playAlertHaptics(DangerKind kind) async {
    for (var i = 0; i < kind.hapticPulses; i++) {
      await feedback.playDangerHaptic();
      if (i < kind.hapticPulses - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
  }

  void _log(String message) {
    if (diagnosticsEnabled) debugPrint('[DangerAlert] $message');
  }
}

class AlertCooldownState {
  const AlertCooldownState.clear() : blocked = false, remaining = null;

  const AlertCooldownState.blocked(this.remaining) : blocked = true;

  final bool blocked;
  final Duration? remaining;
}
