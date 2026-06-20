# Wareeny Feature Roadmap

This roadmap reorganizes Wareeny around a **vision-language model (VLM) assistant** core. The app
should feel like a personal assistant, not a robot: it *sees the image*, understands context, and
says only what matters — read the sign, not every pixel of text; summarize a page; name the thing
in your hand. Only hard real-time safety stays on fast local computer vision.

## Architecture In One Picture

Wareeny runs on three tiers:

- `Tier 1 — Realtime local CV`: obstacle, traffic light, danger-word/sign alerts, and the finder
  features. Frame-rate, worker-thread, never blocks the UI, never calls the VLM.
- `Tier 2 — On-device VLM`: `Gemma 4` via MediaPipe LLM Inference. Reading and the unified scan
  (object / money / brand / label). Private and offline-capable. Image + task prompt → natural
  spoken answer.
- `Tier 3 — Cloud VLM`: hosted Gemma (same family). Scene Q&A, heavier reasoning, and the fallback
  for Tier 2.

The other parts of the app are supporting services that plug into these tiers:

- `Feedback and Interaction Service`: speech, haptics, priority queue, audio focus, directional cues.
- `Safety and Alert System`: danger mode, emergency call, danger-word alerts, critical overrides.
- `System Controller`: mode manager, model router, permission handler, battery/thermal throttling.
- `Presentation Layer`: voice command UI, camera preview, overlays, current-mode indicator, alerts.
- `Data Layer`: saved items, emergency contacts, privacy settings, item logs, local model files.
- `Backend`: cloud VLM route, app config, model manifest, storage sync if needed.

## Stack

- `Flutter` shell: mode selection, settings, accessibility-first controls, lightweight overlays only.
- Native bridges in `Kotlin` and `Swift`: camera stream, mic, speaker routing, haptics, battery and
  thermal signals, background download services.
- `LiteRT` (TensorFlow Lite) for local CV detectors.
- `MediaPipe LLM Inference` running `Gemma 3n E4B` for the on-device VLM.
- `SQLite` plus encrypted local files for settings, saved items, contacts, logs, and the model
  registry.

Runtime services: `ModeManager`, `VlmAssistant`, `ModelRouter`, `LocalVlmProvider` /
`CloudVlmProvider` (behind one `VlmProvider`), `InferenceOrchestrator` (realtime CV loop),
`FeedbackEngine`, `ModelManager`, `ThermalBatteryController`.

## Runtime And Performance

Three isolated loops, none allowed to block another:

- `UI loop`: Flutter only — never blocked by inference, download, OCR, or network.
- `camera / inference loop`: native, throttled, mode-aware, worker-thread isolated.
- `feedback loop`: priority queue for speech and haptics, with interruption and dedup.

Smoothness and battery rules:

- only one heavy mode runs hot at a time
- sample frames instead of processing every frame; reduce inference resolution for navigation and
  obstacle detection; full-resolution capture only for VLM tasks
- keep the local VLM unloaded until needed; park inactive heavy models
- suppress repeated announcements with cooldown windows
- shrink prompt context before local generation; avoid continuous network polling
- downshift workload and disable nonessential overlays on low battery or thermal pressure

Device capability classes gate the on-device VLM:

- `High`: strongest local model option visible
- `Medium`: lighter local model option visible
- `Low`: local model install hidden or strongly warned

Capability checks: free storage, RAM class, available acceleration path, thermal headroom, recent
warmup benchmark.

Local model install flow: download into temp → verify checksum → move into encrypted model
directory → write registry metadata into SQLite → run warmup benchmark → mark usable or unsupported.

## Why This Redo

The previous roadmap built each feature as a deterministic pipeline. Phase 6 shipped a literal
ML Kit OCR → TTS reader that dumps every text block in frame — accurate but robotic. The shift:
**every non-realtime feature is driven by the VLM** so behavior is context-aware and conversational.
Fast safety logic stays local and deterministic where latency and reliability are non-negotiable.

### Confirmed Design Decisions

- **Hybrid routing by task.** On-device VLM for private/light tasks (reading, scan);
  cloud Gemma for scene Q&A and heavy reasoning. The router picks per task and network
  state, with fallback in both directions.
