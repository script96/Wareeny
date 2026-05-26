# Wareeny Feature Roadmap

This roadmap is organized around the actual Wareeny feature set described in the thesis and the system architecture diagram.

Wareeny should be implemented as two main AI modules:

- `Object Detection Module`: real-time object, obstacle, traffic light, in-hand, saved item, and finder features.
- `OCR Module`: document reading, quick text scanning, outdoor reading, currency, brand, privacy, and danger-word features.

The other parts of the application are supporting services. They should not become separate user-facing AI modules. They must plug into the two AI modules above:

- `Feedback and Interaction Service`: speech, haptics, priority queue, audio focus, and directional cues.
- `Safety and Alert System`: danger mode, emergency call, danger-word alerts, and critical override payloads.
- `System Controller`: mode manager, permission handler, battery monitor, and runtime throttling.
- `Presentation Layer`: voice command UI, camera preview, visual overlays, current mode indicator, and danger alerts.
- `Data Layer`: saved items, emergency contacts, privacy settings, item logs, and offline AI model files.
- `Backend`: remote in-hand detection, app config, model manifest, cloud AI routes, and storage sync if needed.

## Delivery Strategy

Build the features in a sequence that creates a demoable app early, then deepens accuracy, safety, storage, and backend support.

1. Build one object detection feature end-to-end.
2. Add the special remote-backed in-hand feature.
3. Add saved/lost item workflows.
4. Add navigation and obstacle safety.
5. Add outdoor object and traffic-light support.
6. Add OCR reading flows.
7. Add OCR-specialized recognition and privacy features.
8. Integrate feedback, safety, controls, and runtime performance.
9. Finish backend, storage, configuration, and release hardening.

## Definition Of Done For The Graduation Build

The build is done when all of these work on real phones:

- object detection features run through one shared object detection pipeline
- OCR features run through one shared OCR pipeline
- only one heavy mode runs at a time
- results are delivered through speech and haptics without freezing the UI
- obstacle and danger feedback has priority over normal labels
- document, quick text, sign, currency, brand, and privacy OCR flows work
- stuff finder, in-hand detection, saved item finder, obstacle avoidance, outdoor detection, and traffic light status work
- emergency contact and danger mode flows are configured and testable
- backend endpoints are reachable and fail safely
- local storage persists settings, saved items, emergency contacts, logs, and model metadata
- battery and thermal downgrade rules are active

## Module Mapping

| Feature | Main Module | Supporting Services |
| --- | --- | --- |
| Stuff Finder | Object Detection | feedback, camera, mode manager, item log |
| What's In My Hand | Object Detection | backend proxy, feedback, capture/upload |
| Lost Item Finder / Saved Items | Object Detection | local storage, reference images, feedback |
| Obstacle Avoidance | Object Detection | safety alerts, haptics, battery controller |
| Indoor Navigation | Object Detection | directional audio, mode manager, feedback |
| Outdoor Object Detection | Object Detection | safety alerts, visual overlay, feedback |
| Outdoor Object Finder | Object Detection | finder rules, feedback, current mode UI |
| Traffic Light Status | Object Detection | safety alerts, outdoor mode, speech |
| Smart Framing | Object Detection + OCR | camera guidance, haptics, visual overlay |
| Document Reader | OCR | TTS, text chunking, repeat/stop controls |
| Quick Text Scanner | OCR | camera capture, speech, mode manager |
| Outdoor Reader | OCR | sign detection, text normalization, feedback |
| Currency Reader | OCR | local recognition, speech, item log |
| Brand Detector | OCR | label recognition, product feedback |
| Privacy Mode | OCR | sensitive text detection, safe suppression |
| Danger Word Alerts | OCR | safety alerts, priority queue |
| QA Mode | OCR | OCR context, LMM route, speech |
| Emergency Auto Call | Supporting Service | danger mode, contacts, location |
| Backend And Storage | Supporting Service | config, remote AI, persistence |

## Phase 1: Stuff Finder

Goal: deliver the first complete object detection feature and prove the shared object detection pipeline.

Module: `Object Detection`

### Task List

- create the stuff finder mode entry in the app mode list
- connect the live camera preview to the object detection pipeline
- define the target object selection flow
- create detector input and output models for labels, confidence, box, direction, and distance estimate
- integrate the first local YOLO/LiteRT detector path or a temporary detector adapter
- filter detections to the selected target object
- add directional feedback such as left, right, center, near, and far
- add haptic feedback for target proximity
- add cooldown rules so the same target is not spoken every frame
- show minimal visual overlay for debug and sighted testing
- log detection latency and selected target events
- test the feature on at least one Android phone and one iPhone if available

Deliverables:

- stuff finder screen or mode
- working shared object detection adapter
- spoken and haptic target guidance
- first latency baseline

## Phase 2: What's In My Hand

