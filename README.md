# Warene (واريني) 👁️ — AI Assistive App for Visually Impaired Users

**Warene** is a real-time AI-powered mobile application designed to assist visually impaired users in Egypt. It uses on-device object detection with **YOLOv8** to identify objects through the phone's camera and announces them in **Egyptian Arabic** with spatial direction feedback — telling the user *what* is around them, *where* it is, and *how far* away it is. It also features a **Scene Description** capability powered by Groq's LLaMA vision models.

---

## ✨ Features

### 🔍 Real-Time Object Detection
- Detects **80 COCO object classes** (people, cars, furniture, animals, electronics, food, etc.)
- Uses **YOLOv8n** (nano) model for fast on-device inference via TensorFlow Lite
- Runs detection every **1.5 seconds** using camera snapshots
- All processing happens **locally on the device** — no internet required

### 🖼️ Scene Description (Groq LLaMA)
- Summarizes the current scene in natural Arabic sentences optimized for blind users
- Uses **Groq API** with the `meta-llama/llama-4-scout-17b-16e-instruct` model for blazing fast vision inference
- Adjusts description verbosity (brief, normal, detailed)
- Intelligent prompt engineering to emphasize safety hazards and accurate direction

### 🗣️ Arabic Text-to-Speech (TTS)
- Announces detected objects in **Egyptian Arabic** with natural pronunciation
- Full translation dictionary for all 80 COCO classes (e.g., "person" → "شخص", "car" → "سيارة")
- Smart announcement system: avoids repeating the same object, waits 3 seconds between identical announcements

### 💵 Egyptian Currency Recognition
- Detects Egyptian Pound banknotes (10, 20, 50, 100, 200 EGP) using a custom YOLOv8 model.
- Fast, reliable bounding box detection with tuned confidence thresholds.
- Specialized audio feedback in Arabic for recognized denominations.

### 📖 Text Reading (OCR)
- On-device Optical Character Recognition (OCR) powered by Tesseract.
- Allows visually impaired users to read text from signs, products, or labels.
- Integration with TTS for seamless reading aloud.

### 🧭 Spatial Direction Feedback
- Tells the user **WHERE** objects are relative to them:
  - **على اليسار** — on the left
  - **في الوسط** — in the center  
  - **على اليمين** — on the right
- Estimates object **distance** based on bounding box size:
  - **قريب جداً** — very close (box > 15% of image)
  - **قريب** — close (box > 5% of image)
  - **بعيد** — far (box < 5% of image)
- Example TTS output: **"شخص على اليمين، قريب"** (person on the right, close)
- Announces **up to 3 objects** per detection cycle with full spatial context

### 📦 Bounding Box Visualization
- Color-coded bounding boxes drawn over detected objects on the camera preview
- Arabic labels with confidence percentages displayed above each box
- 8 rotating colors for visual distinction between multiple objects
- Semi-transparent fill inside boxes for better visibility

### 📷 High-Resolution Camera
- Uses `ResolutionPreset.high` for better image quality and detection accuracy
- Center-crops portrait images to square before inference to preserve aspect ratio
- Automatic lifecycle handling — pauses detection when app is backgrounded, resumes when foregrounded

---

## 🏗️ Architecture

### Project Structure

```
warene/
├── lib/
│   ├── main.dart          # App UI, camera, TTS, spatial feedback, bounding boxes
│   ├── detector.dart      # YoloDetector wrapper, center-crop preprocessing
│   ├── ocr_service.dart   # Text Reading component (Tesseract OCR)
│   └── gemini_service.dart# Scene description service (using Groq API)
├── assets/
│   ├── models/
│   │   ├── yolov8n.tflite           # YOLOv8 nano TFLite model (6.3 MB)
│   │   ├── labels.txt               # 80 COCO class labels
│   │   ├── currency_yolov8n.tflite  # Egyptian Currency YOLOv8 model
│   │   └── currency_labels.txt      # Currency labels (10, 20, 50, 100, 200 EGP)
│   ├── tessdata/                    # Tesseract OCR language data models
│   └── tessdata_config.json         # Tesseract configuration file
├── android/                # Android platform configuration
├── pubspec.yaml            # Flutter dependencies
└── README.md               # This file
```

### Detection Pipeline

```
┌─────────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────────┐
│ Camera Feed │───▶│ takePicture()│───▶│ Center Crop    │───▶│ flutter_vision│
│ (1280x720)  │    │ JPEG snapshot│    │ 720x720 square │    │ yoloOnImage() │
└─────────────┘    └──────────────┘    └────────────────┘    └──────┬───────┘
                                                                    │
┌─────────────┐    ┌──────────────┐    ┌────────────────┐           │
│ Arabic TTS  │◀──│ Spatial Info  │◀──│ Coordinate     │◀──────────┘
│ Announcement│    │ Direction +  │    │ Mapping +      │    (detections in
│             │    │ Distance     │    │ Crop Offset    │     cropped coords)
└─────────────┘    └──────────────┘    └────────────────┘
```