- **Full-VLM reading.** ML Kit is removed. If no local model **and** no network, reading is
  unavailable and the app says so (install a model or connect). No literal-OCR fallback.
- **One-shot voice Q&A.** A spoken question yields a single VLM answer about the current frame. No
  conversation memory in v1.
- **VLM scope:** document/scene reading, unified scan (object / money / brand / label).
- **Realtime local CV stays:** obstacle, traffic light, danger-word alerts, and the finders
  (stuff / lost-item / outdoor). These never call the VLM.
- **Assistant-first delivery.** Build the VLM assistant core first as the demo headline; realtime
  CV safety second.

## The VLM Assistant Core

A single service, `VlmAssistant`, is the entry point for *image + task → spoken result*. It replaces
the ad-hoc OCR controller logic.

- `VlmTask` enum: `scan`, `read`, `describeScene`, `askImage`. The `scan` task is the unified
  one-tap identifier — it subsumes what were once separate in-hand / currency / brand tasks: a single
  capture and prompt let the model decide whether it is looking at money (total + breakdown), a
  packaged product (read off the label), a sign/label (gist), or a generic object.
- **Per-task prompt templates are the headline deliverable.** This is where "not robotic" lives.
  Each task ships a tuned system prompt — for example: *"You are the eyes of a blind user. Look at
  this image and say only what a sighted person would find relevant in this context. Be concise and
  spoken-style. Do not enumerate everything."* Prompts are documented and version-controlled.
- `VlmRequest{ imagePath, task, userQuestion? }` → `VlmResponse{ spokenText, source, latency }`.
- Routes through `ModelRouter` to a `LocalVlmProvider` or `CloudVlmProvider`.
- **Streams tokens** so speech starts as generation flows — no dead silence. A short "thinking"
  earcon covers first-token latency.

### Model Router (task-aware)

- `scan`, `read` → **local-preferred**; cloud fallback if the local model is
  missing or unsupported and network is present; if neither, return `unavailable` (the accepted gap).
- `askImage`, `describeScene` → **cloud-preferred** (heavy reasoning); local fallback when offline.

## Module Mapping

| Feature | Tier | Supporting Services |
| --- | --- | --- |
| Document Reading | VLM | feedback, camera capture, model router |
| Scan (object / money / brand / label, one tap) | VLM | feedback, camera capture, model router |
| Scene Describe | VLM (cloud-pref) | feedback, camera capture |
| Ask-Image Q&A (one-shot) | VLM (cloud-pref) | STT, feedback, camera capture |
| Obstacle Avoidance | Realtime CV | safety alerts, haptics, battery controller |
| Traffic Light Status | Realtime CV | safety alerts, outdoor mode, speech |
| Danger Word / Sign Alerts | Realtime CV | safety alerts, priority queue |
| Stuff Finder | Realtime CV | finder rules, directional audio, item log |
| Lost Item Finder / Saved Items | Realtime CV | local storage, reference images, feedback |
| Outdoor Object Finder | Realtime CV | finder rules, feedback, current mode UI |
| Emergency Auto Call | Supporting | danger mode, contacts, location |
| Backend And Storage | Supporting | cloud VLM route, config, persistence |

## Delivery Strategy

Build the assistant first to get a demoable headline early, then add the remaining VLM tasks,
voice, the feedback/mode backbone, realtime safety, model lifecycle, and finally backend and
release hardening.

## Phase A: VLM Core + Reading

**Replaces the old Phase 6 OCR core.**

Goal: stand up the VLM assistant and ship context-aware reading as the headline feature.

Module: `VLM`

### Task List

- create `lib/shared/vlm/`: `VlmAssistant`, `VlmTask`, `VlmRequest`/`VlmResponse`, `VlmProvider`,
  `ModelRouter`, `LocalVlmProvider`, `CloudVlmProvider`
- write per-task prompt templates for `read` and `describeScene`; document them
- extend `LocalAiRuntimeBridge` for image input and token streaming
- implement `LocalVlmProvider` against MediaPipe LLM Inference (Android `tasks-genai`; iOS path)
- implement `CloudVlmProvider` over HTTP/SSE to `POST /vlm/generate`
- implement task-aware `ModelRouter` with the local/cloud fallback order above
- create `VlmReadController` replacing `OcrController`; reuse capture flow and `OcrControlsBar`
- emit framing guidance as natural language ("move closer, I can't read it"), not confidence cues
- stream tokens to TTS; play a "thinking" earcon until first token
- delete the ML Kit path: `ocr_bridge.dart`, `ocr_service.dart`, `ocr_models.dart`,
  `ocr_controller.dart`; remove `google_mlkit_text_recognition` from `pubspec.yaml`
