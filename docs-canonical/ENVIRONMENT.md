# Environment & Local Setup

---

## Prerequisites

| Tool | Version | Notes |
|---|---|---|
| Flutter SDK | ≥ 3.12.0 | Includes Dart ^3.12.0 |
| Android Studio | Latest stable | Required for Android SDK and emulator |
| Xcode | ≥ 14 | Required for iOS builds (macOS only) |
| Python | ≥ 3.10 | For the FastAPI cloud backend |
| Ollama | Latest | For serving the Gemma 4 vision model locally |

---

## 1 — Flutter App Setup

### Install dependencies

```bash
flutter pub get
```

### Run in development mode (simulator / emulator)

```bash
flutter run --dart-define=APP_ENV=dev
```

### Run pointing at a specific backend (physical device on LAN)

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
```

### Run in production mode

```bash
flutter run --dart-define=APP_ENV=prod
```

### Run tests

```bash
flutter test
```

---

## 2 — Cloud VLM Backend Setup

### Install Python dependencies

```bash
cd backend
python -m venv .venv

# Windows
.venv\Scripts\activate

# macOS / Linux
source .venv/bin/activate

pip install -r requirements.txt
```

### Pull the Gemma 4 vision model

Ollama must be installed and running.

```bash
ollama pull gemma4:e4b
```

### Configure environment variables

```bash
cp backend/.env.example backend/.env
# Edit .env with your values (see the variables table below)
```

### Start the development server

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The server binds to all interfaces on port `8000`, making it reachable from a physical Android/iOS device on the same network.

---

## Flutter Build-Time Variables (`--dart-define`)

These are injected at compile time using `--dart-define=KEY=VALUE`. They are **not** read from any `.env` file — they must be passed on the `flutter run` or `flutter build` command line.

| Variable | Default (dev) | Default (prod) | Description |
|---|---|---|---|
| `APP_ENV` | `dev` | `prod` | Environment mode. Any value other than `prod` or `production` resolves to `dev`. |
| `API_BASE_URL` | `http://localhost:8000` | `https://api.wareeny.app` | Base URL of the FastAPI cloud backend. Override for physical device testing. |
| `CLOUD_MODEL_ID` | `gemma4:e4b` | `gemma4:e4b` | Ollama model tag sent in `/vlm/generate` requests. |
| `LOCAL_MODEL_REGISTRY` | `wareeny-local-models-dev` | `wareeny-local-models` | Registry name for the on-device model installer (Phase F). |
| `ENABLE_DIAGNOSTICS` | `true` | `false` | Enables the debug overlay (`NavigationDebugPanel`) and verbose logging. |

---

## Backend Environment Variables (`.env` file)

These are loaded by the FastAPI process at startup. Copy `.env.example` to `.env` in the `backend/` directory and set the values.

| Variable | Default | Description |
|---|---|---|
| `OLLAMA_URL` | `http://localhost:11434` | Base URL of the Ollama instance serving the vision model. |
| `GEMMA_MODEL` | `gemma4:e4b` | Ollama model tag to use for inference. |
| `APP_ENV` | `dev` | Backend environment label. Exposed in the `/health` response. |
| `NUM_PREDICT` | `320` | Default maximum output token count for tasks not listed below. |
| `NUM_PREDICT_SCAN` | `80` | Output cap for the `scan` task (one-liner gist). |
| `NUM_PREDICT_READ` | `1200` | Output cap for the `read` task (full document). |
| `OLLAMA_KEEP_ALIVE` | `30m` | Duration Ollama keeps the model in GPU memory between requests. Reduces first-token latency on repeated scans. |

> **Note:** Do not commit `.env` to version control. Only `.env.example` is tracked.

---

## Android Runtime Permissions

The Android manifest requests the following permissions. On Android 6+, dangerous permissions are requested at runtime by `permission_handler`.

| Permission | Purpose |
|---|---|
| `CAMERA` | Camera preview and frame capture |
| `SEND_SMS` | Emergency SMS dispatch via `SmsManager` |
| `ACCESS_FINE_LOCATION` | GPS coordinates for emergency SOS message |
| `RECORD_AUDIO` | Reserved for future Speech-to-Text (STT) input |

---

## iOS Runtime Permissions

Declared in `ios/Runner/Info.plist`. iOS prompts the user for:

| Key | Purpose |
|---|---|
| `NSCameraUsageDescription` | Camera preview and frame capture |
| `NSLocationWhenInUseUsageDescription` | GPS for emergency SOS |
| `NSMicrophoneUsageDescription` | Reserved for future STT input |

---

## Physical Device Testing (LAN)

1. Find your development machine's local IP address:
   - **Windows:** `ipconfig` → look for "IPv4 Address"
   - **macOS / Linux:** `ifconfig | grep "inet "`
2. Ensure the phone and the development machine are on the same Wi-Fi network.
3. Start the FastAPI server with `--host 0.0.0.0`.
4. Run the Flutter app with the LAN IP:
   ```bash
   flutter run --dart-define=API_BASE_URL=http://192.168.1.X:8000
   ```

---

## Models (On-Device Assets)

YOLO model files are bundled under `assets/models/` and declared in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/models/
```

These are included in the app binary. No download is required at runtime for Tier 1 (local CV). Tier 2 (local VLM) model download is planned for Phase F via the `file_download` bridge.
