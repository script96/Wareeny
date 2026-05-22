# Wareeny Delivery Roadmap

This roadmap is optimized for:

- less than one month remaining
- a small team working in parallel
- an offline-first app with a thin backend
- one existing remote in-hand detector
- smoothness and battery efficiency as top priorities

## Delivery Strategy

Ship in layers, not all at once.

- `Layer 1`: foundation and critical path
- `Layer 2`: local CV and OCR flows
- `Layer 3`: Gemma routing and optional local model install
- `Layer 4`: polish, profiling, and fallback hardening

## Definition Of Done For The Graduation Build

The build is done when all of the following work on real phones:

- indoor or outdoor mode can run smoothly without visible UI lag
- obstacle-related feedback is local and responsive
- read mode can OCR and speak text
- cloud LLM path works through `Gemma 4 E4B`
- if internet is unavailable and a local model is installed, LLM tasks switch to local automatically
- the in-hand mode works through the deployed Python server
- battery and thermal downgrade rules are applied

## Critical Path

These items must start first because everything else depends on them:

1. mobile project setup and architecture skeleton
2. backend deployment skeleton
3. one real phone benchmark baseline
4. model routing contract lock
5. camera and inference loop integration

## Team Lanes

Use 4 working lanes in parallel:

- `Lane A`: mobile shell, state, settings, routing UX
- `Lane B`: native performance layer, camera, downloads, thermal and battery hooks
- `Lane C`: CV and OCR features
- `Lane D`: backend, Gemma cloud path, in-hand service integration

## Phase 1: Foundation And Architecture Lock

Goal: remove uncertainty and create the base that everything else will build on.

### 1. Create the Flutter app shell

Subtasks:

- initialize the Flutter project structure
- create environment/config support for dev and prod values
- add navigation shell with placeholder screens for:
  - home
  - indoor mode
  - outdoor mode
  - read mode
  - ask mode
  - in-hand mode
  - settings
- add shared theme and accessibility-safe UI defaults
- add app-level dependency injection or service registration

### 2. Create Android and iOS native bridge placeholders

Subtasks:

- create one bridge module for camera
- create one bridge module for audio and haptics
- create one bridge module for battery and thermal signals
- create one bridge module for file download
- create one bridge module for local AI runtime integration
- define method-channel or FFI contract names clearly

### 3. Wire local config consumption from backend contracts

Subtasks:

- create config models matching `GET /app-config`
- create manifest models matching `GET /model-manifest`
- add a config fetch service
- add caching for last successful config and manifest
- add safe fallback values if the backend is unavailable

### 4. Stand up the backend locally

Subtasks:

- create local virtual environment
- install requirements
- run the FastAPI backend locally
- verify all current endpoints return valid responses
- add example `.env` file with placeholder values

### 5. Freeze the first-release feature list

Subtasks:

- mark features as:
  - must have
  - should have
  - optional
- confirm which modes are demo-critical
- remove any advanced feature that does not support the final demo or grading goal

### 6. Pick and lock test devices

Subtasks:

- choose at least one Android phone
- choose at least one iPhone
- document RAM, storage, OS version, and chipset if possible
- use those devices as the baseline for smoothness decisions

### 7. Run baseline measurements

Subtasks:

- measure camera preview smoothness
- measure CPU and memory usage during a simple preview session
- measure thermal rise after a short camera session
- note battery drain trend during repeated use
- write down acceptable target thresholds

Deliverables:

- mobile app skeleton
- backend running locally
- routing and config models locked
- benchmark note with test devices

## Phase 2: Real-Time Runtime Path

Goal: get the core camera and mode system alive early.

### 1. Integrate camera preview with throttled frame sampling

Subtasks:

- connect native camera preview to the app screen
- create frame sampler logic
- make sampler configurable by mode
- ensure preview remains smooth while frames are sampled
- log effective sample rate

### 2. Add `ModeManager`

Subtasks:

- create mode enum and current-mode store
- add enter and exit handlers for each mode
- ensure exiting one mode stops its workers cleanly
- ensure only one heavy mode can be active at a time
- add debug logging for mode transitions

### 3. Add `FeedbackEngine` skeleton

Subtasks:

- create feedback event model
- create priority queue structure
- support speech events and haptic events
- allow high-priority interruption
- add basic deduplication key support

### 4. Add local detector interface

Subtasks:

- create common detector input/output models
- define async detector lifecycle:
  - load
  - infer
  - unload
- create one placeholder implementation for testing
- expose latency logging on each inference call

### 5. Add OCR mode entry flow

Subtasks:

