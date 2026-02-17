# Warene (وارين) 👁️

Warene is an AI-powered assistive application designed for visually impaired users in Egypt. It uses real-time object detection and Arabic Text-to-Speech (TTS) to describe the environment.

## 🚀 Key Features

- **Real-time Object Detection**: Identifies 80+ common objects using YOLOv8.
- **Arabic TTS**: Speaks the names of detected objects in Egyptian Arabic.
- **Performance Optimized**: Uses Flutter Isolates for image preprocessing to maintain a smooth 60 FPS camera preview.
- **Stable Loop**: Features a robust, timer-based detection loop that prevents camera crashes common in real-time Android implementations.

## 🛠️ Tech Stack

- **Framework**: Flutter
- **AI Engine**: TensorFlow Lite (TFLite)
- **Model**: YOLOv8n (640x640 input)
- **Language**: Dart / Egyptian Arabic (TTS)
- **Key Plugins**: `camera`, `tflite_flutter`, `flutter_tts`, `permission_handler`

## 🏁 Getting Started for Developers

To get the app running on your machine, follow these steps:

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- An Android device (Honor 50 or similar) — Detection works best on physical hardware.

### 2. Setup
Clone the repository and install dependencies:

```powershell
git clone https://github.com/script96/Wareeny.git
cd Wareeny
flutter pub get
```

### 3. Run the App
Connect your device and run in **release mode** for the best performance (detection is significantly faster in release):

```powershell
flutter run --release
```

## 🏗️ Architecture & Optimizations

### High-Performance Preprocessing
Camera frames (YUV420) are processed in a background **Flutter Isolate**. This prevents the UI from freezing during the intensive YUV to RGB conversion and normalization math required by the AI model.

### Stable Camera Stream
Instead of starting and stopping the camera stream (which can be unstable on many Android devices), Warene keeps an **always-on stream**. A `Timer.periodic` ticks every 1500ms to grab the most recent frame for detection without interrupting the preview.

### Post-Processing
The app implements **Non-Maximum Suppression (NMS)** with an IoU threshold of 0.5 to ensure that duplicate detections for the same object are filtered out before being spoken.

## 📜 License
This project is built for the benefit of the visually impaired community in Egypt.