Goal: implement the special in-hand recognition feature while keeping it behind the same object detection interface.

Module: `Object Detection`

### Task List

- create the in-hand mode entry and camera capture flow
- guide the user to place the object in frame using speech or haptics
- capture a still image or short burst for analysis
- connect the app to `POST /in-hand/detect`
- adapt request and response models to the existing remote in-hand server
- normalize remote results into the shared object detection result model
- speak the best result with confidence-aware wording
- handle no object, multiple objects, timeout, and backend unavailable states
- prevent upload from blocking the camera UI
- add retry and cancel behavior
- log round-trip latency and failure reason
- keep a future `LocalInHandProvider` interface ready for later migration

Deliverables:

- in-hand mode end-to-end
- remote provider hidden behind a common interface
- safe failure messages when the server is unavailable

## Phase 3: Lost Item Finder And Saved Items

Goal: let users save personal items and find them later using the object detection module plus local storage.

Module: `Object Detection`

### Task List

- create saved item data model with name, label, reference image path, created date, and last found date
- add local storage for saved item records and reference images
- build the save-item capture flow
- allow the user to name an item by voice or text input
- create the lost item finder mode
- load saved item targets into the object detection pipeline
- match detections against saved item labels or reference metadata
- speak item direction and proximity
- update item log when an item is found
- add delete and rename behavior for saved items
- protect saved item images with local-only storage rules
- test with common personal objects in cluttered indoor scenes

Deliverables:

- saved item registry
- lost item finder mode
- local item log

## Phase 4: Obstacle Avoidance And Indoor Navigation

Goal: make the safety-critical indoor movement features local, fast, and prioritized.

Module: `Object Detection`

### Task List

- define obstacle classes such as chair, table, door, stairs, wall edge, and person
- define danger zones in the camera frame
- estimate rough distance or proximity level from bounding box size and position
- create obstacle alert rules for near, center, and moving hazards
- add indoor navigation mode
- detect key indoor navigation objects such as doors, stairs, elevators, and clear path cues
- route obstacle alerts through the highest feedback priority after danger mode
- add haptic patterns for immediate obstacles
- suppress low-priority object labels while obstacle avoidance is active
- tune sample rate for smooth real-time detection
- test in low light and cluttered indoor scenes
- document target latency for obstacle warnings

Deliverables:

- obstacle avoidance mode
- indoor navigation cues
- priority safety feedback

## Phase 5: Outdoor Detection, Outdoor Finder, And Traffic Lights

Goal: complete outdoor object detection features used for street and public-space assistance.

Module: `Object Detection`

### Task List

- create outdoor mode with object detection settings separate from indoor mode
- define outdoor obstacle classes such as car, bicycle, motorcycle, pole, curb, barrier, and person
- add traffic light status detection with red, yellow, green, and unknown states
- create outdoor object finder targets such as ATM, bench, trash can, bus stop, and entrance
- prioritize traffic and obstacle feedback over general object labels
- add directional audio for outdoor object locations
- lower speech verbosity to avoid overload in busy scenes
- add confidence thresholds per outdoor class
- tune frame sampling for outdoor scenes
- test in bright light, night light, and moving-camera conditions
- log outdoor detection latency and false alerts
- verify mode switching between indoor and outdoor detection

Deliverables:

- outdoor object detection
- traffic light status feedback
- outdoor object finder

## Phase 6: OCR Reading Core

**Status: Complete**

Goal: build the shared OCR pipeline and the main text reading experiences.

Module: `OCR`

### Task List

- create OCR input and output models for text blocks, language, confidence, bounding boxes, and reading order
- integrate platform OCR using Google ML Kit, EasyOCR, or the chosen native path
- normalize Arabic and English output into one text model
- support right-to-left reading order for Arabic
- create document reader mode
- create quick text scanner mode
- create outdoor reader mode for shop names, billboards, and street signs
- add smart framing guidance when text is not centered or too far away
- split long OCR text into speech-friendly chunks
- add stop, repeat, skip, and cancel controls
- log OCR latency and text length
- test printed documents, labels, menus, books, and outdoor signs

Deliverables:

- shared OCR pipeline
- document reader
- quick text scanner
- outdoor reader

### Notes

- Outdoor reader and Arabic OCR deferred — SCAN mode covers signs for now; Arabic needs a separate ML Kit script path (Phase 9)
- Added rule-based OCR noise filtering before TTS: drops blocks with >50% non-alphanumeric chars or duplicates, strips isolated symbols and separator runs (`---`, `===`)
- ML Kit returns `null` confidence mapped to `0.0` — added `> 0.0` guard so "blurry" cue doesn't fire on every scan
- `offCenter` framing cue removed — ML Kit bounding boxes are in image pixels, not logical points; caused constant false positives; needs image dimensions in `OcrResult` to fix properly
- Moved tap-to-capture handler to wrap camera layer only; wrapped visual overlays in `IgnorePointer` — otherwise every button tap triggered OCR

