import 'package:flutter/foundation.dart';

import 'package:wareeny/shared/danger/danger_detection_result.dart';

class DangerLabelMapper {
  const DangerLabelMapper({this.diagnosticsEnabled = false});

  final bool diagnosticsEnabled;

  DangerKind? classify(String label, {List<String> labels = const []}) {
    final mapped = _labelForClassIndex(label, labels);
    final value = _normalized(mapped);
    if (value.isEmpty || value == 'unknown') return null;

    if (_containsAny(value, const ['fire', 'flame', 'smoke'])) {
      return DangerKind.fire;
    }
    if (_containsAny(value, const ['stop', 'stop sign'])) {
      return DangerKind.stopSign;
    }
    if (_containsAny(value, const [
      'wet floor',
      'wet floor sign',
      'slippery floor',
      'slip',
      'caution wet',
    ])) {
      return DangerKind.wetFloorSign;
    }
    if (_containsAny(value, const [
      'exit',
      'exit sign',
      'emergency exit',
      'emergency exit indicator light',
    ])) {
      return DangerKind.exitSign;
    }

    _log('label mismatch raw="$label" normalized="$value" labels=$labels');
    return null;
  }

  String mappedLabelFor(String label, {List<String> labels = const []}) {
    return _labelForClassIndex(label, labels);
  }

  List<String> validateLabels(List<String> labels) {
    final missing = <DangerKind>{...DangerKind.values};
    for (final label in labels) {
      final kind = classify(label, labels: labels);
      if (kind != null) missing.remove(kind);
    }
    return missing.map((kind) => kind.debugLabel).toList(growable: false);
  }

  bool _containsAny(String value, List<String> aliases) {
    return aliases.any((alias) => value.contains(_normalized(alias)));
  }

  String _labelForClassIndex(String label, List<String> labels) {
    final normalized = _normalized(label);
    final match = RegExp(r'^(?:class\s*)?(\d+)$').firstMatch(normalized);
    if (match == null) return label;
    final index = int.tryParse(match.group(1)!);
    if (index == null || index < 0 || index >= labels.length) return label;
    return labels[index];
  }

  String _normalized(String label) {
    return label
        .toLowerCase()
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  void _log(String message) {
    if (diagnosticsEnabled) debugPrint('[DangerLabelMapper] $message');
  }
}
