# Wareeny — AI Assistant Reference

Context for AI assistants (Claude, etc.) working on this codebase. Captures architecture, patterns, current status, and gotchas not obvious from reading the code.

---

## What This Is

Wareeny is a Flutter app for blind and low-vision users in Egypt. Core capabilities:
- Real-time YOLOv8 object detection (on-device, no internet)
- Scene description via Groq LLaMA Vision API
- Egyptian currency recognition (custom YOLOv8 model)
- Dual-language OCR (Arabic + English)
- Object Finder (YOLO-based + vision-based)
- Color detection
- All output in Egyptian Arabic via TTS

Runs on Android. iOS is a stub (not tested, not deployed).

---

## Implementation Status

> **Current state: prototype/mockup.** The Flutter app will be completely overhauled once all features and models are finalized. Do not invest in polishing the current UI code.

### Working (code + logic functional)
- General object detection (80 COCO classes, YOLOv8n TFLite)
- Scene description via Groq LLaMA 4 Scout
- OCR: English (Google ML Kit) + Arabic (Tesseract 5)
- Color detection (HSL-based, 5×5 center pixel sample)
- Egyptian Arabic TTS with throttling (3s repeat cooldown)
- Bounding box overlay with Arabic labels
- App lifecycle management (pause/resume on background)

### Implemented but Poor Quality — Needs Work
- **Currency detection** — code exists, model is bad (wrong training data/approach). New YOLOv8m model currently being trained. Do not rely on current model output.
- **Object Finder** — logic exists but rudimentary, barely functional. Complete overhaul planned after model work is done.
- **Gesture controls** — stubs exist in code but not properly implemented. Full gesture system will be built during app overhaul.

### Not Yet Implemented
- Brand detection (local Egyptian brands) — thesis requirement FR-IN-3, no model, no code
- Hand-held object focus — described in thesis, not in codebase
- QA Mode (OCR a document then conversational Q&A via Groq) — not started
- Haptic feedback — not started
- Voice commands — not started
- Traffic light detection — deferred
- Wet floor / danger detection — deferred
- Private photo detection before cloud upload — deferred
- Saved items finder — deferred
- ATM, pharmacy, mosque added to Object Finder registry — not yet registered

### Known Technical Debt
- `GeminiService` uses Groq, not Google Gemini (legacy name, should rename to `GroqVisionService`)
- Zero tests written (test/ folder exists with boilerplate only)
- No CI/CD
- Entire Flutter UI is a prototype — full rebuild planned

---

## Architecture Patterns

### Singleton Services
All services are singletons accessed via `.instance`:
- `VisionService.instance`
- `CameraService.instance`
- `SpeechService.instance`
- `ColorService.instance`

Never instantiate directly. Never call lower services from UI — always go through `VisionService`.

### VisionService Is the Orchestrator
`lib/services/vision_service.dart` owns everything: timer loops, mode transitions, calling detectors, coordinating TTS. All feature logic lives here. UI only listens to streams and sends user intents.

### Stream-Based State
`VisionService` exposes `StreamController` streams:
- `modeStream` — current `WareneMode`
- `statusStream` — Arabic status string for UI
- `detectionStream` — `DetectionResult`
- `finderStateStream` — `ObjectFinderState`

UI widgets subscribe to these. Never push state manually from services to UI.

### Mode Switching
All mode transitions go through `VisionService.switchMode(newMode, target?, speak?)`. This cancels active timers, resets state, starts new mode's loop. Do not bypass this method.

### One-Shot Actions
`describeScene()` and `readText()` pause the current mode, execute, then resume. Do not manually toggle modes around them.

---

## File Map

```
lib/
├── main.dart                    Entry point, PermissionGate, app theme
├── detector.dart                YoloDetector: TFLite model loading, inference, center-crop
├── gemini_service.dart          Groq API client (misnamed — NOT Google Gemini)
├── ocr_service.dart             Dual OCR: ML Kit (EN) + Tesseract (AR)
└── services/
    ├── vision_service.dart      Core orchestrator: all modes, timers, state machine
    ├── camera_service.dart      Camera singleton: init, snapshot, dispose
    ├── speech_service.dart      TTS singleton: Egyptian Arabic, throttled speak
    ├── color_service.dart       Dominant color from image center, Arabic names
    └── object_finder_types.dart Enums (WareneMode, ObjectFinderMode, etc.), target registry
ui/
├── screens/camera_screen.dart   Main screen: gesture detection, overlays, lifecycle
└── widgets/
    ├── action_menu.dart         Bottom sheet: 6 mode/action options
    ├── bounding_box_painter.dart CustomPainter: bbox overlays on camera preview
    └── target_picker.dart       Object Finder target selection sheet
assets/
├── models/
│   ├── yolov8n.tflite           43 MB, 80 COCO classes, threshold 0.25
│   ├── labels.txt               80 COCO class names
│   ├── currency_yolov8n.tflite  6 MB, 14 EGP denominations, threshold 0.15
│   └── currency_labels.txt      Currency class names
└── tessdata/
    ├── ara.traineddata          Arabic OCR language pack
    └── eng.traineddata          English OCR language pack
```