- create read mode UI state
- connect capture button or trigger action
- route captured image into OCR pipeline placeholder
- display and speak placeholder OCR output

### 6. Deploy backend skeleton

Subtasks:

- create Cloud Run service
- set environment variables
- deploy the FastAPI app
- verify health endpoint remotely
- verify app-config and manifest endpoints remotely

### 7. Connect the in-hand proxy shape

Subtasks:

- confirm request format expected by your existing server
- confirm response keys returned by the server
- adapt `POST /in-hand/detect` proxy if needed
- test success case and failure case

### 8. Define battery and thermal thresholds

Subtasks:

- choose low-battery threshold
- choose thermal-degrade threshold
- place thresholds in backend config
- make app read thresholds on startup

Deliverables:

- camera loop working
- mode isolation working
- backend reachable from app
- in-hand proxy contract confirmed

## Phase 3: Local CV And OCR Core

Goal: make local assistance features usable on-device.

### 1. Integrate first local CV model

Subtasks:

- choose first detector to prioritize
- prepare model file and metadata
- add native runtime loading path
- connect inference output to shared detector result model
- surface bounding or label results to the app
- measure latency on real device

### 2. Add result deduplication and cooldown logic

Subtasks:

- create repeated-result suppression rules
- define cooldown window per result type
- suppress duplicate speech across adjacent frames
- keep danger results exempt or lightly throttled

### 3. Integrate OCR using platform-native stack

Subtasks:

- connect Android OCR path
- connect iPhone OCR path
- normalize OCR output into one shared model
- handle Arabic and English text safely
- log OCR latency and output size

### 4. Make read mode capture and speak text

Subtasks:

- connect OCR result to speech output
- split long text into readable chunks
- add stop, repeat, and cancel behavior
- ensure speech does not freeze the UI

### 5. Add thermal and battery controller hooks

Subtasks:

- read battery level from native side
- read thermal state from native side
- expose these signals to runtime controllers
- lower frame rate when thresholds are crossed
- disable nonessential overlays when needed

### 6. Add event logging for performance inspection

Subtasks:

- log mode changes
- log inference start and end times
- log OCR duration
- log feedback queue events
- log thermal downgrade events

### 7. Tune frame rate by mode

Subtasks:

- choose high-sample rate for navigation mode
- choose lower-sample rate for read mode
- verify each mode still feels responsive
- record final chosen values

Deliverables:

- first local CV feature on device
- OCR read mode working
- battery and thermal hooks active

## Phase 4: Cloud LLM And In-Hand End-To-End

Goal: complete the connected cloud features without hurting smoothness.

### 1. Integrate `POST /llm/generate`

Subtasks:

- create app-side LLM client
- create request and response models
- add timeout handling
- add cancellation support
- add retry policy for safe failure cases

### 2. Connect Ask flow to cloud `Gemma 4 E4B`

Subtasks:

- create ask mode UI
- define prompt-building logic
- add support for plain text question flow
- add support for OCR-context question flow
- display and speak answer result

### 3. Add routing preference setting

Subtasks:

- add settings options:
  - auto
  - prefer cloud
  - prefer local
- persist the setting locally
- make router read the setting before each LLM task

### 4. Connect in-hand mode end-to-end

Subtasks:

- create in-hand mode UI
- capture image or short burst for upload
- call `POST /in-hand/detect`
- parse result
- speak result
- handle no-result and timeout states

### 5. Keep cloud tasks non-blocking

Subtasks:

- run all LLM requests async
- run all in-hand requests async
- prevent network calls from blocking camera preview
- show progress states without freezing controls

Deliverables:

- ask flow working with cloud model
- in-hand feature working phone to server
- network tasks do not block UI

## Phase 5: Local Model Install And Offline Fallback

Goal: make the optional on-device LLM path real and reliable.

### 1. Add device capability assessment

Subtasks:

- inspect free storage
- estimate RAM class
- detect acceleration availability if exposed
- record thermal and performance benchmark results
- map device to:
  - high
  - medium
  - low

### 2. Show eligible local model options

Subtasks:

- read device tier
- read backend model manifest
- filter eligible models for platform and tier
- show installable options in settings
- hide or warn on unsupported installs

### 3. Implement model download flow

Subtasks:

- add Android `DownloadManager` integration
- add Android `WorkManager` coordination if needed
- add iPhone background download integration
- create progress reporting
- add pause or resume support if feasible

### 4. Verify checksum and write local registry metadata

Subtasks:

