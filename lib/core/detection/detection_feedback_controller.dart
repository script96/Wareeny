import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:wareny/core/detection/detection_config.dart';
import 'package:wareny/core/detection/detection_pipeline.dart';
import 'package:wareny/core/detection/detection_result.dart';
import 'package:wareny/core/detection/target_labels.dart';
import 'package:wareny/core/tts/tts_service.dart';
import 'package:wareny/shared/bridges/audio_haptics_bridge.dart';

class DetectionFeedbackController {
  DetectionFeedbackController({
    required DetectionPipeline pipeline,
    required AudioHapticsBridge audioHapticsBridge,
    required TtsService ttsService,
    DetectionConfig? config,
    bool enableDiagnostics = false,
    DetectionClock? clock,
  }) : _pipeline = pipeline,
       _audioHapticsBridge = audioHapticsBridge,
       _ttsService = ttsService,
       _config = config ?? pipeline.config,
       _enableDiagnostics = enableDiagnostics,
       _clock = clock ?? DateTime.now;

  final DetectionPipeline _pipeline;
  final AudioHapticsBridge _audioHapticsBridge;
  final TtsService _ttsService;
  final DetectionConfig _config;
  final bool _enableDiagnostics;
  final DetectionClock _clock;

  Timer? _hapticTimer;
  Timer? _lostTargetTimer;
  Duration? _activeHapticInterval;
  String? _lastPhrase;
  DateTime? _lastSpokenAt;
  var _isActive = false;

  void start() {
    if (_isActive) {
      return;
    }
    _isActive = true;
    _pipeline.addListener(_handlePipelineUpdate);
    _handlePipelineUpdate();
  }

  void stop() {
    if (!_isActive) {
      return;
    }
    _isActive = false;
    _pipeline.removeListener(_handlePipelineUpdate);
    _stopFeedback(stopSpeech: true);
  }

  void dispose() {
    stop();
  }

  void _handlePipelineUpdate() {
    if (!_isActive) {
      return;
    }

    final target = _pipeline.currentTarget;
    _scheduleLostTargetStop();

    if (target == null) {
      return;
    }

    _maybeSpeak(target);
    _ensureHaptics(target.proximity);
  }

  void _maybeSpeak(DetectionResult target) {
    final phrase = _phraseFor(target);
    final now = _clock();
    final lastSpokenAt = _lastSpokenAt;

    if (_lastPhrase == phrase &&
        lastSpokenAt != null &&
        now.difference(lastSpokenAt) < _config.cooldownDuration) {
      return;
    }

    _lastPhrase = phrase;
    _lastSpokenAt = now;
    unawaited(_safeTtsCall(() => _ttsService.speak(phrase)));
  }

  void _ensureHaptics(ObjectProximity proximity) {
    final interval = _config.hapticIntervalFor(proximity);
    if (_activeHapticInterval == interval && _hapticTimer != null) {
      return;
    }

    _hapticTimer?.cancel();
    _activeHapticInterval = interval;
    unawaited(_playNavigationCue());
    _hapticTimer = Timer.periodic(
      interval,
      (_) => unawaited(_playNavigationCue()),
    );
  }

  void _scheduleLostTargetStop() {
    _lostTargetTimer?.cancel();
    _lostTargetTimer = Timer(_config.lostTargetDelay, () {
      _stopFeedback(stopSpeech: true);
    });
  }

  void _stopFeedback({required bool stopSpeech}) {
    _hapticTimer?.cancel();
    _hapticTimer = null;
    _lostTargetTimer?.cancel();
    _lostTargetTimer = null;
    _activeHapticInterval = null;
    _lastPhrase = null;
    _lastSpokenAt = null;

    if (stopSpeech) {
      unawaited(_safeTtsCall(_ttsService.stop));
    }
  }

  Future<void> _playNavigationCue() {
    return _safeCall(
      () => _audioHapticsBridge.playHaptic(HapticSignal.navigationCue),
    );
  }

  Future<void> _safeCall(Future<void> Function() call) async {
    try {
      await call();
    } on MissingPluginException catch (error) {
      if (_enableDiagnostics) {
        debugPrint('Audio/haptics bridge missing: ${error.message}');
      }
    } on PlatformException catch (error) {
      if (_enableDiagnostics) {
        debugPrint('Audio/haptics bridge failed: ${error.message}');
      }
    }
  }

  Future<void> _safeTtsCall(Future<void> Function() call) async {
    try {
      await call();
    } on MissingPluginException catch (error) {
      if (_enableDiagnostics) {
        debugPrint('flutter_tts plugin missing: ${error.message}');
      }
    } on PlatformException catch (error) {
      if (_enableDiagnostics) {
        debugPrint('flutter_tts failed: ${error.message}');
      }
    }
  }

  String _phraseFor(DetectionResult target) {
    final label = TargetLabels.displayNameFor(target.label);
    final direction = switch (target.direction) {
      ObjectDirection.left => 'on your left',
      ObjectDirection.center => 'centered',
      ObjectDirection.right => 'on your right',
    };
    final proximity = switch (target.proximity) {
      ObjectProximity.near => 'nearby',
      ObjectProximity.mid => 'in the middle distance',
      ObjectProximity.far => 'far away',
    };

    return '$label, $direction, $proximity';
  }
}
