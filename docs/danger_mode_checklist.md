# Danger Mode Verification Checklist

Danger Mode is a background safety detector. It must only run while Navigation Mode is open, for both indoor and outdoor navigation.

## Model Export

- Run `python tool/export_danger_model.py` from the Flutter project root to rebuild Android TFLite and iOS Core ML assets.
- Confirm `assets/models/danger/danger_model_float32.tflite` exists for correctness testing.
- Confirm `assets/models/danger/danger_model.tflite` exists for Android runtime.
- Confirm `assets/models/danger/danger_model.mlpackage.zip` exists for iOS runtime.
- Confirm `assets/models/danger/labels.txt` contains:
  - `Fire`
  - `Smoke`
  - `Stop`
  - `Emergency exit indicator light`
  - `wet_floor_sign`
- Confirm `assets/models/danger/danger_model_export.json` records input and output tensor shapes.
- Optional: run `python tool/export_danger_model.py --optimized int8 --force` to attempt full INT8 calibration. Use FP16 if INT8 calibration is too slow or unsupported on the target runtime.

## App Runtime

- Open Navigation Mode indoors and confirm debug output says `Danger model loaded`.
- Switch to outdoor navigation and confirm Danger Mode remains running.
- Leave Navigation Mode and confirm debug output stops changing; danger inference should not continue.
- Confirm danger inference time is reported and does not freeze the camera preview.
- Under heavy load, confirm `Danger dropped ticks` increments instead of delayed warnings arriving later.

## Alerts

- Trigger `wet_floor_sign`: speaks `خلي بالك، الأرض ممكن تكون مبلولة قدامك`.
- Trigger `Fire` or `Smoke`: speaks `خطر، في نار أو دخان قريب منك`.
- Trigger `Stop`: speaks `خلي بالك، في علامة توقف قدامك`.
- Trigger `Emergency exit indicator light`: speaks `في مخرج قدامك`.
- Confirm danger speech interrupts normal navigation/object/read speech.
- Confirm strong haptic feedback fires with the danger warning.
- Keep the same hazard visible and confirm the same warning repeats only after cooldown.
- Show a higher-priority hazard during cooldown and confirm it can interrupt.

## Debug Overlay

- Enable diagnostics.
- Confirm danger boxes use the distinct magenta `DANGER` overlay.
- Confirm normal navigation boxes still render separately.
- Confirm labels, confidence, source, and inference time are visible in the debug panel.