- compute SHA-256 after download
- compare with manifest checksum
- move verified file to final storage
- write registry record with:
  - model id
  - path
  - tokenizer path if needed
  - checksum
  - install timestamp
  - usability state

### 5. Add warmup benchmark after install

Subtasks:

- load model once
- run one short prompt
- measure load time
- measure generation latency
- mark model usable or unsupported

### 6. Implement automatic routing fallback

Subtasks:

- detect internet availability at request time
- use cloud when online and allowed
- use local when offline and installed
- return offline-no-llm when neither path exists
- retry locally if cloud fails and local is available
- cache last known local model availability

Deliverables:

- optional local model install flow
- automatic offline fallback working
- local model availability cached

## Phase 6: Smoothness, Battery, And Thermal Optimization

Goal: make the system feel polished and safe to demo.

### 1. Measure hot-path latency in each mode

Subtasks:

- measure camera-to-detection latency
- measure OCR request-to-speech latency
- measure ask flow total response time
- measure in-hand round-trip time
- compare numbers across Android and iPhone

### 2. Reduce unnecessary overlays

Subtasks:

- remove overlays not needed for the visually impaired workflow
- disable debug overlays outside debug mode
- keep only essential state indicators

### 3. Unload inactive heavy models

Subtasks:

- detect mode exit
- unload model resources
- release memory where possible
- confirm no stale model stays active

### 4. Shorten local prompt context

Subtasks:

- keep only relevant OCR text
- keep only relevant object labels
- trim repeated history
- verify answers still remain useful

### 5. Add degrade rules

Subtasks:

- lower frame sampling on low battery
- lower frame sampling on thermal pressure
- reduce speech verbosity if necessary
- disable optional visuals in degraded state

### 6. Ensure local LLM never competes with live safety mode

Subtasks:

- pause or block local LLM start while hot safety mode is active
- cancel or postpone local LLM if danger mode starts
- document this behavior in code and logs

### 7. Tune feedback cooldown windows

Subtasks:

- inspect repeated warning patterns
- adjust cooldown by event type
- keep danger cues urgent
- reduce noise for repeated object labels

Deliverables:

- tuned runtime behavior
- improved battery and thermal handling
- smoother feedback behavior

## Phase 7: Stabilization And Demo Hardening

Goal: remove demo risk and freeze the build.

### 1. Run end-to-end test matrix

Subtasks:

- test indoor mode
- test outdoor mode
- test read mode
- test ask mode
- test in-hand mode
- test mode switching repeatedly

### 2. Test offline and fallback scenarios

Subtasks:

- test airplane mode with no local model
- test airplane mode with local model installed
- test cloud available then lost mid-session
- test local installed but marked unsupported

### 3. Test long-session stability

Subtasks:

- run long camera sessions
- monitor memory growth
- monitor thermal rise
- monitor feedback spam behavior

### 4. Test difficult inputs

Subtasks:

- low light OCR
- cluttered scene OCR
- noisy scene object detection
- in-hand timeout and failure paths

### 5. Fix only release-critical issues

Subtasks:

- remove crashes
- remove freezes
- remove wrong routing behavior
- remove broken fallbacks
- avoid risky refactors late in the cycle

### 6. Prepare demo and submission assets

Subtasks:

- write demo script
- prepare backup offline demo path
- capture screenshots
- export architecture diagrams
- prepare deployment env vars
- confirm backend health before demo

Deliverables:

- release candidate build
- demo-ready flow
- final known-issues list

## Daily Checklist

Every day:

1. test on at least one real phone
2. check UI smoothness after new changes
3. verify no heavy mode remains active after switching
4. watch logs for repeated feedback spam
5. measure one latency or battery metric

## Weekly Milestones

- `Milestone 1`: mobile and backend foundations are alive
- `Milestone 2`: local CV and OCR work on phone
- `Milestone 3`: cloud LLM, in-hand service, and local model install work
- `Milestone 4`: performance tuning, fallback hardening, and demo prep complete

## Scope Protection Rules

To finish in time, do not add new major features after the cloud and in-hand paths are working.

If the team slips:

- keep local safety CV
- keep OCR read mode
- keep cloud Ask flow
- keep in-hand server mode
- treat advanced polish and extra detectors as optional

## Recommended Ownership Split

- `Person 1`
  - Flutter shell
  - settings
  - routing UX
  - accessibility flow
- `Person 2`
  - camera loop
  - native bridges
  - downloads
  - battery and thermal hooks
- `Person 3`
  - local CV
  - OCR
  - feedback engine
- `Person 4`
  - backend
  - Gemma cloud route
  - in-hand integration
  - deployment
