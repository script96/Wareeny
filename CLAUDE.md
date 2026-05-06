# Wareeny — AI Assistant Reference

Context for AI assistants (Claude, etc.) working on this codebase. Captures architecture, patterns, current status, and gotchas not obvious from reading the code.

---

## What This Is

Wareeny is a Flutter app for blind and low-vision users in Egypt. Core capabilities:
- Real-time YOLOv8 object detection (on-device, no internet)
- Scene description via Groq LLaMA Vision API
- Egyptian currency recognition (custom YOLOv8 model)
- Dual-language OCR (Arabic via Groq Vision + English via ML Kit)
- Object Finder (YOLO-based + vision-based)
- Color detection
- Danger Alert — always-on background scan for warning signs (English text)
- All output in Egyptian Arabic via TTS

Runs on Android. iOS is a stub (not tested, not deployed).

---

## Implementation Status

> **Current state: prototype/mockup.** The Flutter app will be completely overhauled once all features and models are finalized. Do not invest in polishing the current UI code.

### Working (code + logic functional)
- General object detection (80 COCO classes, YOLOv8n TFLite)
- Scene description via Groq LLaMA 4 Scout
- OCR: English (Google ML Kit) + Arabic (Groq Vision — replaces Tesseract)
- Color detection (HSL-based, 5×5 center pixel sample)
- Egyptian Arabic TTS with throttling (3s repeat cooldown)
- Bounding box overlay with Arabic labels
- App lifecycle management (pause/resume on background)
- QA Mode (OCR document → Groq text LLM → conversational voice Q&A)
- Danger Alert — always-on ML Kit background scan (English warning keywords, 5s interval, 30s per-keyword throttle)

### Implemented but Poor Quality — Needs Work
- **Currency detection** — new YOLOv8m fp16 model trained and deployed (`currency_yolov8m.tflite`). Accuracy untested on real device — requires field testing.
- **Object Finder** — logic exists but rudimentary, barely functional. Complete overhaul planned after model work is done.
- **Gesture controls** — stubs exist in code but not properly implemented. Full gesture system will be built during app overhaul.

### Not Yet Implemented
- Brand detection (local Egyptian brands) — thesis requirement FR-IN-3, no model, no code
- Hand-held object focus — described in thesis, not in codebase
- Haptic feedback — not started
- Voice commands — not started
- Traffic light detection — deferred
- Danger Alert for Arabic-only signs — ML Kit has no Arabic script support; English signs only for now
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
├── ocr_service.dart             ML Kit English OCR + danger keyword scanner
└── services/
    ├── vision_service.dart      Core orchestrator: all modes, timers, state machine
    ├── camera_service.dart      Camera singleton: init, snapshot, dispose
    ├── speech_service.dart      TTS singleton: Egyptian Arabic, throttled speak
    ├── color_service.dart       Dominant color from image center, Arabic names
    ├── voice_input_service.dart STT singleton wrapper for QA voice input
    └── object_finder_types.dart Enums (WareneMode, ObjectFinderMode, etc.), target registry
ui/
├── screens/camera_screen.dart   Main screen: gesture detection, overlays, lifecycle
└── widgets/
    ├── action_menu.dart         Bottom sheet: 6 mode/action options
    ├── bounding_box_painter.dart CustomPainter: bbox overlays on camera preview
    └── target_picker.dart       Object Finder target selection sheet
assets/
└── models/
    ├── yolov8n.tflite           43 MB, 80 COCO classes, threshold 0.25
    ├── labels.txt               80 COCO class names
    ├── currency_yolov8m.tflite  ~24 MB, YOLOv8m fp16, 14 EGP denominations, threshold 0.15
    └── currency_labels.txt      Currency class names