- register new services in `ServiceRegistry`
- log VLM latency, chosen source tier, and token-stream start time
- test on one Android phone and one iPhone

Deliverables:

- working `VlmAssistant` + task-aware router
- context-aware reading (sign vs document vs label) with streaming speech
- safe `unavailable` behavior when no model and no network

## Phase B: Unified Scan (object / money / brand / label)

Goal: ship one capture-and-identify mode that covers what were once separate in-hand, currency, and
brand tasks, by reusing the Phase A pipeline. One tap → one VLM call → one spoken sentence; the model
decides the answer shape.

Module: `VLM`

### Task List

- add a single `scan` `VlmTask` whose prompt branches by what is in view (money / packaged product /
  document-or-sign / generic object). The old `inHand` / `currency` / `brand` tasks are **not** added
  separately — the merged `scan` prompt covers all three (scope-protection: no per-feature pipelines)
- wire `AppMode.scan` into `AppMode` and `navigation_shell.dart` (replaces the empty `inHand` stub)
- reuse the capture + stream + speak pipeline (`VlmReadController.scan`); only the prompt differs
- money: state the **total in EGP plus breakdown** ("250 pounds: a 200 and a 50"). The prompt embeds
  an EGP denomination cheat-sheet (colour / mosque / polymer-vs-paper) and tells the model to read
  printed numerals first; cheat-sheet is the tiebreaker (100 vs 200 is the risky pair)
- brand: read the packaging text (brand + product name + variant + size), never guess from logo memory
- confidence-aware wording ("this looks like…") and unknown handling
- retire the planned `/in-hand/detect` endpoint — identification is now `VlmTask.scan`
- backend `NUM_PREDICT_SCAN` raised to 200 (a money total + breakdown needs more than a one-liner)
- test with personal objects, supported banknotes (incl. polymer 10/20), and product packaging

Deliverables:

- one-tap Scan mode identifying objects, money (total + breakdown), and products through the shared
  VLM pipeline

## Phase C: Voice Q&A + Scene Describe

Goal: add the personal-assistant voice layer (one-shot) and a scene-description action.

Module: `VLM`

### Task List

- add STT via `speech_to_text` for the `ask` mode
- one-shot flow: voice question → capture frame → `VlmTask.askImage` (cloud-preferred) → speak
- no conversation memory in v1
- add `VlmTask.describeScene` for a "what's in front of me" action
- handle no-speech, timeout, and offline-no-cloud states gracefully

Deliverables:

- one-shot voice Q&A about the current frame
- scene description action

## Phase D: Feedback Engine + Mode Manager

Goal: build the feedback and mode backbone, pulled early because streaming VLM speech must yield to
safety interrupts.

Modules: supporting services for `VLM` and `Realtime CV`

### Task List

- implement `FeedbackEngine` with a priority queue, interruption, dedup, and cooldown
- priority order: danger, obstacle, navigation cue, VLM result, general label
- implement `ModeManager` so only one heavy mode runs at a time
- stop camera, VLM workers, and detectors when leaving a mode
- route all speech and haptics through the feedback loop
- voice command UI for switch mode, stop, repeat, scan, ask, call emergency

Deliverables:

- priority feedback loop with safety interruption
- single-heavy-mode mode controller

## Phase E: Realtime CV Safety + Finders

Goal: deliver the deterministic local safety features and finders that must never wait on a VLM.

Module: `Realtime CV`

### Task List

- integrate a local detector (YOLO/LiteRT) behind a `Detector` interface
- obstacle avoidance with danger-zone and proximity rules + haptics
- traffic light status (red, yellow, green, unknown)
- danger word / sign alerts routed to the highest feedback priority
- finders: stuff finder, lost-item finder (saved items + reference images), outdoor finder
- directional audio for target and hazard locations
- separate indoor and outdoor detection settings; verify mode switching
- tune frame sampling; test low light, bright light, and moving-camera scenes
- log detection latency and false-alert rate

