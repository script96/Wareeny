import 'package:wareeny/features/indoor_navigation/indoor_navigation_phrases.dart';
import 'package:wareeny/shared/bridges/indoor_navigation_bridge.dart';

class IndoorSpeechCommand {
  const IndoorSpeechCommand({required this.text, required this.interrupt});

  final String text;
  final bool interrupt;
}

class IndoorNavigationFeedbackController {
  IndoorNavigationFeedbackController({DateTime? now}) : _lastStateAt = now;

  static const dangerThreshold = 0.62;
  static const cueThreshold = 0.58;
  static const clearThreshold = 0.7;

  IndoorPathCode? _candidateCode;
  var _candidateCount = 0;
  IndoorPathCode? _lastSpokenCode;
  IndoorPathCode? _lastStableCode;
  DateTime? _lastSpokenAt;
  DateTime? _lastStateAt;

  IndoorSpeechCommand? handle(IndoorPathState state, DateTime now) {
    if (!_passesConfidence(state)) {
      _resetCandidate();
      return null;
    }

    if (_isFlickeringDirection(state.code)) {
      _resetCandidate();
      return null;
    }

    if (_candidateCode == state.code) {
      _candidateCount += 1;
    } else {
      _candidateCode = state.code;
      _candidateCount = 1;
    }
    _lastStateAt = now;

    if (_candidateCount < _requiredSamples(state)) {
      return null;
    }

    final wasWarningOrDanger =
        _lastStableCode != null && _lastStableCode != IndoorPathCode.clearPath;
    _lastStableCode = state.code;

    if (state.code == IndoorPathCode.clearPath && !wasWarningOrDanger) {
      return null;
    }

    if (_isOnCooldown(state, now)) {
      return null;
    }

    _lastSpokenCode = state.code;
    _lastSpokenAt = now;

    return IndoorSpeechCommand(
      text: IndoorNavigationPhrases.forCode(state.code),
      interrupt: state.severity == IndoorPathSeverity.danger,
    );
  }

  void reset() {
    _resetCandidate();
    _lastSpokenCode = null;
    _lastStableCode = null;
    _lastSpokenAt = null;
    _lastStateAt = null;
  }

  bool _passesConfidence(IndoorPathState state) {
    return switch (state.severity) {
      IndoorPathSeverity.danger => state.score >= dangerThreshold,
      IndoorPathSeverity.obstacle => state.score >= cueThreshold,
      IndoorPathSeverity.navigationCue => state.score >= cueThreshold,
      IndoorPathSeverity.clear => state.score >= clearThreshold,
      IndoorPathSeverity.uncertain => state.score >= cueThreshold,
    };
  }

  int _requiredSamples(IndoorPathState state) {
    return switch (state.severity) {
      IndoorPathSeverity.danger => 2,
      IndoorPathSeverity.obstacle => 3,
      IndoorPathSeverity.navigationCue => 3,
      IndoorPathSeverity.clear => 5,
      IndoorPathSeverity.uncertain => 3,
    };
  }

  bool _isOnCooldown(IndoorPathState state, DateTime now) {
    if (_lastSpokenAt == null || _lastSpokenCode != state.code) {
      return false;
    }

    final elapsed = now.difference(_lastSpokenAt!);
    final cooldown = switch (state.severity) {
      IndoorPathSeverity.danger => const Duration(seconds: 2),
      IndoorPathSeverity.obstacle => const Duration(seconds: 4),
      IndoorPathSeverity.navigationCue => const Duration(seconds: 5),
      IndoorPathSeverity.clear => const Duration(seconds: 12),
      IndoorPathSeverity.uncertain => const Duration(seconds: 8),
    };

    return elapsed < cooldown;
  }

  bool _isFlickeringDirection(IndoorPathCode code) {
    final previous = _candidateCode;
    if (previous == null || _lastStateAt == null) {
      return false;
    }

    final opposingDirections =
        (previous == IndoorPathCode.moveLeft &&
            code == IndoorPathCode.moveRight) ||
        (previous == IndoorPathCode.moveRight &&
            code == IndoorPathCode.moveLeft) ||
        (previous == IndoorPathCode.forwardThenSlightLeft &&
            code == IndoorPathCode.forwardThenSlightRight) ||
        (previous == IndoorPathCode.forwardThenSlightRight &&
            code == IndoorPathCode.forwardThenSlightLeft);

    return opposingDirections && _candidateCount < 2;
  }

  void _resetCandidate() {
    _candidateCode = null;
    _candidateCount = 0;
  }
}
