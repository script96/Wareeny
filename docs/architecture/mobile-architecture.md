# Mobile Architecture

## Recommended Stack

- `Flutter`
- native bridges in `Kotlin` and `Swift`
- `LiteRT` for local CV models
- `LiteRT-LM` for local downloadable LLMs
- `SQLite` plus encrypted local files

## High-Level Modules

### Flutter Shell

- mode selection
- settings
- routing UX
- accessibility-first controls
- lightweight overlays only

### Native Device Layer

- camera stream
- microphone
- speaker routing
- haptics
- battery and thermal signals
- background download services

### Runtime Services

- `ModeManager`
- `InferenceOrchestrator`
- `FeedbackEngine`
- `ModelRouter`
- `ModelManager`
- `ThermalBatteryController`

## Heavy Mode Isolation

At most one of these runs hot at once:

- indoor safety
- outdoor safety
- OCR read
- ask-image / LLM task
- in-hand capture

## Feedback Priority

Priority order:

1. danger
2. obstacle
3. navigation cue
4. OCR result
5. LLM answer
6. general object labels

## Existing Special Case

`What’s in my hand` is a server-backed feature in v1.

The app must hide the source behind one interface:

- `RemoteInHandProvider`
- `LocalInHandProvider` for future migration
