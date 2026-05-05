# Wareeny — Roadmap

Feature tracking by milestone. Check items as completed.

---

## Milestone 1: Foundation (Complete)

Core app infrastructure.

- [x] Flutter project structure and dark theme
- [x] Camera integration (singleton, `ResolutionPreset.high`)
- [x] Runtime permission gating (camera + microphone)
- [x] Egyptian Arabic TTS (flutter_tts, `ar-EG`, 0.5× speed)
- [x] `.env` configuration loading via flutter_dotenv
- [x] App lifecycle pause/resume handling

---

## Milestone 2: Core Detection Features (Partial — In Progress)

> **Note:** Current Flutter app is a prototype. Full UI overhaul planned after models and features are finalized.

- [x] Real-time object detection (YOLOv8n, 80 COCO classes, on-device)
- [x] Full Arabic translation dictionary for all 80 COCO classes
- [x] Spatial feedback — direction (left/center/right) + distance (close/far)
- [x] Scene description one-shot (Groq LLaMA 4 Vision)
- [x] English OCR (Google ML Kit)
- [x] Arabic OCR (Tesseract 5)
- [x] Color detection (HSL-based, 12 Arabic color names)
- [x] TTS throttling (3-second repeat cooldown)
- [x] Detection persistence (3-frame hysteresis before clearing)
- [x] Bounding box overlay with Arabic labels and confidence scores
- [ ] **Egyptian currency recognition** — model poor quality, retraining with YOLOv8m in progress
- [ ] **Object Finder** — logic stubbed but rudimentary/barely functional, full overhaul needed
- [ ] **Gesture controls** — stubs in code, not properly implemented
- [ ] **Mode switching UI** — basic version exists, will be rebuilt in app overhaul

---

## Milestone 3: Model Improvement (In Progress — Current Focus)

Better models, more Egyptian-specific coverage.

- [~] Retrain currency model — YOLOv8m training pipeline ready, training in progress
- [ ] Expand currency coverage — add 5 EGP note, 1 EGP coin
- [ ] Collect training dataset for Egyptian brand detection (product packaging, logos)
- [ ] Train YOLOv8 brand detection model
- [ ] Integrate brand detection model in app (new mode or embedded in general detection)
- [ ] Add ATM, pharmacy sign, trash can, mosque to Object Finder smart registry
- [ ] Add traffic light to Object Finder smart registry (temporary until dedicated model)

---

## Milestone 3.5: Flutter App Overhaul (Planned — After Models Done)

Current app is a prototype. Full rebuild once all models and core features are finalized.

- [ ] Complete UI redesign from scratch
- [ ] Proper gesture control system (swipes, taps, long-press — fully implemented)
- [ ] Polished Object Finder (reliable detection, good UX feedback)
- [ ] Smooth mode transitions and state management
- [ ] Accessibility audit (screen reader compatibility, touch target sizes)

---

## Milestone 4: Advanced Interaction Features (In Progress)

New modes and input methods.

- [x] QA Mode — OCR document → Groq system context → conversational Q&A via voice
  - [ ] Follow-up: Long-document chunking for texts > 4000 characters
  - [ ] Follow-up: Optional privacy warning before sending text to Groq
  - [ ] Follow-up: Manual Android QA test pass on real device
- [ ] Hand-held object focus — detect user holding object, auto-describe that specific object
- [ ] Haptic feedback — vibrate pattern when obstacle is very close in general objects mode
- [ ] Voice commands — activate modes and trigger one-shot actions by speech
- [ ] Adjustable verbosity control accessible in-app (currently hardcoded to `normal`)

---

## Milestone 5: Safety and Environment Detection (Later)

Hazard awareness features.

- [ ] Traffic light detection — dedicated YOLOv8 model (red/green/yellow)
- [ ] Wet floor / slippery surface detection
- [ ] Obstacle warning — stairs, open manholes, low poles
- [ ] Danger sign reading (Arabic + English warning signs)

---

## Milestone 6: Privacy and Personal Features (Deferred)

Lower priority — requires additional infrastructure or significant design work.

- [ ] Private content detection — warn before any image leaves device (faces, IDs, documents)
- [ ] Saved items finder — user registers owned objects, app guides back to them by location/description
- [ ] On-device scene description — offline fallback when Groq unavailable

---

## Technical Debt

- [ ] Rename `GeminiService` → `GroqVisionService` (currently misnamed, uses Groq not Google Gemini)
- [ ] Write unit tests (test/ folder is empty boilerplate)
- [ ] Write widget tests for CameraScreen and ActionMenu
- [ ] Add CI/CD pipeline (GitHub Actions: lint + test on PR)
- [ ] Test and deploy on iOS
- [ ] Reduce APK size (TFLite models total ~49 MB — consider dynamic delivery)
- [ ] Handle Groq API key rotation without app rebuild
