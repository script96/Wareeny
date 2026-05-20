import 'package:flutter/services.dart';

import 'indoor_navigation_types.dart';

class HapticCueService {
  DateTime _lastPulse = DateTime.fromMillisecondsSinceEpoch(0);
  DangerLevel? _lastLevel;

  Future<void> emit(DangerLevel level) async {
    final now = DateTime.now();
    final minGap = switch (level) {
      DangerLevel.safe => const Duration(milliseconds: 1400),
      DangerLevel.caution => const Duration(milliseconds: 900),
      DangerLevel.danger => const Duration(milliseconds: 650),
      DangerLevel.stop => const Duration(milliseconds: 450),
    };

    if (_lastLevel == level && now.difference(_lastPulse) < minGap) {
      return;
    }

    _lastPulse = now;
    _lastLevel = level;

    switch (level) {
      case DangerLevel.safe:
        await HapticFeedback.selectionClick();
        break;
      case DangerLevel.caution:
        await HapticFeedback.lightImpact();
        break;
      case DangerLevel.danger:
        await HapticFeedback.mediumImpact();
        break;
      case DangerLevel.stop:
        await HapticFeedback.heavyImpact();
        break;
    }
  }
}
