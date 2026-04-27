// Warene — Mode, Object Finder types, and target registry
//
// Centralizes all mode/finder-specific enums, data classes, and the
// preset target registry so they can be tested without pulling
// in service dependencies.

import '../detector.dart';

// ── App Mode ─────────────────────────────────────────────────────────

/// The single active mode for the entire app.
/// All behaviour in VisionService is driven by this enum.
enum WareneMode {
  generalObjects,
  currency,
  objectFinderFast,
  objectFinderSmart,
  color,
}

// ── Object Finder Enums ──────────────────────────────────────────────

enum ObjectFinderMode {
  fastYolo,
  smartVision,
}

/// Status of the Object Finder within its mode.
///
/// - `inactive` — finder is not running (app is in another mode).
/// - `searching` — target not currently visible.
/// - `tracking` — target currently visible and being tracked.
/// - `error` — something went wrong (camera/API/timeout).
enum ObjectFinderStatus {
  inactive,
  searching,
  tracking,
  error,
}

// ── Data classes ─────────────────────────────────────────────────────

class ObjectFinderTarget {
  final String label;
  final String arabicName;
  final ObjectFinderMode mode;

  const ObjectFinderTarget({
    required this.label,
    required this.arabicName,
    required this.mode,
  });

  @override
  String toString() => 'ObjectFinderTarget($label / $arabicName, ${mode.name})';
}

class ObjectFinderState {
  final ObjectFinderStatus status;
  final ObjectFinderMode? mode;
  final String? targetLabel;
  final String? targetArabicName;
  final Detection? foundDetection;
  final String statusText;

  const ObjectFinderState({
    required this.status,
    this.mode,
    this.targetLabel,
    this.targetArabicName,
    this.foundDetection,
    this.statusText = '',
  });

  /// Convenience factory for the resting state.
  const ObjectFinderState.inactive()
      : status = ObjectFinderStatus.inactive,
        mode = null,
        targetLabel = null,
        targetArabicName = null,
        foundDetection = null,
        statusText = '';
}

class SmartFindResult {
  final bool found;
  final String direction;
  final String distance;
  final String spokenText;
  final bool isError;

  const SmartFindResult({
    required this.found,
    this.direction = 'unknown',
    this.distance = 'unknown',
    this.spokenText = '',
    this.isError = false,
  });

  /// Parse a JSON map returned by the AI. Returns a safe default
  /// (`found: false`) when the map is malformed.
  factory SmartFindResult.fromJson(Map<String, dynamic> json) {
    try {
      return SmartFindResult(
        found: json['found'] == true,
        direction: json['direction'] as String? ?? 'unknown',
        distance: json['distance'] as String? ?? 'unknown',
        spokenText: json['arabic_response'] as String? ?? '',
      );
    } catch (_) {
      return const SmartFindResult(found: false);
    }
  }

  /// Convenience factory for error states.
  const SmartFindResult.error(String message)
      : found = false,
        direction = 'unknown',
        distance = 'unknown',
        spokenText = message,
        isError = true;
}

// ── Target Registry ──────────────────────────────────────────────────

class ObjectFinderRegistry {
  ObjectFinderRegistry._(); // prevent instantiation

  /// COCO labels that the general YOLO model can detect.
  /// Keys must match `Detection.label` exactly.
  static const Map<String, String> fastTargets = {
    'apple': 'تفاحة',
    'banana': 'موزة',
    'bottle': 'زجاجة',
    'cup': 'كوب',
    'chair': 'كرسي',
    'book': 'كتاب',
    'cell phone': 'هاتف',
    'laptop': 'لابتوب',
    'backpack': 'شنطة',
    'person': 'شخص',
  };

  /// Objects that YOLO cannot detect — handled via Smart Finder.
  static const Map<String, String> smartTargets = {
    'keys': 'مفاتيح',
    'wallet': 'محفظة',
    'glasses': 'نظارة',
    'charger': 'شاحن',
    'medicine': 'دواء',
    'id card': 'بطاقة',
    'remote control': 'ريموت',
  };

  /// All COCO labels the general model knows (from `YoloDetector.arabicNames`).
  static final Set<String> _cocoLabels =
      YoloDetector.arabicNames.keys.toSet();

  /// Resolve a label to the appropriate finder target.
  ///
  /// If the label matches any COCO label the general model can detect,
  /// returns a Fast target. Otherwise returns a Smart target.
  static ObjectFinderTarget resolve(String label) {
    final lower = label.toLowerCase().trim();

    // Check fast presets first (exact match against registry)
    if (fastTargets.containsKey(lower)) {
      return ObjectFinderTarget(
        label: lower,
        arabicName: fastTargets[lower]!,
        mode: ObjectFinderMode.fastYolo,
      );
    }

    // Check smart presets
    if (smartTargets.containsKey(lower)) {
      return ObjectFinderTarget(
        label: lower,
        arabicName: smartTargets[lower]!,
        mode: ObjectFinderMode.smartVision,
      );
    }

    // Check full COCO label set (covers items like 'remote', 'mouse' etc.)
    if (_cocoLabels.contains(lower)) {
      final arabic = YoloDetector.arabicNames[lower] ?? lower;
      return ObjectFinderTarget(
        label: lower,
        arabicName: arabic,
        mode: ObjectFinderMode.fastYolo,
      );
    }

    // Fallback: Smart Finder for any unknown object
    return ObjectFinderTarget(
      label: lower,
      arabicName: lower,
      mode: ObjectFinderMode.smartVision,
    );
  }

  /// Create a Smart Finder target from custom user text.
  /// Always uses Smart mode regardless of label.
  static ObjectFinderTarget fromCustomText(String text) {
    final trimmed = text.trim();
    return ObjectFinderTarget(
      label: trimmed,
      arabicName: trimmed,
      mode: ObjectFinderMode.smartVision,
    );
  }
}