```

---

## Critical Gotchas

### GeminiService Is Not Gemini
`lib/gemini_service.dart` uses **Groq API** (`api.groq.com`), model `meta-llama/llama-4-scout-17b-16e-instruct`. Legacy name from early development. Do not add Google Gemini SDK — the service is already functional.

### Arabic OCR Uses Groq Vision
`OCRService` handles English only (ML Kit Latin). Arabic OCR is routed to `GeminiService.extractTextFromImage()` in `VisionService.readText()` and `VisionService.startDocumentQa()`. Tesseract has been removed. Do not add it back — it was slow, inaccurate, and depended on large tessdata files. Groq handles Arabic text correctly including handwriting and mixed-script signs.

### Danger Alert Is Always-On
`VisionService._dangerScanTimer` runs every 5 seconds regardless of mode. It is NOT stopped by `stopAllTimers()` or `switchMode()` — only by `handleAppPause()` and `dispose()`. It restarts automatically on the next `switchMode()` call (including resume). Do not add danger scanning logic to individual mode handlers — it lives independently in `_runDangerScan()`.

### YUV Stride Bug — Do Not Use yoloOnFrame()
`flutter_vision`'s `yoloOnFrame()` corrupts NV21→Bitmap conversion on many Android devices due to Y-plane stride padding. The app uses `CameraService.takeSnapshot()` (JPEG) instead. Do not revert this.

### Center Crop Is Required
YOLOv8 expects square input. `detector.dart` center-crops 720×1280 portrait to 720×720 before inference, then maps bbox coordinates back to original image space. Removing the crop causes significant accuracy degradation.

### Different Confidence Thresholds Per Model
- General model: 0.25 (standard COCO)
- Currency model: 0.15 (intentionally lower — catches folded/angled/partial notes)

### No Backend
No server, no database. All processing: on-device (YOLO, OCR English, color, danger scan) or Groq API (scene description, smart finder, Arabic OCR). `.env` contains only `GROQ_API_KEY`.

### Arabic Is Primary Language
All TTS, UI text, and error messages are in Egyptian Arabic. When adding any feature, add Arabic TTS strings. `SpeechService` defaults to `ar-EG` locale at 0.5× speed.

### Object Finder Registry Gap
`ObjectFinderRegistry` has 10 fast targets and 7 smart targets hardcoded. ATMs, pharmacies, trash cans, mosques, and other real-world landmarks are not registered. They can be added to `smartTargets` in `object_finder_types.dart` since they can be found via Groq vision without a dedicated model.

---

## API Dependencies

| Service | Endpoint | Key |
|---------|----------|-----|
| Groq Vision | `https://api.groq.com/openai/v1/chat/completions` | `GROQ_API_KEY` in `.env` |

Groq is used for: scene description, smart object finder, Arabic OCR, and Document QA.
Rate limit: 429 responses are handled in `gemini_service.dart` with Arabic fallback TTS. Arabic OCR returns `null` on 429 (not empty string) so callers can distinguish rate-limit failure from "no text found."

---

## Modes Reference

| Mode | Enum Value | Engine | Interval | Entry Point |
|------|-----------|--------|----------|-------------|
| General Objects | `generalObjects` | YOLOv8 general | 1500ms | Action menu / swipe |
| Currency | `currency` | YOLOv8 currency | 1500ms | Action menu / swipe |
| Object Finder (fast) | `objectFinderFast` | YOLOv8 general | 2000ms | Action menu → target picker |
| Object Finder (smart) | `objectFinderSmart` | Groq Vision | 3000ms | Action menu → target picker |
| Color | `color` | ColorService | 2000ms | Action menu / triple-tap |
| Document QA | `documentQa` | OCR + Groq Text | Event-driven | Action menu (اسأل عن نص) |

One-shot actions (not modes): `describeScene()` (double-tap), `readText()` (action menu).

Always-on background: `_dangerScanTimer` (5s, independent of mode, ML Kit keyword scan).

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

### New danger keyword
Add to `OCRService._dangerKeywords` list in `lib/ocr_service.dart`.
Add Arabic translation to `VisionService._dangerArabic` map in `lib/services/vision_service.dart`.
Both must stay in sync.

### QA Mode
Implemented and stabilized.
1. Run OCR on document → get structured `OCRResult`
2. Pass text as Groq system context (truncated to 4,000 chars with spoken warning if truncated).
3. Loop: user double-taps to speak question (via `speech_to_text`) → Groq `llama-3.3-70b-versatile` text model answers using ONLY the document → TTS reads answer.
4. History is stored in `VisionService._qaHistory` (max 5 turns) and cleared on mode exit.

**Stabilization Details:**
- Voice input automatically falls back to exact locale (`ar_EG`, `en_US`), then prefix matches, then device default.
- Swipe left/right and triple-tap gestures are disabled while in QA mode to prevent accidental exit. User is prompted to use the menu.
- `ActionMenu` dynamically updates to show `اسأل عن نص جديد` (rescan) and `إنهاء سؤال النص` (exit) while hiding the general QA entry point.
- QA questions under 2 characters are rejected to save API calls.
- Voice input handles specific failures (`permissionDenied`, `timeout`, `unavailable`, `noSpeech`, `error`) and translates them into appropriate Egyptian Arabic TTS messages.
