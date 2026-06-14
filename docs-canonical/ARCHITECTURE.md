# Architecture

Wareeny ("وريني" — "Show Me" in Arabic) is a cross-platform mobile assistive application for blind and low-vision users. It converts the device camera into a real-time understanding engine, speaking results and providing haptic feedback so users never need to look at the screen.

---

## System Overview

The app is structured around a **three-tier AI runtime** that balances latency, privacy, and reasoning depth. Safety-critical paths always run on-device; heavy reasoning falls back to the cloud.

```
┌─────────────────────────────────────────────────────────┐
│                  Wareeny Flutter Shell                  │
│  (Dart/Flutter — Android + iOS)                         │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Tier 1      │  │  Tier 2      │  │  Tier 3      │  │
│  │  Local CV    │  │  Local VLM   │  │  Cloud VLM   │  │
│  │  YOLOv8 /   │  │  MediaPipe   │  │  FastAPI +   │  │
│  │  LiteRT      │  │  LLM Infer  │  │  Ollama      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         └─────────────────┴──────────────────┘          │
│                           │                             │
│              ┌────────────▼────────────┐                │
│              │   Feedback Engine       │                │
│              │   TTS + Haptics         │                │
│              └─────────────────────────┘                │
└─────────────────────────────────────────────────────────┘
```

---

## Tier 1 — Real-Time Local Computer Vision

- **Technology:** YOLOv8 nano (quantized int8 for Android, `.mlpackage` for iOS) via the `ultralytics_yolo` Flutter plugin and LiteRT (TensorFlow Lite).
- **Inference latency:** ~15–50 ms per frame on a mid-range device.
- **Rule:** All real-time safety tasks run exclusively here. They never go through the VLM pipeline.
- **Capabilities:**
  - Obstacle proximity detection and zone classification (left / center / right)
  - Stuff Finder (search for COCO-class objects: keys, glasses, phone, wallet, etc.)
  - Traffic light status classification (reserved)
  - Danger sign/word detection (reserved)
- **Models stored at:** `assets/models/` (bundled with the app binary)

---

## Tier 2 — On-Device VLM (Private & Offline)

- **Technology:** MediaPipe LLM Inference running a quantized Gemma model.
- **Implementation:** `lib/shared/vlm/local_vlm_provider.dart` + native bridge `com.wareeny.bridge/local_ai_runtime`.
- **Status:** Native runtime integration planned for Phase F. Provider interface is fully defined; bridge methods are stubbed.
- **Preferred for:** Read, Scan, In-Hand identification, Currency ID, Brand recognition.
- **Privacy guarantee:** No data leaves the device when this tier is active.

---

## Tier 3 — Cloud VLM (Fallback / Heavy Reasoning)

- **Technology:** Python FastAPI service forwarding requests to an Ollama-hosted Gemma 4 vision model, streaming token deltas back over SSE.
- **Implementation:** `lib/shared/vlm/cloud_vlm_provider.dart` → `backend/main.py`.
- **Preferred for:** Scene description (`describeScene`) and spoken visual Q&A (`askImage`).
- **Fallback chain:** If the local tier is unavailable, `ModelRouter` promotes cloud. If cloud is unreachable, a `VlmSource.unavailable` response is returned.

---

## Flutter Application Structure

```
lib/
├── main.dart                       # Entry point — calls bootstrap
├── app/
│   ├── bootstrap.dart              # Async init, DI wiring
│   └── wareny_app.dart             # MaterialApp root, theme, locales
├── core/
│   ├── config/app_config.dart      # Environment config (dev / prod)
│   ├── di/                         # InheritedWidget DI container + ServiceRegistry
│   ├── emergency/                  # Shake detector, GPS, contact model, controller
│   ├── localization/               # All user-facing strings (en / ar)
│   └── theme/                      # Color palette, spacing, Material theme
├── presentation/                   # Screens, controllers, overlay widgets
│   ├── camera/                     # Raw camera preview surface
│   ├── emergency/                  # 5-second countdown overlay
│   ├── navigation/                 # Root shell + AppMode enum
│   ├── navigation_mode/            # Real-time obstacle detection HUD
│   ├── onboarding/                 # First-launch emergency contact setup
│   ├── read/                       # Document/text reading + speech queue
│   ├── settings/                   # Language, speech rate, contacts
│   ├── stuff_finder/               # Object search + COCO picker
│   └── reusable/                   # Shared widgets (top bar, carousel, gestures)
└── shared/                         # Infrastructure — no UI
    ├── bridges/                    # Platform channel adapters (Dart side)
    ├── navigation/                 # Risk engine, feedback, models
    ├── object_detection/           # Detection models, coordinate mapper
    └── vlm/                        # VLM assistant, providers, router, prompts
```

