<!-- PROJECT BANNER -->
<!-- TODO: Drop a real banner/logo here, e.g. docs/assets/banner.png (1280×320 recommended), then uncomment:
<p align="center">
  <img src="docs/assets/banner.png" alt="Wareeny — AI eyes for the blind" width="100%">
</p>
-->

<h1 align="center">👁️ Wareeny — وريني</h1>

<p align="center">
  <strong>An AI-powered mobile assistant that gives blind and low-vision users a pair of eyes.</strong><br>
  Point the camera. Wareeny <em>sees</em>, understands the context, and tells you only what matters.
</p>

<!-- ANIMATED TYPING TAGLINE (renders live on GitHub) -->
<p align="center">
  <a href="#-wareeny--وريني">
    <img src="https://readme-typing-svg.demolab.com?font=Fira+Code&weight=600&size=22&duration=3000&pause=900&color=02569B&center=true&vCenter=true&width=720&lines=Reads+the+sign%2C+not+every+pixel.;One+tap+to+count+money+%26+identify+products.;Real-time+obstacle+%26+danger+alerts.;Your+AI+eyes+%E2%80%94+in+English+%26+%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9." alt="What Wareeny does">
  </a>
</p>

<!-- SHIELDS.IO BADGES -->
<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.12+-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-3.12-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Python-3.10+-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/FastAPI-Backend-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/Gemma_4-VLM-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="Gemma 4">
  <img src="https://img.shields.io/badge/Ollama-Serving-000000?style=for-the-badge&logo=ollama&logoColor=white" alt="Ollama">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/Languages-English%20%7C%20العربية-orange?style=flat-square" alt="Languages">
  <img src="https://img.shields.io/badge/Accessibility-First-blueviolet?style=flat-square" alt="Accessibility First">
  <img src="https://img.shields.io/badge/Status-Complete-success?style=flat-square" alt="Status">
  <img src="https://img.shields.io/badge/License-Academic-lightgrey?style=flat-square" alt="License">
</p>

> **Wareeny** (Arabic: *وريني*, "show me") is a bachelor thesis project from **Future University in Egypt**.
> It reimagines assistive vision as a *conversational personal assistant* — not a robot that reads every
> pixel of text, but a companion that reads the sign, summarizes the page, names the thing in your hand,
> and shouts when there's danger.

---

## 📑 Table of Contents

- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Environment Variables](#environment-variables)
  - [Running Locally](#running-locally)
- [Usage](#-usage)
- [Contributing](#-contributing)
- [License](#-license)
- [Acknowledgements](#-acknowledgements)

---

## 🌟 About the Project

Most assistive apps treat the world as a wall of raw data — they dump every detected object or every
text block on screen and leave the user to sort it out. Wareeny takes a different stance:

> **It sees the image, understands the situation, and says only what a sighted person would find relevant.**

The app is built **accessibility-first** for total reliance on the camera, voice, speech, and haptics.
Every surface is screen-reader friendly (TalkBack / VoiceOver semantics), gestures are large and
forgiving (two-finger swipe between modes, hold-to-listen for voice commands), and the entire
experience is fully **bilingual — English and Arabic** — including spoken answers.

Under the hood, Wareeny runs a **three-tier intelligence stack** so the right brain handles each job:
hard real-time safety stays on fast, deterministic on-device computer vision, while everything that
needs *understanding* is driven by a vision-language model (VLM) — on-device first for privacy, cloud
as the heavy-lifting fallback.

<!-- SCREENSHOTS / GIFs — TODO: add real demo captures to docs/assets/ then uncomment:
<p align="center">
  <img src="docs/assets/screen-read.gif"   alt="Reading mode demo"   width="30%">
  &nbsp;
  <img src="docs/assets/screen-scan.gif"   alt="Scan mode demo"      width="30%">
  &nbsp;
  <img src="docs/assets/screen-navigate.gif" alt="Navigation demo"   width="30%">
</p>
-->

---

## ✨ Key Features

| Feature | What it does | Powered by |
| --- | --- | --- |
| 📖 **Context-Aware Reading** | Reads documents, signs, and labels — summarizes a page, reads a sign, with natural framing cues ("move closer, I can't read it"). | On-device VLM → cloud fallback |
| 🔍 **One-Tap Scan** | A single capture identifies objects, products (brand + name + size), and **money** (total in EGP + breakdown: *"250 pounds: a 200 and a 50"*). | On-device VLM |
| 🗣️ **Voice Q&A** | Ask a one-shot spoken question about what's in front of you and get a spoken answer. | STT → Cloud VLM |
| 🌆 **Scene Describe** | "What's in front of me?" — a natural description of the surroundings. | Cloud VLM |
| 🚧 **Obstacle & Navigation** | Real-time indoor/outdoor obstacle and path assistance with directional audio + haptics. | YOLO / TFLite |
| ⚠️ **Danger Detection** | Fast, deterministic alerts for hazards and danger signs — interrupts everything else. | On-device CV |
| 🧭 **Stuff Finder** | Find a specific object (COCO classes) with directional guidance as you sweep the camera. | YOLO / TFLite |
| 🆘 **Emergency Mode** | Shake-to-trigger emergency call + location sharing to saved contacts. | Sensors + Geolocation |
| 🔊 **Speech & Haptics** | A priority feedback queue: danger > obstacle > navigation > VLM result, with interruption & dedup. | TTS + Haptics |
| 🌍 **Bilingual & Accessible** | Full English/Arabic UI and spoken output; screen-reader semantics throughout. | Flutter a11y |

---

## 🏗️ Architecture

Wareeny is organized as three isolated, non-blocking tiers — fast safety never waits on a language
model, and the UI never freezes on inference:

```text
        ┌──────────────────────────────────────────────────────────┐
        │                   Flutter App (Dart)                       │
        │   Accessibility-first UI · Voice commands · Overlays       │
        └───────────────┬───────────────────────────┬──────────────┘
                        │                           │
        ┌───────────────▼────────────┐   ┌──────────▼───────────────┐
        │  Tier 1 — Realtime CV       │   │  Tier 2 — On-device VLM  │
        │  YOLO / TFLite (LiteRT)     │   │  Gemma 4 (private/offline)│
        │  Obstacles · Danger · Find  │   │  Read · Scan             │
        └─────────────────────────────┘   └──────────┬───────────────┘
                                                      │ fallback / heavy
                                          ┌───────────▼───────────────┐
                                          │  Tier 3 — Cloud VLM        │
                                          │  FastAPI + Ollama → Gemma 4│
                                          │  Scene Q&A · SSE streaming │
                                          └────────────────────────────┘
```

- **`ModelRouter`** picks providers per task: `scan`/`read` are *local-preferred* (private, offline),
  `askImage`/`describeScene` are *cloud-preferred* (heavier reasoning) — each with fallback in both directions.
- **`VlmAssistant`** is the single entry point for *image + task → spoken result*, streaming tokens
  so speech begins before generation finishes (a "thinking" earcon covers first-token latency).
- The **backend is intentionally thin** — it relays the app's tuned per-task prompt + image to the
  model and streams tokens back over Server-Sent Events. No task logic lives on the server.

---

## 🛠️ Tech Stack

### Frontend / Mobile
| Technology | Role |
| --- | --- |
| **Flutter** | Cross-platform mobile shell (Android & iOS) |
| **Dart** (`^3.12`) | Application language |
| **camera / flutter_tts / speech_to_text** | Camera stream, text-to-speech, speech-to-text |
| **sensors_plus / geolocator** | Shake detection & location for emergency mode |
| **permission_handler / url_launcher / flutter_phone_direct_caller** | Permissions, deep links, emergency calling |

### On-Device AI
| Technology | Role |
| --- | --- |
| **Ultralytics YOLO** | Real-time object / obstacle / finder detection |
| **TensorFlow Lite (LiteRT)** | Quantized on-device models (`int8` TFLite + CoreML `.mlpackage`) |
| **Gemma 4 (E4B)** | On-device vision-language model for reading & scan |

### Backend
| Technology | Role |
| --- | --- |
| **Python** (`3.10+`) | Backend language |
| **FastAPI + Uvicorn** | Cloud VLM service & SSE streaming |
| **httpx / Pydantic** | Async model relay & request validation |
| **Ollama** | Serves the vision-capable Gemma 4 model |

### Tooling & Deployment
| Technology | Role |
| --- | --- |
| **Kotlin / Swift** | Native bridges (camera, haptics, battery/thermal, downloads) |
| **shared_preferences** | Local settings & lightweight persistence |
| **flutter_lints** | Static analysis & code style |

---

## 📁 Project Structure

```text
wareeny/
├── lib/                       # Flutter app
│   ├── main.dart              # Minimal entry point
│   ├── app/                   # Bootstrap & root app setup
│   ├── core/                  # Config, DI, theme, localization, emergency
│   ├── presentation/          # Feature screens (home, navigation, scan,
│   │                          #   read, stuff_finder, voice, settings…)
│   └── shared/                # VLM, danger, navigation, object detection,
│                              #   camera & native bridges
├── backend/                   # FastAPI cloud VLM service (Ollama → Gemma 4)
├── assets/models/             # On-device models (int8 TFLite + CoreML)
├── android/ · ios/            # Native platform projects
├── test/                      # Unit & widget tests
└── docs/                      # Architecture, contracts & design notes
```

See [`RULES.md`](RULES.md) for the layering conventions behind this structure.

---

## 🚀 Getting Started

The project has two parts: the **Flutter app** (root) and the **cloud VLM backend** (`backend/`).
The app runs fully on-device for safety features; the backend powers cloud VLM tasks and fallback.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) `3.12+` (with Dart)
- Android Studio / Xcode for device builds
- A physical Android or iOS device with a camera (recommended over emulators)
- [Python](https://www.python.org/) `3.10+` *(backend only)*
- [Ollama](https://ollama.com/) *(backend only — serves the Gemma vision model)*

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/wareeny.git
cd wareeny

# 2. Install Flutter dependencies
flutter pub get

# 3. (Optional) Set up the cloud VLM backend
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
ollama pull gemma4:e4b                                # vision-capable Gemma
cp .env.example .env                                  # adjust if Ollama lives elsewhere
```

### Environment Variables

The app is configured at build time via `--dart-define` flags; the backend via a `.env` file.

**App (`--dart-define`):**

| Variable | Default (dev) | Description |
| --- | --- | --- |
| `APP_ENV` | `dev` | Environment profile (`dev` / `prod`) |
| `API_BASE_URL` | `http://localhost:8000` | Cloud VLM backend URL |
| `CLOUD_MODEL_ID` | `gemma4:e4b` | Cloud model identifier |
| `ENABLE_DIAGNOSTICS` | `true` | Verbose diagnostics & logging |

**Backend (`backend/.env`):**

| Variable | Default | Description |
| --- | --- | --- |
| `OLLAMA_URL` | `http://localhost:11434` | Where the Gemma model is served |
| `GEMMA_MODEL` | `gemma4:e4b` | Vision-capable Gemma tag |
| `APP_ENV` | `dev` | Reported by `/health` |

### Running Locally

**Start the backend** (from `backend/`):

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

**Run the app:**

```bash
# Dev profile (defaults to localhost backend)
flutter run --dart-define=APP_ENV=dev

# From a physical phone, point at your machine's LAN IP
flutter run --dart-define=APP_ENV=dev --dart-define=API_BASE_URL=http://<your-ip>:8000

# Production profile
flutter run --dart-define=APP_ENV=prod
```

> 💡 The on-device CV and safety features work fully **offline**. The backend is only needed for
> cloud VLM tasks (scene Q&A) and as a fallback when no local model is installed.

---

## 📱 Usage

Once running, the app opens to a camera-first interface controlled by gesture and voice:

1. **Switch modes** — two-finger swipe (or use the mode carousel) to move between
   **Home → Navigation → Stuff Finder → Scan → Read → Settings**.
2. **Read** — point at a document, sign, or label and Wareeny speaks a context-aware summary.
3. **Scan** — one tap to identify an object, product, or count money (EGP total + breakdown).
4. **Ask** — hold to listen, speak a question about the frame, and get a single spoken answer.
5. **Navigate** — get real-time obstacle and path guidance with directional audio and haptics.
6. **Emergency** — a configured shake gesture triggers an emergency call with location sharing.

All feedback is spoken and haptic, prioritized so that **safety alerts always interrupt** lower-priority
speech. Spoken output follows the app language (English or Arabic).

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! This is an academic project, so please:

1. Read [`RULES.md`](RULES.md) — the codebase conventions every contributor (and coding agent) follows.
2. Fork the repo and create a feature branch (`git checkout -b feature/amazing-feature`).
3. Keep accessibility front-and-center — every new surface must be screen-reader friendly.
4. Open a pull request with a clear description.

---

## 📄 License

This project was developed as a **bachelor thesis** at **Future University in Egypt** and is
distributed for **educational and academic use**. Please contact the authors before any commercial use.

---

## 🙏 Acknowledgements

- **Future University in Egypt** — academic home of this thesis project.
- [Google Gemma](https://ai.google.dev/gemma) & [Ollama](https://ollama.com/) — the VLM brain.
- [Ultralytics YOLO](https://github.com/ultralytics/ultralytics) & TensorFlow Lite — on-device vision.
- The blind and low-vision community, whose needs shaped every design decision.

<p align="center"><em>Built with ❤️ to help people see the world differently.</em></p>
