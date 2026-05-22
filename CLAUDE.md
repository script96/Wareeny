# Wareeny

AI-powered mobile assistive app for blind/low-vision users. Bachelor thesis project, Future University in Egypt.

## Stack

- **Flutter (Dart)** — cross-platform mobile shell (iOS + Android)
- **YOLOv8** — real-time object detection (on-device)
- **GPT-4V / LMMs** — semantic understanding, VQA, Arabic OCR fallback
- **Google ML Kit + EasyOCR** — on-device OCR (English + Arabic)
- **Whisper AI** — speech-to-text / voice commands
- **Google Cloud TTS** — audio feedback
- **PyTorch / OpenCV** — backend AI inference

## Key Features

Indoor: object detection + distance, in-hand detection, brand/currency recognition, saved items, privacy mode  
Outdoor: obstacle detection, traffic lights, object finder, sign reader, navigation  
OCR: document read, QA mode, danger word alerts  
Safety: danger mode (voice/gesture/shake), emergency auto-call + location share, directional audio

## Repo Layout

```
lib/
  app/              # bootstrap + root widget
  core/             # DI, config, theme
  shared/bridges/   # platform channel bridges (camera, AI runtime, audio/haptics, battery)
  presentation/     # UI (camera feed, navigation shell, reusable widgets)
docs/               # thesis PDF/TXT, system arch diagram, other docs
```
## Corrections & Agent Notes

<!-- Add agent mistakes and corrections here as they occur -->