---

## Backend Structure

```
backend/
├── main.py             # FastAPI app — /vlm/generate, /health, /app-config, /model-manifest
├── requirements.txt    # fastapi, uvicorn[standard], httpx, pydantic, python-dotenv
├── .env.example        # Environment variable template
├── README.md           # Backend usage guide
└── HOSTING.md          # Production deployment options (Ollama / vLLM / llama.cpp)
```

---

## Tech Stack Summary

| Layer | Technology | Version |
|---|---|---|
| Mobile framework | Flutter (Dart) | SDK ^3.12.0 |
| Local CV | YOLOv8 / LiteRT (`ultralytics_yolo`) | ^0.6.2 |
| Local VLM | MediaPipe LLM Inference / Gemma | Phase F |
| Cloud VLM runtime | Ollama + Gemma 4 (`gemma4:e4b`) | — |
| Backend framework | Python FastAPI + uvicorn | — |
| Backend HTTP client | httpx (async) | — |
| Text-to-speech | flutter_tts | ^4.0.2 |
| Shake / motion | sensors_plus | ^6.1.0 |
| GPS | geolocator | ^13.0.2 |
| Persistence | shared_preferences | ^2.2.0 |
| Permissions | permission_handler | ^11.4.0 |
| Emergency calling | flutter_phone_direct_caller | ^2.0.1 |
| Image encoding | image (Dart) | ^4.3.0 |
| Native bridges | Flutter Platform Channels (Kotlin / Swift) | — |

---

## Platform Channel Map

All platform channel names are defined in `lib/shared/bridges/native_bridge_channels.dart`.

| Channel name | Direction | Purpose |
|---|---|---|
| `com.wareeny.bridge/camera` | Dart → Native | Camera permission and session |
| `com.wareeny.bridge/object_detection` | Dart ↔ Native | YOLO control (start/stop) |
| `com.wareeny.bridge/object_detection_events` | Native → Dart | Streaming detection frames |
| `com.wareeny.bridge/audio_haptics` | Dart → Native | TTS and haptic vibration |
| `com.wareeny.bridge/battery_thermal` | Native → Dart | Device thermal state |
| `com.wareeny.bridge/file_download` | Dart → Native | On-device model downloads |
| `com.wareeny.bridge/local_ai_runtime` | Dart ↔ Native | MediaPipe LLM control |
| `com.wareeny.bridge/local_ai_runtime/stream` | Native → Dart | Streamed VLM token deltas |
| `com.wareeny.bridge/emergency` | Dart → Native | SMS dispatch via SmsManager |
| `com.wareeny.bridge/ocr` | Reserved | Future Arabic OCR (iOS Vision / ML Kit) |

---

## Dependency Injection

`AppScope` (an `InheritedWidget`) holds a single `ServiceRegistry` instance, initialized in `bootstrap.dart`. All screens access shared services via `AppScope.of(context)`. There is no third-party DI framework.

---

## Feedback Priority

When multiple events compete for the speaker, the feedback engine applies this priority order (highest → lowest):

1. **Danger** — immediate obstacle in walking path (interrupts everything)
2. **Obstacle / caution** — object partially in path
3. **Navigation cue** — path clear (throttled to avoid spam)
4. **VLM result** — spoken VLM answer
5. **Detection label** — object class announcement

---

## Key Architectural Rules (from RULES.md)

- Real-time CV never routes through the VLM pipeline.
- Only one heavy inference mode (CV or VLM) runs hot at a time.
- The UI event loop never blocks on inference.
- Feedback priority: danger > obstacle > nav cue > VLM result > label.
- On-device VLM stays unloaded until a task requires it.
- Native bridges are stable contracts — API changes require coordinated Dart + native updates.
