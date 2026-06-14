# Features

Wareeny is a voice-first, camera-driven assistant. Users navigate entirely by audio and haptic feedback — no reading of the screen is required. This document describes every implemented user flow.

---

## App Modes

The app is organized into six modes, selectable by swiping left or right with two fingers. The current mode is announced via TTS on every switch.

| Mode | Internal enum value | Primary input |
|---|---|---|
| Home | `AppMode.home` | — (idle) |
| Navigation | `AppMode.navigation` | Continuous camera + YOLO |
| Stuff Finder | `AppMode.stuffFinder` | YOLO + target class |
| In-Hand | `AppMode.inHand` | Single capture + VLM |
| Read | `AppMode.read` | Single capture + VLM |
| Settings | `AppMode.settings` | Touch / TTS |

---

## Navigation Mode

**Files:** `lib/presentation/navigation_mode/`

### Purpose

Real-time obstacle detection and hazard alert for walking safety.

### Flow

1. The camera feed streams frames continuously.
2. Each frame is processed by on-device YOLOv8 (Tier 1 only — never VLM).
3. `DetectionCoordinateMapper` normalizes bounding boxes to `[0, 1]` space, accounting for rotation and mirroring.
4. `NavigationRiskEngine.assess()` classifies every detection:
   - Computes overlap between each bounding box and the trapezoidal walking path polygon.
   - Assigns `NavigationRisk.safe`, `caution`, or `danger`.
   - Determines which zone (`left`, `center`, `right`) the object occupies.
5. The highest-priority threat drives the feedback output.

### Feedback

| Risk level | Speech | Haptics | Cooldown |
|---|---|---|---|
| `danger` | Immediately interrupts all other speech. | Continuous pulse every 450 ms. | 4 s between speeches. |
| `caution` | Yields to danger. | Pulse every 900 ms. | 7 s between speeches. |
| Path clear | Only when transitioning from danger/caution to safe. | None. | 12 s between speeches. |

### Sub-modes

Switch with a two-finger swipe up/down:
- **Indoor** — tuned risk thresholds for hallways and rooms.
- **Outdoor** — broader path polygon for street/sidewalk navigation.

---

## Stuff Finder Mode

**Files:** `lib/presentation/stuff_finder/`

### Purpose

Help users locate a specific lost object by continuously scanning for it.

### Flow

1. User opens Stuff Finder mode.
2. `CocoObjectPicker` — a scrollable list of the 80 COCO classes — is announced via TTS as the user scrolls. User double-taps to select a target.
3. App confirms selection: "Searching for keys."
4. YOLOv8 runs continuously on the camera feed.
5. `StuffFinderController` filters detections for the target label.
6. On match:
   - TTS announces "Found [object]!"
   - `StuffFinderOverlay` draws bounding box on screen (visual aid for sighted assistants).
   - Haptic confirmation pulse.
   - 4-second cooldown before the next announcement to prevent repetition.

---

## In-Hand Mode

**Files:** `lib/presentation/` (handled via `VlmAssistant`)

### Purpose

Identify the object the user is physically holding.

### Flow

1. User raises the object toward the camera.
2. Double-tap triggers a single frame capture.
3. Haptic "thinking" cue starts.
4. `VlmAssistant` routes task `VlmTask.inHand` to local VLM (preferred) or cloud fallback.
5. Streamed token deltas are spoken via TTS as they arrive.
6. Complete response is spoken; haptic completion cue fires.

---

## Read Mode

**Files:** `lib/presentation/read/`

### Purpose

Read printed or on-screen text aloud — documents, signs, menus, packaging.

### Sub-modes

Switch with a two-finger swipe up/down:

| Sub-mode | VLM task | Token budget | Output style |
|---|---|---|---|
| SCAN | `VlmTask.scan` | 80 tokens | One sentence — key fact or gist. |
| READ | `VlmTask.read` | 1200 tokens | Full faithful reading of body text, skips page furniture. |

### Flow

1. User points camera at the document and double-taps.
2. `VlmReadController` captures the frame and starts a `VlmAssistant.generate()` stream.
3. Haptic "thinking" cue plays until the first token arrives.
4. `SpeechQueue` buffers streamed text chunks and speaks them sequentially — no overlapping utterances.
5. **In READ sub-mode only:** playback controls appear:
   - Play / Pause
   - Repeat (replay the last sentence)
   - Skip (discard remaining queue)
   - Cancel (stop generation and clear queue)
6. When the queue drains, the mode returns to idle and announces readiness.

### Language detection

If > 30% of the response codepoints are Arabic, TTS switches to Arabic voice (`ar-EG` preferred, `ar` fallback).

---

## Emergency SOS

**Files:** `lib/core/emergency/`

### Purpose

Allow a user in danger to silently trigger a call and SMS alert to their emergency contacts.

### Trigger

The device accelerometer is monitored continuously by `ShakeDetectorService`. A shake event is fired when acceleration exceeds **15 m/s²** for two or more consecutive samples.

### Countdown Flow

1. Shake detected → `EmergencyController` starts a 5-second countdown.
2. TTS counts down: "5… 4… 3… 2… 1…"
3. Haptic pulse syncs with each count.
4. `EmergencyOverlay` appears on screen with a cancel button.

### On Timeout (auto-trigger)

1. Direct phone call to the first emergency contact (or `112` if none configured).
2. SMS sent to all emergency contacts via the Android native bridge (`sms.send`).
3. On iOS: `sms:` URI launched via `url_launcher`.
4. Confirmation haptic and TTS: "Emergency alert sent."

### Cancellation

- Double-tap anywhere on the overlay, or
- The user says "cancel" (if STT is enabled in a future phase).
- Countdown stops; overlay closes; 30-second cooldown before the shake detector re-arms.

### First-Launch Onboarding

`EmergencyOnboardingScreen` is shown once on first launch (gated by `settings.emergencyOnboardingSeen`). The user must add at least one emergency contact before the screen dismisses.

---

## Settings

**Files:** `lib/presentation/settings/`

### Language

Switch between English and Arabic. Immediately updates TTS voice language, layout direction (RTL for Arabic), and all localized strings. Persisted in `settings.locale`.

### Speech Rate

Slider from 0.1 to 1.0 (default 0.45). Adjustments take effect on the next TTS utterance. Persisted in `settings.speechRate`.

### Haptics

Toggle all vibration feedback on or off. Persisted in `settings.hapticsEnabled`.

### Emergency Contacts

- View the list of saved contacts.
- Add a contact (name + phone number).
- Remove a contact.
- Contacts stored as a JSON array in `settings.emergencyContacts`.

---

## Localization

**File:** `lib/core/localization/app_localizations.dart`

- **Languages:** English (`en`) and Arabic (`ar`).
- All user-facing strings — mode names, announcements, error messages, semantic labels — are defined here. No hardcoded strings in UI code.
- Flutter handles RTL layout flip automatically when locale is `ar`.
- TTS voice preference: Egyptian Arabic (`ar-EG`) if available, generic Arabic (`ar`) otherwise, then English.

---

## Accessibility Design

All interaction is designed to work without looking at the screen:

| Input | Action |
|---|---|
| Two-finger swipe left / right | Switch between modes |
| Two-finger swipe up / down | Switch sub-mode within current mode |
| Double-tap | Capture / confirm / primary action |
| Volume buttons | Quick mode switch (via `CameraSideActions`) |
| Shake | Emergency SOS trigger |

Every screen provides:
- Semantic labels and hints for TalkBack (Android) and VoiceOver (iOS).
- Custom semantic actions registered for mode switching.
- Haptic signals to confirm every meaningful interaction.
