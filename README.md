# وريني (Warene) — AI Assistive App for Visually Impaired Users

**Warene** is a real-time AI-powered mobile application designed to assist visually impaired users in Egypt. It uses on-device object detection with **YOLOv8** to identify objects through the phone's camera and announces them in **Egyptian Arabic** with spatial direction feedback — telling the user *what* is around them, *where* it is, and *how far* away it is.

---

## ✨ Features

### 🔍 Real-Time Object Detection
- Detects **80 COCO object classes** (people, cars, furniture, animals, electronics, food, etc.)
- Uses **YOLOv8n** (nano) model for fast on-device inference via TensorFlow Lite
- Runs detection every **1.5 seconds** using camera snapshots
- All processing happens **locally on the device** — no internet required

### 🗣️ Arabic Text-to-Speech (TTS)
- Announces detected objects in **Egyptian Arabic** with natural pronunciation
- Full translation dictionary for all 80 COCO classes (e.g., "person" → "شخص", "car" → "سيارة")
- Smart announcement system: avoids repeating the same object, waits 3 seconds between identical announcements

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
│   └── detector.dart      # YoloDetector wrapper, center-crop preprocessing
├── assets/
│   └── models/
│       ├── yolov8n.tflite  # YOLOv8 nano TFLite model (6.3 MB)
│       └── labels.txt      # 80 COCO class labels
├── android/                # Android platform configuration
├── pubspec.yaml            # Flutter dependencies
└── README.md               # This file
```

### Detection Pipeline

```
┌─────────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────────┐
│ Camera Feed  │───▶│ takePicture()│───▶│ Center Crop    │───▶│ flutter_vision│
│ (1280x720)   │    │ JPEG snapshot│    │ 720x720 square │    │ yoloOnImage() │
└─────────────┘    └──────────────┘    └────────────────┘    └──────┬───────┘
                                                                     │
