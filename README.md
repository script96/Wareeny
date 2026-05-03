
# Wareeny (واريني)

An AI-powered mobile assistive system for blind and low-vision users in Egypt. Provides real-time object detection, scene description, text reading, and currency recognition — all announced in Egyptian Arabic via text-to-speech.

Built with Flutter. Runs on Android.

---

## Features

### Object Detection
- Detects 80 COCO classes in real time (people, vehicles, furniture, food, electronics, etc.)
- YOLOv8n running on-device via TensorFlow Lite — no internet required
- Spatial feedback: announces direction (left/center/right) and estimated distance (close/far) per object
- Up to 3 objects announced per detection cycle

### Scene Description
- One-shot scene summary powered by Groq LLaMA 4 Vision API
- Output in natural Egyptian Arabic
- Three verbosity levels: brief (1 sentence), normal (2–3 sentences), detailed (4–5 sentences)
- Prompt-engineered to prioritize hazards, spatial layout, and relevant context for blind users

### Egyptian Currency Recognition
- Custom YOLOv8 model trained on Egyptian pound banknotes
- Recognizes 1, 5, 10, 20, 50, 100, 200 EGP denominations (front and back variants)
- Tuned confidence threshold for folded and angled notes

### Object Finder
- **Fast mode**: YOLO-based search for any of 80 known object classes
- **Smart mode**: Groq vision-based search for arbitrary objects (keys, glasses, medicine, ID card, charger, remote, etc.)
- Announces direction and distance when target is found
- Periodic guidance cues while searching; 2-minute timeout

### Text Reading (OCR)
- English text: Google ML Kit (printed signs, labels, documents)
- Arabic text: Tesseract 5 with Arabic language pack
- Result announced via TTS

### Color Detection
- Identifies dominant color in camera center
- Reports in Arabic: أسود، أبيض، أحمر، أزرق، أخضر، إلخ

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.11.0 (Dart) |
| Object Detection | YOLOv8n TFLite |
| Inference Engine | flutter_vision 2.0.0 |
| Scene Description / Smart Finder | Groq API — LLaMA 4 Scout 17B |
| English OCR | Google ML Kit |
| Arabic OCR | Tesseract 5 |
| Text-to-Speech | flutter_tts 4.0.2 (Egyptian Arabic) |
| Camera | camera 0.11.0 |
| Environment | flutter_dotenv 6.0.0 |

---

## Quick Start

See [docs/SETUP.md](docs/SETUP.md) for full setup instructions.

```bash
flutter pub get
# Create .env with: GROQ_API_KEY=your_key_here
flutter run
```

Requires Android device (API 21+) with NDK installed.

---

## Gestures

| Gesture | Action |
|---------|--------|
| Double-tap | Describe scene (one-shot) |
| Triple-tap | Toggle color mode |
| Swipe right | Toggle currency / general objects |
| Swipe left | Toggle OCR language (EN / AR) |
| Long-press | Open mode menu |

---

## Documentation

| Document | Purpose |
|----------|---------|
| [docs/SETUP.md](docs/SETUP.md) | Environment setup and build guide |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design and data flow |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Feature roadmap and milestone tracking |
| [CLAUDE.md](CLAUDE.md) | AI assistant reference (architecture, gotchas, status) |

---

## License

Educational and humanitarian use. See [docs/thesis.pdf](docs/thesis.pdf) for full research context.

## Acknowledgments

- [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics)
- [Groq](https://groq.com/)
- [flutter_vision](https://pub.dev/packages/flutter_vision)
- [Flutter](https://flutter.dev/)
