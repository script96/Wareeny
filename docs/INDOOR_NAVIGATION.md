# Wareeny — Indoor Navigation

## Goal

Indoor Navigation is a reactive assistive mode for blind users walking inside a house. It does not build a house map or route to named rooms in v1. Its job is to make the immediate path safer using short Arabic voice commands and haptic danger levels.

## Chosen Stack

- Flutter UI and existing `VisionService` orchestration
- Existing on-device YOLO detector for recognized indoor obstacles
- `IndoorNavigationService` for the live loop
- `DepthProvider` abstraction with:
  - `ArcoreDepthProvider`
  - `ArkitDepthProvider`
  - `MonocularDepthProvider`
- `HapticCueService` for vibration output
- `SpeechService` for Arabic-only spoken cues

## Path Safety Logic

The feature analyzes a forward trapezoid corridor in the lower-middle camera view.

An alert is produced only when:
- a detected object overlaps the corridor enough
- near-depth occupies the corridor strongly enough
- the free-space corridor collapses, which is treated as a wall or blocked path

Objects outside the corridor are ignored even if they appear in the frame.

Guidance rules:
- clear corridor: quiet, with occasional `كمل`
- stronger blockage on the left: `اتجه يمين`
- stronger blockage on the right: `اتجه يسار`
- wall-like blockage ahead: `قربت من الحيطة`
- immediate collision risk: `قف حالاً`

## Danger Model

- `safe`: no repeated speech, optional reassurance
- `caution`: light haptic pulse
- `danger`: stronger haptic plus directional cue
- `stop`: strongest haptic plus forced stop command

The score combines:
- corridor overlap of each detected box
- box size and bottom proximity in the image
- near-depth occupancy in left, center, and right corridor bands
- wall-like depth patterns across the center corridor

Hysteresis prevents rapid flicker between lower and higher danger states.

## Device Support

Primary experience:
- Android devices with ARCore Depth support
- iOS LiDAR-capable devices with ARKit scene depth

Fallback:
- Unsupported devices use `MonocularDepthProvider`
- The fallback is fully on-device and offline-first, but wall confidence is lower than native depth

## User Guidance

- Hold the phone forward around chest height
- Use indoor navigation as assistive collision avoidance, not autonomous navigation
- Core indoor navigation does not depend on internet access
