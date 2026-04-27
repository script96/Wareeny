# Wareeny — Architecture

---

## System Overview

Wareeny is a client-only Flutter app. No backend server. Processing split between:
- **On-device**: Object detection (YOLOv8 TFLite), OCR (ML Kit + Tesseract), color analysis
- **Cloud**: Scene description and smart object search (Groq LLaMA Vision API)

```
┌──────────────────────────────────────────────────────┐
│                     Flutter App                       │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │              VisionService (Orchestrator)        │  │
│  │  mode state · timer loops · stream controllers  │  │
│  └──────┬───────────────────────────────┬──────────┘  │
│         │                               │              │
│   ┌─────▼──────┐   ┌────────────┐  ┌───▼──────────┐  │
│   │ YoloDetect │   │GroqVision  │  │ OCRService   │  │
│   │ (on-device)│   │(cloud API) │  │(on-device)   │  │
│   └─────┬──────┘   └─────┬──────┘  └───┬──────────┘  │
│         │                │              │              │
│   ┌─────▼──────┐   ┌─────▼──────┐  ┌───▼──────────┐  │
│   │CameraService│  │SpeechService│  │ColorService  │  │
│   └────────────┘   └────────────┘  └──────────────┘  │
└──────────────────────────────────────────────────────┘
                            │
                     ┌──────▼──────┐
                     │  Groq API   │
                     │(LLaMA 4 Scou│
                     └─────────────┘
```

---

## VisionService — State Machine

`lib/services/vision_service.dart` is the central orchestrator. Everything flows through it.

### Modes

| Mode | Interval | Engine | Output |
|------|----------|--------|--------|
| `generalObjects` | 1500ms | YOLOv8 general | Top 3 objects + direction + distance |
| `currency` | 1500ms | YOLOv8 currency | Denomination + count |
| `objectFinderFast` | 2000ms | YOLOv8 general | Direction/distance to target |
| `objectFinderSmart` | 3000ms | Groq Vision | Direction/distance via LMM |
| `color` | 2000ms | ColorService | Dominant color name in Arabic |

### One-Shot Actions (not modes)

- `describeScene()` — pause current mode → Groq scene description → resume
- `readText(language)` — pause current mode → OCR → TTS → resume

### State Streams

| Stream | Type | Purpose |
|--------|------|---------|
| `modeStream` | `WareneMode` | Current active mode |
| `statusStream` | `String` | Arabic status text for UI |
| `detectionStream` | `DetectionResult` | Latest YOLO detection results |
| `finderStateStream` | `ObjectFinderState` | Object Finder status + best match |

### Mode Transition

```
User triggers change
    → VisionService.switchMode(newMode)
        → Cancel active timer
        → Reset finder state
        → Optionally speak mode name
        → Start new mode's timer loop
```

---

## Detection Pipeline

```
Camera (720×1280 portrait JPEG)
    → Center-crop to 720×720 square     [detector.dart]
    → flutter_vision yoloOnImage()      [TFLite native]
    → Map bbox coords: cropped → original [detector.dart]
    → Filter tiny boxes (noise)
    → Attach Arabic labels
    → Return List<Detection>
    → VisionService routes by mode
    → SpeechService announces in Arabic
```

**Why center-crop:** YOLOv8 expects square input. Cropping instead of squishing preserves object proportions, improving accuracy significantly.

**Why JPEG snapshots:** `flutter_vision`'s frame-based API (`yoloOnFrame()`) has a YUV stride padding bug that corrupts inference on many Android devices. The app uses `takePicture()` JPEG instead.

---

## Modules

### YoloDetector
`lib/detector.dart`

Wraps `flutter_vision`. Manages two model instances (`DetectionModel.general`, `DetectionModel.currency`). Handles model loading, JPEG preprocessing, coordinate mapping, and label translation.

**Models:**
- `yolov8n.tflite` — 43 MB, 80 COCO classes, confidence threshold 0.25
- `currency_yolov8n.tflite` — 6 MB, 14 EGP denominations, confidence threshold 0.15 (lower to catch partial notes)

### GeminiService (Groq Client)
`lib/gemini_service.dart`

Despite the name, uses Groq API (`api.groq.com`), model `meta-llama/llama-4-scout-17b-16e-instruct`.

- `describeScene(image, style)` → Arabic scene summary
- `findObjectInScene(image, target)` → `SmartFindResult` with direction/distance