Deliverables:

- obstacle, traffic light, and danger-sign safety
- saved items and the three finder modes

## Phase F: On-Device Model Lifecycle

Goal: manage download, verification, and resource use of the local VLM.

Modules: `System Controller`

### Task List

- local model install: download → checksum → encrypted store → SQLite registry → warmup → mark
  usable/unsupported (reuse `file_download_bridge.dart`)
- device capability classes (High / Medium / Low) from storage, RAM, acceleration, thermal headroom
- onboarding offer to install the on-device VLM, with capability-based guidance
- keep the local VLM unloaded until needed; park it when idle
- battery and thermal hooks via `battery_thermal_bridge.dart`; downshift sampling under pressure

Deliverables:

- managed on-device model lifecycle
- capability-aware install and battery/thermal downgrade behavior

## Phase G: Backend, Storage, And Release

Goal: finish the thin backend, local persistence, safety flows, and release hardening.

Modules: supporting services

### Task List

- FastAPI `POST /vlm/generate`: multimodal image + task, SSE streaming, routed to hosted Gemma
- keep `GET /health`, `GET /app-config`, `GET /model-manifest`; drop `/in-hand/detect`
- store backend URLs, feature flags, model and routing thresholds in app config
- local cache for last good config and model manifest
- SQLite schema: settings, saved items, item logs, emergency contacts, model registry, privacy prefs
- store saved-item reference images in protected local app storage
- emergency auto call + location sharing + danger-mode activation (voice / gesture / shake)
- backend timeout, retry, and offline behavior; ensure CV/safety still work fully offline
- privacy rules for images sent to the cloud VLM
- deploy backend; test from a real phone network
- final known-issues list and demo script

Deliverables:

- deployed backend with the streaming VLM route
- local storage and persistence
- emergency and danger-mode flows
- safe offline behavior and a demo-ready release candidate

## Definition Of Done For The Graduation Build

The build is done when all of these work on real phones:

- VLM tasks (scan, read, scene describe, ask-image) run through one shared
  `VlmAssistant` with task-aware routing
- reading is context-aware (sign vs document vs label), with streaming speech and a "thinking" earcon
- only one heavy mode runs at a time
- results are delivered through speech and haptics without freezing the UI
- danger, obstacle, and navigation feedback interrupt VLM speech and have priority
- one-shot voice Q&A returns a relevant answer about the current frame
- obstacle, traffic light, danger-sign safety and the finder modes run on local CV
- emergency contact and danger mode are configured and testable
- the cloud VLM route is reachable and fails safely; CV/OCR-free safety still works offline
- local storage persists settings, saved items, emergency contacts, logs, and model metadata
- battery and thermal downgrade rules are active

## Daily Checklist

1. test at least one feature on a real phone
2. verify camera preview stays smooth
3. verify only one heavy mode remains active
4. confirm streaming VLM speech starts quickly and can be interrupted by safety alerts
5. watch logs for repeated feedback spam
6. record one latency, source-tier, battery, or thermal observation
7. confirm VLM tasks share `VlmAssistant` and safety stays on local CV

## Scope Protection Rules

Keep the build focused on the VLM-assistant core plus local safety.

Keep:

- the `VlmAssistant` core and its task prompts
- realtime CV safety and finders
- feedback and mode backbone
- backend and storage needed by the above

Avoid re-introducing per-feature deterministic pipelines for tasks the VLM already covers
(reading, scan — i.e. object / money / brand / label). Avoid standalone AI modules for what are
supporting services (safety alerts, voice commands, privacy suppression, storage).

If time slips, protect these demo-critical features first:

- context-aware reading
- scan: object / money (total + breakdown) / product
- one-shot voice Q&A
- obstacle avoidance
- danger mode and emergency contact
- cloud VLM health and the streaming generate route

## Recommended Ownership Split

- `Person 1`: VLM core, model router, providers, prompt templates, reading
- `Person 2`: unified scan task (object / money / brand / label), voice Q&A, scene describe
- `Person 3`: feedback engine, mode manager, voice commands, safety, battery/thermal hooks
- `Person 4`: realtime CV detector, finders, backend, storage, deployment, integration testing
