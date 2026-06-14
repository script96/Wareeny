# Data Model

Wareeny has no remote database. All persistent state is stored locally on the device via `SharedPreferences` (a key/value store backed by Android `SharedPreferences` and iOS `NSUserDefaults`). The sections below document every key, type, and in-memory data structure used at runtime.

---

## Local Persistence — SharedPreferences

All keys are defined as constants in `lib/presentation/settings/settings_controller.dart`.

### Settings Keys

| Key | Type | Default | Description |
|---|---|---|---|
| `settings.locale` | `String` | `"en"` | BCP-47 language tag. Supported values: `"en"`, `"ar"`. |
| `settings.speechRate` | `double` | `0.45` | TTS speed. Clamped to `[0.1, 1.0]`. |
| `settings.hapticsEnabled` | `bool` | `true` | Enables or disables haptic vibration feedback. |
| `settings.emergencyContacts` | `String` | `""` | JSON-encoded array of `EmergencyContact` objects (see below). |
| `settings.emergencyOnboardingSeen` | `bool` | `false` | Set to `true` after the user completes first-launch onboarding. |

---

## Data Classes

### EmergencyContact

Defined in `lib/core/emergency/emergency_contact.dart`.

```dart
class EmergencyContact {
  final String name;   // Human-readable label, e.g. "Mom" or "أمي"
  final String phone;  // International format, e.g. "+201234567890"
}
```

**Serialization:**

```json
// Stored at settings.emergencyContacts as a JSON string
[
  { "name": "Mom", "phone": "+201234567890" },
  { "name": "Ahmed", "phone": "+201098765432" }
]
```

**Constraints:**
- No hard limit on count, but the UI encourages at least one.
- If the list is empty and an emergency is triggered, the fallback number `112` (international emergency) is dialled.
- `name` and `phone` are both required and non-nullable.

---

### ObjectDetection

Defined in `lib/shared/object_detection/detection_models.dart`. Ephemeral — never persisted.

```dart
class ObjectDetection {
  final String label;         // COCO class name, e.g. "person", "chair"
  final double confidence;    // 0.0 – 1.0
  final Rect boundingBox;     // Pixel coordinates: left, top, right, bottom
  final String? trackingId;   // Optional object tracker ID across frames
}
```

### ObjectDetectionFrame

Container emitted by the YOLO bridge on each camera frame.

```dart
class ObjectDetectionFrame {
  final int frameId;
  final Size sourceSize;                  // Camera resolution in pixels
  final List<ObjectDetection> detections;
  final DateTime timestamp;
  final Duration? inferenceTime;
  final double? framesPerSecond;
}
```

---

### NavigationPath

Defined in `lib/shared/navigation/navigation_models.dart`. Represents the trapezoidal "safe walking corridor" polygon in normalized (0–1) coordinates.

```dart
class NavigationPath {
  final double topY;          // default 0.48
  final double topLeft;       // default 0.46
  final double topRight;      // default 0.54
  final double bottomLeft;    // default 0.30
  final double bottomRight;   // default 0.70
  final double bottomDangerY; // default 0.78
}
```

### NavigationRisk (enum)

```dart
enum NavigationRisk { safe, caution, danger }
```

| Value | Trigger |
|---|---|
| `safe` | Object outside walking path or below confidence / size thresholds. |
| `caution` | Object overlaps path by > 8% of path area. |
| `danger` | Object center inside path, or large object (> 18% frame area) inside path, or object at bottom-danger zone. |

### NavigationZone (enum)

```dart
enum NavigationZone { left, center, right }
```

Derived from the horizontal position of the bounding box center.

### NavigationObjectRisk

Per-detection risk record produced by `NavigationRiskEngine`.

```dart
class NavigationObjectRisk {
  final UprightDetection detection;
  final NavigationRisk risk;
  final NavigationZone zone;
  final bool insidePath;
  final bool centerInsidePath;
  final double overlapRatio;    // Fraction of path area overlapped
  final bool isBottomDanger;    // Object in the bottom-danger strip
  final bool isIgnored;
  final String? ignoreReason;   // e.g. "low confidence", "tiny bounding box"
}
```

### NavigationAssessment

The final output of each risk engine cycle.

```dart
class NavigationAssessment {
  final List<NavigationObjectRisk> objects;  // All detections with classification
  final NavigationObjectRisk? selected;      // Highest-priority threat (null = path clear)

  NavigationRisk get highestRisk => selected?.risk ?? NavigationRisk.safe;
}
```

---

### VLM Types

All defined in `lib/shared/vlm/`.

#### VlmTask (enum)

```dart
enum VlmTask {
  scan,          // Quick one-line gist. Local-preferred. Powers SCAN sub-mode.
  read,          // Full faithful text reading. Local-preferred. Powers READ sub-mode.
  describeScene, // "What's in front of me." Cloud-preferred.
  inHand,        // Identify object the user is holding. Local-preferred.
  currency,      // Identify a banknote or coin. Local-preferred.
  brand,         // Identify a product brand. Local-preferred.
  askImage,      // One-shot spoken question about the frame. Cloud-preferred.
}
```

#### VlmSource (enum)

```dart
enum VlmSource {
  localDevice,   // On-device MediaPipe / Gemma
  cloud,         // Hosted FastAPI + Ollama
  unavailable,   // No model and no network
}
```

#### VlmRequest

```dart
class VlmRequest {
  final String imagePath;      // Local file path of the captured JPEG
  final VlmTask task;
  final String? userQuestion;  // Only set for VlmTask.askImage
}
```

#### VlmChunk

One streaming token batch from a provider.

```dart
class VlmChunk {
  final String textDelta;  // Newly generated text since the previous chunk
  final bool isFirst;      // True for the first chunk — triggers "stop thinking" cue
}
```

#### VlmResponse

Terminal summary after a stream completes.

```dart
class VlmResponse {
  final String spokenText;           // Full assembled answer
  final VlmSource source;            // Which tier answered
  final Duration latency;            // Wall-clock time from request to stream end
  final Duration? firstTokenLatency; // Time to first chunk, when measured
}
```

---

## Coordinate System

All object detection coordinates are normalized to `[0.0, 1.0]` before risk assessment. The mapping is handled by `DetectionCoordinateMapper` (`lib/shared/object_detection/detection_coordinate_mapper.dart`), which accounts for:

- Camera rotation (portrait vs landscape)
- Front/rear camera mirroring
- Center-crop offset when the preview aspect ratio differs from the sensor ratio

---

## In-Memory State Ownership

| State | Owner class | Scope |
|---|---|---|
| User preferences | `SettingsController` (ChangeNotifier) | App lifetime |
| Emergency contacts | `SettingsController` | App lifetime |
| Current `AppMode` | `NavigationShell` | App lifetime |
| YOLO detection frames | `NavigationController` / `StuffFinderController` | Mode lifetime |
| Navigation assessment | `NavigationController` | Mode lifetime |
| VLM speech queue | `SpeechQueue` | Screen lifetime |
| Active VLM stream | `VlmReadController` | Screen lifetime |
| Shake / countdown | `EmergencyController` | App lifetime |

---

## Planned Future Schema (not yet implemented)

The thesis design document (`docs/thesiss.tex`) describes a future Supabase integration for cloud backup. The tables below are **not implemented** — they exist only as a design reference.

| Table | Key columns | Purpose |
|---|---|---|
| `users` | `id`, `email`, `created_at` | User account |
| `scan_history` | `id`, `user_id`, `task`, `result_text`, `created_at` | VLM scan log |
| `detected_objects` | `id`, `scan_id`, `label`, `confidence` | Per-detection record |