## Phase 7: Currency, Brand, Privacy, Danger Words, And QA

Goal: add the specialized OCR-based features that make the app useful in real daily tasks.

Module: `OCR`

### Task List

- implement currency reader for supported banknotes and denominations
- decide whether currency recognition uses OCR, image classification, or a hybrid local model
- speak currency value clearly and avoid repeated announcements
- implement brand detector for product labels and packaging text
- add brand confidence thresholds and unknown-brand handling
- implement privacy mode to detect sensitive text without speaking it aloud
- define sensitive categories such as phone numbers, addresses, IDs, payment cards, and personal names where possible
- implement danger word alerts for words such as danger, caution, wet floor, emergency, exit, and Arabic equivalents
- route danger words to the safety alert priority queue
- create QA mode using OCR text as context
- connect QA mode to the selected LMM route
- trim OCR context before sending to the model
- test Arabic and English documents with questions

Deliverables:

- currency reader
- brand detector
- privacy mode
- danger word alerts
- OCR-based QA mode

## Phase 8: Feedback, Safety, Controls, And Runtime Integration

Goal: integrate supporting services into the two AI modules and make the app feel safe, clear, and controlled.

Modules: `Object Detection` and `OCR`

### Task List

- implement `ModeManager` so only one heavy mode runs at a time
- stop camera, OCR, detector, upload, or LMM workers when leaving a mode
- implement `FeedbackEngine` with speech, haptics, priority, interruption, and cooldown
- define priority order: danger, obstacle, navigation cue, OCR result, LMM answer, general label
- add voice command UI for listening state and command parsing
- support commands such as switch mode, stop, repeat, scan, call emergency, and privacy mode
- add visual feedback UI for live camera preview, bounding boxes, text highlights, current mode, and danger alert popup
- implement danger mode activation by voice command, gesture, or shake
- add emergency auto call and location sharing flow
- implement directional audio cues
- add battery monitor and thermal monitor hooks
- downshift frame sampling during low battery or thermal pressure
- unload inactive heavy models
- add event logging for mode changes, feedback events, inference latency, OCR latency, and thermal downgrade
- test repeated mode switching and long camera sessions

Deliverables:

- integrated feedback and interaction service
- safety and alert system
- mode controller
- battery and thermal downgrade behavior

## Phase 9: Backend And Storage

Goal: finish the backend, configuration, local persistence, and release hardening that support the two AI modules.

Modules: supporting services for `Object Detection` and `OCR`

### Task List

- keep FastAPI as the thin backend service
- verify `GET /health`
- verify `GET /app-config`
- verify `GET /model-manifest`
- verify `POST /in-hand/detect`
- add or verify cloud LMM endpoint for OCR QA and visual questions if used
- store backend URLs and feature flags in app config
- include battery, thermal, model, and routing thresholds in app config
- add local cache for last successful config and model manifest
- create SQLite or local database schema for settings, saved items, item logs, emergency contacts, model registry, and privacy preferences
- store saved item reference images in protected local app storage
- store offline AI model files in a managed local model directory
- verify checksum before marking downloaded models usable
- add backend timeout, retry, and offline failure behavior
- ensure local object detection and OCR still work when the backend is unavailable
- add privacy rules for images sent to the backend
- prepare deployment environment variables
- deploy backend to the selected hosting target
- test backend from a real phone network
- write final known-issues list and demo script

Deliverables:

- deployed backend
- local storage schema and persistence
- config and manifest cache
- safe offline behavior
- demo-ready release candidate

## Daily Checklist

Every working day:

1. test at least one feature on a real phone
2. verify camera preview stays smooth
3. verify only one heavy mode remains active
4. check speech and haptic feedback priority
5. watch logs for repeated feedback spam
6. record one latency, battery, or thermal observation
7. confirm object detection and OCR still use their shared module interfaces

## Scope Protection Rules

The release should stay focused on the two-module architecture.

Keep:

- object detection module
- OCR module
- feedback and safety integration
- backend and storage needed by those modules

Avoid adding separate modules for features that can be integrated into object detection or OCR. For example, safety alerts, smart framing, privacy mode, voice commands, and storage are supporting services, not standalone AI modules.

If time slips, protect these demo-critical features first:

- stuff finder
- what's in my hand
- obstacle avoidance
- document reader
- quick text scanner
- currency reader
- danger mode and emergency contact
- backend health and in-hand endpoint

## Recommended Ownership Split

- `Person 1`: object detection features, finder modes, traffic lights, obstacle avoidance
- `Person 2`: OCR features, document reader, quick scanner, currency, brand, privacy, QA
- `Person 3`: feedback, voice commands, haptics, safety, mode manager, battery and thermal hooks
- `Person 4`: backend, storage, model manifest, config, deployment, integration testing