### Data Flow (Step by Step)

1. **Camera Capture**: Every 1.5 seconds, `takePicture()` captures a JPEG snapshot from the camera (720×1280 portrait).
2. **Center Crop**: The portrait image is center-cropped to a 720×720 square using `dart:ui` canvas operations. This avoids the model squishing the image.
3. **Native Inference**: The cropped JPEG is passed to `flutter_vision`'s `yoloOnImage()`, which runs TFLite inference through the YOLOv8n model and returns bounding box coordinates.
4. **Coordinate Mapping**: Bounding box coordinates are mapped from cropped-image space back to original-image space.
5. **Spatial Analysis**: Each detection's bounding box center determines direction, and its area determines estimated distance.
6. **Arabic TTS**: A natural Arabic sentence is constructed for the top 3 detections and spoken via `flutter_tts`.
7. **Scene Description (On-Demand)**: When the user activates the scene description button, YOLO is paused, a snapshot is captured, and sent to the **Groq LLaMA Vision API** which returns a comprehensive Arabic description of the scene spoken via TTS.

---

## 🔧 Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Framework** | Flutter (Dart) | Cross-platform UI and app logic |
| **Object Detection** | YOLOv8n (TFLite) | Real-time object detection model |
| **Inference Engine** | flutter_vision 2.0.0 | Native C++/Java TFLite inference wrapper |
| **Scene Description** | Groq LLaMA Vision API | Fast inference for rich scene context (`meta-llama/llama-4-scout-17b-16e-instruct`) |
| **Camera** | camera 0.11.0 | Camera preview and image capture |
| **Text-to-Speech** | flutter_tts 4.0.2 | Arabic speech synthesis |
| **Permissions** | permission_handler 11.3.1 | Camera and microphone permissions |
| **Networking** | http 1.2.2 | API requests for scene generation |
| **Screen Wake** | wakelock_plus 1.2.8 | Keeps screen on during use |

---

## 📂 Key Files

### `lib/detector.dart` — YoloDetector
The core detection engine that wraps `flutter_vision`. Handles model lifecycle (load/unload), runs inference (`detectFromFile()`), and maps 80 COCO class names translated to Egyptian Arabic. Also manages the secondary YOLOv8 model for **Egyptian Currency Recognition**.

### `lib/ocr_service.dart` — OCR Service
Handles on-device Optical Character Recognition (OCR) using Tesseract, allowing the app to extract text from images and pass it to the TTS engine.

### `lib/gemini_service.dart` — GeminiService (Groq Backend)
Handles the scene description capability. Formats images to base64 and sends them to the Groq API for rapid processing using a LLaMA vision model, handling timeouts, and connection errors to guarantee speech output.

### `lib/main.dart` — App UI and Logic
The main application containing the Camera Screen, bounding box painter mapping coordinates to the display screen, timer-based local object detection (running every 1.5s), and the TTS announcements.

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.11.0 or later
- **Android SDK** with NDK installed (required by flutter_vision for native C++ compilation)
- **Java Development Kit** 11+
- An **Android device** with a camera (API 21+)
- **ADB** configured for device deployment

### Installation

```bash
# 1. Clone the repository
git clone <repository-url>
cd warene

# 2. Install Flutter dependencies
flutter pub get

# 3. Connect your Android device via USB or wireless ADB

# 4. Run the app
flutter run
```

---

## ⚠️ Known Considerations

### YUV Stride Bug Workaround
flutter_vision's `yoloOnFrame()` has a bug where the Y plane stride padding on some Android devices corrupts the NV21→Bitmap conversion. **Warene uses `takePicture()` JPEG snapshots instead**, bypassing this bug.

### Center Crop for Accuracy
The YOLOv8 model expects square 640×640 input. Warene center-crops to square first, so the model sees undistorted objects and only needs a mild downscale.

---

## 🗺️ Roadmap

Planned features for future development:

- [x] **Scene Description** — summarize all detected objects into one natural Arabic sentence (Implemented via Groq)
- [x] **Text Reading (OCR)** — read signs, labels, and prices using Tesseract OCR
- [x] **Currency Recognition** — identify Egyptian pound banknotes
- [ ] **Obstacle Warning with Haptic Vibration** — vibrate when large objects are very close
- [ ] **Voice Commands** — activate features using voice input
- [ ] **Color Detection** — announce the color of objects

---

## 📄 License

This project is for educational and humanitarian purposes.

---

## 🙏 Acknowledgments

- [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) — State-of-the-art object detection model
- [Groq](https://groq.com/) — Fast AI inference engine
- [flutter_vision](https://pub.dev/packages/flutter_vision) — Native TFLite inference for Flutter
- [COCO Dataset](https://cocodataset.org/) — 80-class object detection benchmark
- [Flutter](https://flutter.dev/) — Cross-platform mobile framework