---

## Critical Gotchas

### GeminiService Is Not Gemini
`lib/gemini_service.dart` uses **Groq API** (`api.groq.com`), model `meta-llama/llama-4-scout-17b-16e-instruct`. Legacy name from early development. Do not add Google Gemini SDK — the service is already functional.

### YUV Stride Bug — Do Not Use yoloOnFrame()
`flutter_vision`'s `yoloOnFrame()` corrupts NV21→Bitmap conversion on many Android devices due to Y-plane stride padding. The app uses `CameraService.takeSnapshot()` (JPEG) instead. Do not revert this.

### Center Crop Is Required
YOLOv8 expects square input. `detector.dart` center-crops 720×1280 portrait to 720×720 before inference, then maps bbox coordinates back to original image space. Removing the crop causes significant accuracy degradation.

### Different Confidence Thresholds Per Model
- General model: 0.25 (standard COCO)
- Currency model: 0.15 (intentionally lower — catches folded/angled/partial notes)

### No Backend
No server, no database. All processing: on-device (YOLO, OCR, color) or Groq API (scene description, smart finder). `.env` contains only `GROQ_API_KEY`.

### Arabic Is Primary Language
All TTS, UI text, and error messages are in Egyptian Arabic. When adding any feature, add Arabic TTS strings. `SpeechService` defaults to `ar-EG` locale at 0.5× speed.

### Object Finder Registry Gap
`ObjectFinderRegistry` has 10 fast targets and 7 smart targets hardcoded. ATMs, pharmacies, trash cans, mosques, and other real-world landmarks are not registered. They can be added to `smartTargets` in `object_finder_types.dart` since they can be found via Groq vision without a dedicated model.

---

## API Dependencies

| Service | Endpoint | Key |
|---------|----------|-----|
| Groq Vision | `https://api.groq.com/openai/v1/chat/completions` | `GROQ_API_KEY` in `.env` |

Rate limit: 429 responses are handled in `gemini_service.dart` with an Arabic fallback TTS message.

---

## Modes Reference

| Mode | Enum Value | Engine | Interval | Entry Point |
|------|-----------|--------|----------|-------------|
| General Objects | `generalObjects` | YOLOv8 general | 1500ms | Action menu / swipe |
| Currency | `currency` | YOLOv8 currency | 1500ms | Action menu / swipe |
| Object Finder (fast) | `objectFinderFast` | YOLOv8 general | 2000ms | Action menu → target picker |
| Object Finder (smart) | `objectFinderSmart` | Groq Vision | 3000ms | Action menu → target picker |
| Color | `color` | ColorService | 2000ms | Action menu / triple-tap |

One-shot actions (not modes): `describeScene()` (double-tap), `readText()` (action menu).

---

## Adding Features

### New detection mode
1. Add value to `WareneMode` in `object_finder_types.dart`
2. Add timer + handler in `VisionService`
3. Add menu item to `action_menu.dart`
4. Handle in `VisionService.switchMode()`

### New Object Finder target
Add to `ObjectFinderRegistry` in `object_finder_types.dart`:
- `fastTargets`: use for YOLO-detectable 80 COCO classes
- `smartTargets`: use for anything else (Groq vision handles it)

### New TFLite model
1. Add `.tflite` to `assets/models/`
2. Declare in `pubspec.yaml` assets
3. Add enum value to `DetectionModel` in `detector.dart`
4. Load in `YoloDetector.init()`

### QA Mode (not yet built)
Planned flow:
1. Run OCR on document → get text string
2. Pass text as Groq system context
3. Loop: user speaks question (voice input) → Groq answers → TTS reads answer
4. Needs: voice input integration (not yet in project), conversation state in VisionService
