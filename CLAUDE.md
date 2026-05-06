# Wareeny — AI Assistant Reference

Flutter app for blind/low-vision users in Egypt (Android; iOS is a stub). AI-assisted vision: YOLO object detection, Groq vision/LLM, ML Kit OCR, color detection, Egyptian Arabic TTS.

---

## Status

> **Prototype.** Full UI rebuild planned after features finalized. Don't polish current UI.

### Needs Work
- **Currency detection** — `currency_yolov8m.tflite` deployed. Accuracy untested on real device.
- **Object Finder** — barely functional. Complete overhaul planned.
- **Gesture controls** — stubs only, not implemented.

### Not Yet Implemented
- Brand detection (Egyptian brands) — thesis FR-IN-3, no model, no code
- Hand-held object focus — in thesis, not in code
- Haptic feedback, voice commands, traffic lights — not started
- Danger Alert for Arabic signs — ML Kit has no Arabic script support; English only
- Private photo detection, saved items finder — deferred
- ATM, pharmacy, mosque in Object Finder registry — not registered

---

## Architecture

**Singletons** — all services via `.instance` (`VisionService`, `CameraService`, `SpeechService`, `ColorService`). Never instantiate directly. UI never calls lower services — always through `VisionService`.

**VisionService** (`lib/services/vision_service.dart`) — sole orchestrator. Owns timer loops, mode transitions, detector calls, TTS coordination. All feature logic lives here.

**Streams** — UI subscribes to `VisionService` streams: `modeStream`, `statusStream`, `detectionStream`, `finderStateStream`. Never push state manually from services to UI.

**Mode switching** — always via `VisionService.switchMode(newMode, target?, speak?)`. Cancels timers, resets state, starts new loop. Never bypass.

**One-shot actions** — `describeScene()` and `readText()` pause mode, execute, resume. Don't toggle modes manually around them.

---

## Critical Gotchas

**`GeminiService` is Groq, not Gemini** — `lib/gemini_service.dart` hits `api.groq.com`, model `meta-llama/llama-4-scout-17b-16e-instruct`. Legacy name. Don't add Google Gemini SDK.

**Arabic OCR → Groq Vision** — `OCRService` handles English only (ML Kit). Arabic OCR routes to `GeminiService.extractTextFromImage()`. Tesseract removed permanently — slow, inaccurate, heavy tessdata. Don't add it back.

**Danger Alert is always-on** — `_dangerScanTimer` runs every 5s regardless of mode. NOT stopped by `stopAllTimers()` or `switchMode()` — only by `handleAppPause()` and `dispose()`. Restarts on next `switchMode()`. Don't add danger logic to mode handlers — it lives in `_runDangerScan()`.

**Don't use `yoloOnFrame()`** — `flutter_vision`'s YUV→NV21 corrupts output on many Android devices (stride padding). Use `CameraService.takeSnapshot()` (JPEG). Don't revert.

**Center crop required** — `detector.dart` crops 720×1280 → 720×720 before YOLO inference, maps bbox coords back. Removing crop kills accuracy.

**Confidence thresholds** — general: 0.25; currency: 0.15 (intentionally lower — catches folded/partial notes).

**No backend** — all processing: on-device (YOLO, English OCR, color, danger) or Groq. `.env` has only `GROQ_API_KEY`.

**Arabic is primary** — all TTS, UI text, errors in Egyptian Arabic. Every new feature needs Arabic TTS strings. `SpeechService` defaults to `ar-EG` at 0.5× speed.

**Object Finder registry gap** — 10 fast + 7 smart targets hardcoded. Add missing landmarks to `smartTargets` in `object_finder_types.dart` (Groq vision handles them without a dedicated model).

---

## API

| Service | Endpoint | Key |
|---------|----------|-----|
| Groq | `https://api.groq.com/openai/v1/chat/completions` | `GROQ_API_KEY` |

Used for: scene description, smart finder, Arabic OCR, Document QA.
429 → Arabic fallback TTS. Arabic OCR returns `null` (not `""`) on 429 — callers distinguish rate-limit from "no text found."

---

## Modes

| Mode | Enum | Engine | Interval |
|------|------|--------|----------|
| General Objects | `generalObjects` | YOLOv8n | 1500ms |
| Currency | `currency` | YOLOv8m fp16 | 1500ms |
| Object Finder fast | `objectFinderFast` | YOLOv8n | 2000ms |
| Object Finder smart | `objectFinderSmart` | Groq Vision | 3000ms |
| Color | `color` | ColorService | 2000ms |
| Document QA | `documentQa` | OCR + Groq Text | event-driven |

One-shots (not modes): `describeScene()` (double-tap), `readText()` (menu).
Always-on background: `_dangerScanTimer` (5s, ML Kit keyword scan).

---

## Adding Features

**New mode:** add to `WareneMode` in `object_finder_types.dart` → timer+handler in `VisionService` → menu item in `action_menu.dart` → handle in `switchMode()`.

**New Object Finder target:** add to `ObjectFinderRegistry` in `object_finder_types.dart`. `fastTargets` for COCO-80 classes, `smartTargets` for everything else.

**New TFLite model:** add `.tflite` to `assets/models/` + declare in `pubspec.yaml` → add enum to `DetectionModel` in `detector.dart` → load in `YoloDetector.init()`.

**New danger keyword:** add to `OCRService._dangerKeywords` AND `VisionService._dangerArabic` map. Both must stay in sync.

**QA Mode non-obvious details:**
- OCR text truncated to 4,000 chars (spoken warning if truncated); Groq model: `llama-3.3-70b-versatile`
- History: max 5 turns in `_qaHistory`, cleared on mode exit
- Swipe + triple-tap disabled in QA mode — menu only
- Voice input falls back: `ar_EG` → `en_US` → prefix match → device default
- Questions under 2 chars rejected
