# Wareeny Runtime Strategy

## Goals

- keep the app smooth under continuous camera usage
- protect battery and thermal headroom
- keep safety-critical behavior fully local
- support optional local LLM install with automatic offline fallback

## Runtime Tiers

- `Tier 1`: hard real-time local CV and safety logic
- `Tier 2`: optional local LLM if installed and supported
- `Tier 3`: cloud LLM using `Gemma 4 E4B`

## Core Principle

Only one heavy mode runs at a time.

The runtime is split into three isolated loops:

- `UI loop`
  - Flutter UI only
  - never blocked by inference, download, OCR, or network
- `camera/inference loop`
  - native
  - throttled
  - mode-aware
  - worker-thread isolated
- `feedback loop`
  - priority queue for speech and haptics
  - supports interruption and deduplication

## Smoothness Rules

- sample frames instead of processing every frame
- reduce inference resolution for navigation and obstacle detection
- use full-resolution capture only for OCR and ask-image requests
- unload or park inactive heavy models
- keep local LLM unloaded until needed
- suppress repeated announcements using cooldown windows
- downshift workload on low battery or thermal pressure

## Battery Rules

- do not keep LLMs resident in memory unnecessarily
- do not run OCR continuously in background
- avoid continuous network polling
- shrink prompt context before local generation
- disable nonessential overlays when battery is low

## App Routing Rules

### Real-time CV tasks

Always local:

- obstacle detection
- traffic light detection
- currency detection
- brand detection
- saved items
- emergency and danger logic

### LLM tasks

The app-side model router must use this order:

1. if the user preference is `prefer-cloud` and internet is available, use cloud
2. else if internet is unavailable and local model is installed, use local automatically
3. else if user preference is `prefer-local` and local model is installed, use local
4. else if internet is available, use cloud
5. else return `offline-no-llm`

## Device Capability Classes

- `High`
  - strongest local model option visible
- `Medium`
  - lighter local model option visible
- `Low`
  - local model install hidden or strongly warned

Capability checks:

- free storage
- RAM class
- available acceleration path
- thermal headroom
- recent warmup benchmark

## Local Model Install Flow

1. download into temp storage
2. verify checksum
3. move into encrypted model directory
4. write registry metadata into SQLite
5. run warmup benchmark
6. mark model usable or unsupported

## Fallback Behavior

- if cloud request fails and local model is installed, the app retries locally for supported LLM tasks
- if local model is not installed and internet is down, the app remains fully usable for CV/OCR safety features