Handles 429 (rate limit), 401/400 (auth), and network timeouts gracefully with Arabic TTS fallbacks.

### OCRService
`lib/ocr_service.dart`

- `OCRLanguage.english` → Google ML Kit `TextRecognizer`
- `OCRLanguage.arabic` → Tesseract 5 with `ara.traineddata`

No auto-language detection. User switches via swipe-left gesture.

### CameraService
`lib/services/camera_service.dart`

Singleton. Manages `CameraController` lifecycle. `takeSnapshot()` returns JPEG bytes. Guards against double-init.

### SpeechService
`lib/services/speech_service.dart`

Singleton wrapping `flutter_tts`. Default locale `ar-EG`, speed 0.5×.

`speak(text, force: false, throttle: true)`:
- `force: true` interrupts current speech
- `throttle: true` skips if same text spoken within 3 seconds

### ColorService
`lib/services/color_service.dart`

Samples 5×5 pixel grid from image center. RGB → HSL → nearest Arabic color name. 12 color buckets: أسود، أبيض، رمادي، أحمر، برتقالي، أصفر، أخضر، سماوي، أزرق، بنفسجي، وردي، بني.

### ObjectFinderRegistry
`lib/services/object_finder_types.dart`

Hardcoded target registry:
- **Fast targets** (10): apple, banana, bottle, cup, chair, book, phone, laptop, backpack, person — all YOLO-detectable
- **Smart targets** (7): keys, wallet, glasses, charger, medicine, id card, remote — requires Groq vision
- **COCO fallback**: any of the 80 COCO label names resolves to fast mode
- **Unknown fallback**: anything else goes to smart mode

---

## UI Layer

### CameraScreen
`lib/ui/screens/camera_screen.dart`

Three independent render layers (no cascade repaints):
1. Camera preview (always live)
2. `BoundingBoxPainter` overlay (hidden during color/smart finder modes)
3. Status UI: mode badge, status text, gesture hint bar

**Gesture map:**

| Gesture | Action |
|---------|--------|
| Double-tap | Describe scene (one-shot) |
| Triple-tap | Toggle color mode on/off |
| Swipe right | Toggle currency ↔ general objects |
| Swipe left | Toggle OCR language EN ↔ AR |
| Long-press | Open action menu |

### ActionMenu
`lib/ui/widgets/action_menu.dart`

Bottom sheet. Shows all 6 actions, hides the currently active mode. RTL layout. Speaks action name in Arabic on selection.

Actions: general objects, currency, find object, color mode, read text, describe scene.

### BoundingBoxPainter
`lib/ui/widgets/bounding_box_painter.dart`

Maps detection bbox from original image coordinates to display coordinates. Green outline = normal, amber = highlighted (Object Finder target found). 8 rotating colors for multi-object distinction.

---

## Data Structures

```dart
class Detection {
  String label;          // COCO English label ("person", "car", ...)
  String arabicLabel;    // Translated Arabic ("شخص", "سيارة", ...)
  double confidence;     // 0.0–1.0
  List<double> bbox;     // [x1, y1, x2, y2] in original image coordinates
}

class DetectionResult {
  List<Detection> detections;
  int imageWidth;
  int imageHeight;
}

class ObjectFinderState {
  ObjectFinderStatus status;   // inactive / searching / tracking / error
  Detection? bestMatch;        // Closest detection matching target label
  String statusText;           // Arabic status for TTS + UI display
  bool shouldHighlight;        // Highlight bestMatch bbox in amber
}

class SmartFindResult {
  bool found;
  String direction;    // "left" / "center" / "right"
  String distance;     // "very_close" / "close" / "far"
  String spokenText;   // Arabic sentence for TTS
  bool isError;
}
```

---

## Distance Estimation

Simple bounding-box area ratio (no depth sensor):

| Condition | Arabic | English |
|-----------|--------|---------|
| bbox area > 15% of image | قريب جداً | very close |
| bbox area > 5% of image | قريب | close |
| bbox area ≤ 5% of image | بعيد | far |

---

## Configuration

`.env` file (gitignored, must be created manually):
```
GROQ_API_KEY=your_groq_api_key_here
```

Loaded at startup by `flutter_dotenv`. Read in `gemini_service.dart` via `dotenv.env['GROQ_API_KEY']`. App crashes on startup if `.env` is missing or key is absent.