┌─────────────┐    ┌──────────────┐    ┌────────────────┐           │
│ Arabic TTS   │◀──│ Spatial Info  │◀──│ Coordinate     │◀──────────┘
│ Announcement │    │ Direction +  │    │ Mapping +      │    (detections in
│              │    │ Distance     │    │ Crop Offset    │     cropped coords)
└─────────────┘    └──────────────┘    └────────────────┘
```

### Data Flow (Step by Step)

1. **Camera Capture**: Every 1.5 seconds, `takePicture()` captures a JPEG snapshot from the camera (720×1280 portrait)
2. **Center Crop**: The portrait image is center-cropped to a 720×720 square using `dart:ui` canvas operations. This avoids the model squishing the image from rectangle to square, which would distort objects and hurt detection accuracy
3. **Native Inference**: The cropped JPEG is passed to `flutter_vision`'s `yoloOnImage()`, which:
   - Decodes the JPEG to a Bitmap (native Java/C++)
   - Resizes to 640×640 (the model's input size)
   - Normalizes pixel values to [0, 1] (divides by 255)
   - Runs TFLite inference through the YOLOv8n model
   - Applies Non-Maximum Suppression (NMS) to filter overlapping boxes
   - Returns detected objects with bounding box coordinates
4. **Coordinate Mapping**: Bounding box coordinates are mapped from cropped-image space back to original-image space (adding the crop offset)
5. **Spatial Analysis**: Each detection's bounding box center determines direction (left/center/right), and its area determines estimated distance (close/far)
6. **Arabic TTS**: A natural Arabic sentence is constructed for the top 3 detections and spoken via `flutter_tts`
7. **Visual Overlay**: Bounding boxes are drawn on the camera preview with color-coded rectangles and Arabic labels

---

## 🔧 Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Framework** | Flutter (Dart) | Cross-platform UI and app logic |
| **Object Detection** | YOLOv8n (TFLite) | Real-time object detection model |
| **Inference Engine** | flutter_vision 2.0.0 | Native C++/Java TFLite inference wrapper |
| **Camera** | camera 0.11.0 | Camera preview and image capture |
| **Text-to-Speech** | flutter_tts 4.0.2 | Arabic speech synthesis |
| **Permissions** | permission_handler 11.3.1 | Camera and microphone permissions |
| **Screen Wake** | wakelock_plus 1.2.8 | Keeps screen on during use |
| **Model Format** | TensorFlow Lite (.tflite) | Optimized on-device ML inference |

### Model Details

| Property | Value |
|----------|-------|
| Architecture | YOLOv8 Nano |
| Input Shape | `[1, 640, 640, 3]` (NHWC, float32) |
| Output Shape | `[1, 84, 8400]` (84 = 4 box coords + 80 class scores) |
| Classes | 80 COCO classes |
| Model Size | ~6.3 MB |
| Quantization | None (float32) |
| Inference Threads | 4 |

---

## 📂 Key Files

### `lib/detector.dart` — YoloDetector

The core detection engine that wraps `flutter_vision`:

- **`YoloDetector`** class: Manages model lifecycle (load/unload), runs inference
- **`Detection`** data class: Holds label, Arabic translation, confidence, and bounding box `[x1, y1, x2, y2]`
- **`DetectionResult`** data class: Groups detections with source image dimensions for coordinate mapping
- **`_centerCropToSquare()`**: Uses `dart:ui` canvas to center-crop portrait images to square before inference — prevents aspect-ratio distortion that significantly reduces detection accuracy
- **`detectFromFile()`**: Full pipeline — load JPEG → get dimensions → crop → run inference → map coordinates back → return results
- **Arabic translation map**: All 80 COCO class names translated to Egyptian Arabic

### `lib/main.dart` — App UI and Logic

The main application with 4 key components:

1. **`PermissionGate`**: Handles camera/microphone permission requests before showing the camera
2. **`CameraScreen`**: The main screen with camera preview, detection overlay, and status display
3. **Spatial Helpers**:
   - `_getDirection()` — determines left/center/right from bbox center X position (splits image into thirds)
   - `_getDistance()` — estimates distance from bbox area ratio (>15% = very close, >5% = close, else far)
   - `_buildSpatialDescription()` — builds Arabic sentence like "شخص على اليمين، قريب"
4. **`BoundingBoxPainter`**: Custom `CustomPainter` that draws color-coded bounding boxes with Arabic labels on the camera preview. Handles coordinate transformation from source image space → display space using BoxFit.cover scaling math

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.11.0 or later
- **Android SDK** with NDK installed (required by flutter_vision for native C++ compilation)
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

### Build for Release

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## ⚠️ Known Considerations

### YUV Stride Bug Workaround
flutter_vision's `yoloOnFrame()` has a bug where the Y plane stride padding on some Android devices (e.g., Qualcomm chipsets) corrupts the NV21→Bitmap conversion, producing a distorted image that the model cannot detect objects in. **Warene uses `takePicture()` JPEG snapshots instead**, which bypasses this bug entirely. The tradeoff is slightly higher latency per detection (camera capture + JPEG encode/decode), but detection accuracy is dramatically better.

### Center Crop for Accuracy
The YOLOv8 model expects square 640×640 input. Most phone cameras produce portrait images (e.g., 720×1280). Without preprocessing, flutter_vision squishes the rectangle to a square, distorting all objects. Warene center-crops to square first, so the model sees undistorted objects and only needs a mild downscale (720→640).

### Detection Interval
Detection runs every 1.5 seconds rather than real-time frame-by-frame. This is intentional for:
- Stable performance on mid-range devices
- Clean TTS announcements (no overlapping speech)
- Reasonable battery usage

---

## 🗺️ Roadmap

Planned features for future development:

- [ ] **Obstacle Warning with Haptic Vibration** — vibrate when large objects are very close
- [ ] **Text Reading (OCR)** — read signs, labels, and prices using ML Kit
- [ ] **Scene Description** — summarize all detected objects into one natural Arabic sentence
- [ ] **Currency Recognition** — identify Egyptian pound banknotes
- [ ] **Voice Commands** — activate features using voice input
- [ ] **Color Detection** — announce the color of objects

---

## 📄 License

This project is for educational and humanitarian purposes.

---

## 🙏 Acknowledgments

- [Ultralytics YOLOv8](https://github.com/ultralytics/ultralytics) — State-of-the-art object detection model
- [flutter_vision](https://pub.dev/packages/flutter_vision) — Native TFLite inference for Flutter
- [COCO Dataset](https://cocodataset.org/) — 80-class object detection benchmark
- [Flutter](https://flutter.dev/) — Cross-platform mobile framework
