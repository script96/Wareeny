# Wareeny — Developer Setup

---

## Prerequisites

- Flutter SDK 3.11.0 or later — [install guide](https://docs.flutter.dev/get-started/install)
- Android SDK with **NDK installed** (required by flutter_vision for native TFLite compilation)
- Java Development Kit 11+
- Android device (API 21+) or emulator with camera support
- Groq API key (free tier available at https://console.groq.com)

---

## Setup Steps

### 1. Install Flutter dependencies

```bash
flutter pub get
```

### 2. Create environment file

Create `.env` in the project root (next to `pubspec.yaml`):

```
GROQ_API_KEY=your_groq_api_key_here
```

Get a free key at https://console.groq.com. The app crashes on startup if this file is missing or the key is empty.

### 3. Verify model assets

These large files must exist locally. They may not be tracked in git (check `.gitignore`):

```
assets/models/yolov8n.tflite             (~43 MB)
assets/models/labels.txt
assets/models/currency_yolov8n.tflite    (~6 MB)
assets/models/currency_labels.txt
assets/tessdata/ara.traineddata          (~1.4 MB)
assets/tessdata/eng.traineddata          (~4.0 MB)
```

If any are missing, see the Models section below.

### 4. Run the app

```bash
# Debug mode (slower, use for development)
flutter run

# Release mode (required for real performance testing)
flutter run --release
```

Connect an Android device via USB with USB debugging enabled, or start an emulator first.

---

## Android NDK Setup

`flutter_vision` requires the Android NDK for native TFLite compilation. Without it, the build fails.

**Via Android Studio:**
1. Open Android Studio
2. Tools → SDK Manager → SDK Tools tab
3. Check "NDK (Side by side)" → Apply

**Via command line:**
```bash
sdkmanager "ndk;26.1.10909125"
```

**Verify:** Check `android/app/build.gradle.kts` for the `ndkVersion` field — it must match your installed NDK version.

---

## Build for Release

```bash
# APK (sideload)
flutter build apk --release

# App Bundle (Play Store)
flutter build appbundle --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Models

### General Object Detection
`assets/models/yolov8n.tflite` — Standard YOLOv8 nano exported to TFLite int8.

Export yourself if needed:
```bash
pip install ultralytics
yolo export model=yolov8n.pt format=tflite int8=true
```

### Egyptian Currency Model
`assets/models/currency_yolov8n.tflite` — Custom-trained on Egyptian pound banknotes.

Training dataset is not in this repo. Contact the team for dataset access or retraining instructions. Class mapping is in `lib/detector.dart` under `_currencyArabicNames`.

### Tesseract Language Data
Download from the official Tesseract tessdata repository:
- Arabic: `ara.traineddata` (fast variant recommended)
- English: `eng.traineddata`

Place both in `assets/tessdata/`.

---

## Project Structure

```
Wareeny-test/
├── lib/
│   ├── main.dart                    Entry point, PermissionGate, app theme
│   ├── detector.dart                YOLOv8 TFLite wrapper
│   ├── gemini_service.dart          Groq API client (scene description, smart finder)
│   ├── ocr_service.dart             Dual OCR: ML Kit (EN) + Tesseract (AR)
│   └── services/
│       ├── vision_service.dart      Central orchestrator — all modes, state
│       ├── camera_service.dart      Camera singleton
│       ├── speech_service.dart      TTS singleton (Egyptian Arabic)
│       ├── color_service.dart       Dominant color detection
│       └── object_finder_types.dart Mode enums, target registry
│   └── ui/
│       ├── screens/camera_screen.dart   Main UI screen + gestures
│       └── widgets/
│           ├── action_menu.dart         Mode selection bottom sheet
│           ├── bounding_box_painter.dart Detection overlay
│           └── target_picker.dart       Object finder target picker
├── assets/
│   ├── models/                      TFLite models + label files
│   └── tessdata/                    Tesseract language packs
├── docs/
│   ├── thesis.pdf                   Research thesis (Future University in Egypt, 2025-2026)
│   ├── ROADMAP.md                   Feature roadmap and milestone tracking
│   ├── ARCHITECTURE.md              System design and data flow
│   └── SETUP.md                     This file
├── CLAUDE.md                        AI assistant reference
├── README.md                        Public-facing project overview
└── pubspec.yaml                     Flutter dependency manifest
```

---

## Environment Variables

| Variable | Required | Purpose |
|----------|----------|---------|
| `GROQ_API_KEY` | Yes | Scene description + Smart Object Finder |

---

## Common Issues

**App crashes immediately on launch**
Check that `.env` exists in the project root and contains `GROQ_API_KEY`. Missing file = crash at startup.

**Build error: NDK not found**
NDK is not installed. Follow Android NDK Setup above.

**flutter_vision fails to load model**
Check that the `.tflite` files exist in `assets/models/` and are declared in `pubspec.yaml` under `assets:`.

**Arabic TTS sounds robotic or wrong language**
Device does not have the Egyptian Arabic (`ar-EG`) TTS engine. Install Google Text-to-Speech from Play Store and select Egyptian Arabic voice in system settings.

**Object detection is very slow (1+ second per frame)**
Running in debug mode. Debug mode runs Dart in a VM with no AOT compilation. Use `flutter run --release` for real-world performance.

**Currency model not detecting notes**
- Ensure good lighting (avoid harsh shadows or glare)
- Hold note approximately 20–30 cm from camera
- Model confidence threshold is 0.15 (low), so it should fire on most clear shots
- Worn/very crumpled notes may still be missed — model retraining is planned (see ROADMAP.md)

**Groq API returns 429**
Rate limit exceeded on free tier. The app handles this gracefully with an Arabic TTS message. Wait a few seconds and try again.
