# Wareeny Thesis — Chapters 4, 5, 6 Implementation Guide

**Project:** Wareeny — AI-powered assistive mobile app for blind/low-vision users  
**Stack:** Flutter (Dart) · Supabase (PostgreSQL) · Google ML Kit · VLM API  
**Thesis:** Bachelor's, Future University in Egypt

---

## Chapter 4: System Design

### 4.1 Introduction
Brief paragraph: this chapter covers the architectural decisions, tools chosen, and design artifacts (screens, DB schema, navigation map) for the Wareeny system.

---

### 4.2 Development Tools and Technologies

| Tool/Technology | Purpose |
|---|---|
| Flutter (Dart) | Cross-platform mobile frontend |
| Supabase | Backend-as-a-service (auth, database, storage) |
| PostgreSQL (via Supabase) | Relational database |
| Google ML Kit | On-device OCR text recognition |
| `flutter_tts` | Text-to-speech audio output |
| VLM API (e.g., Gemini Vision) | Scene/product description via AI |
| Android Studio / VS Code | IDE |
| Git + GitHub | Version control |

---

### 4.3 System Architecture

**Three-layer model:**

```
┌─────────────────────────────────┐
│  Frontend (Flutter Mobile App)  │
│  - UI screens                   │
│  - Camera + mic input           │
│  - TTS audio output             │
└────────────┬────────────────────┘
             │ REST / Supabase SDK
┌────────────▼────────────────────┐
│  Backend (Supabase)             │
│  - Auth (email / anonymous)     │
│  - Realtime DB                  │
│  - Edge Functions (if used)     │
│  - Storage (images)             │
└────────────┬────────────────────┘
             │ SQL
┌────────────▼────────────────────┐
│  Database (PostgreSQL)          │
│  - users, scan_history,         │
│    detected_objects tables      │
└─────────────────────────────────┘
```

**AI layer sits in the frontend** — camera frame → VLM API → spoken result via TTS.

---

### 4.4 Screen Map (Navigation)

> Mobile-only app — no website. Replace "website map" with screen/navigation map.

```
App Entry
│
├── Onboarding / Splash
│
├── Auth
│   ├── Sign Up
│   └── Log In
│
└── Main App (Bottom Nav / Home)
    ├── Scan & Read (OCR mode)
    │   └── Camera → OCR result → TTS
    ├── Scene Description (VLM mode)
    │   └── Camera → AI description → TTS
    ├── Product Detection
    │   └── Camera → Object/product ID → TTS
    └── Settings / Profile
        ├── TTS speed/language
        └── Account
```

---

### 4.5 UI/UX Design

Include screenshots or Figma mockups for each screen above.  
Key design principles for accessibility:
- High contrast / large tap targets
- Every action has audio feedback (TTS)
- Minimal visual clutter — app is used by users who may not see the screen
- Single-tap camera trigger (not multi-step)

If no Figma: include annotated screenshots from the running app.

---

### 4.6 Database Schema (Relational Model)

**`users`**
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | Supabase Auth UID |
| email | TEXT | |
| created_at | TIMESTAMP | |

**`scan_history`**
| Column | Type | Notes |
|---|---|---|
| id | UUID (PK) | |
| user_id | UUID (FK → users.id) | |
| mode | TEXT | `ocr` / `scene` / `product` |
| input_image_url | TEXT | Supabase Storage URL |
| result_text | TEXT | OCR or AI output |
| created_at | TIMESTAMP | |

> Add/adjust columns based on actual Supabase tables. Export schema from Supabase dashboard → Table Editor.

---

## Chapter 5: System Implementation & Testing

### 5.1 Introduction
This chapter documents the implemented features, source code structure, and test results for Wareeny.

---

### 5.2 System Tools
Same table as 4.2 — add version numbers here (e.g., Flutter 3.x, Dart 3.x, Supabase JS/Dart SDK version).

---

### 5.3 Core Features Implemented (CRUD)

**OCR / Scan & Read**
- User points camera at text → ML Kit extracts text → TTS reads it aloud
- C: scan result saved to `scan_history`
- R: user can replay/review past scans
- U/D: user can delete scan history entries

**Scene Description (VLM)**
- Camera frame sent to VLM API → AI returns natural-language description → TTS
- Result optionally saved to `scan_history` (mode = `scene`)

**Product Detection**
- Camera detects product/object → label returned → TTS announces it
- Result saved to `scan_history` (mode = `product`)

**Auth (CRUD on users)**
- C: Sign up creates user in Supabase Auth + `users` table
- R: Login reads user profile
- U: Profile/settings update
- D: Account deletion (if implemented)

---

### 5.4 User Interface — Organized & Documented

For each screen, provide:
1. Screenshot
2. 2–3 sentences describing its purpose
3. Accessibility considerations

Screens to document: Splash, Auth (Login/Signup), Scan & Read, Scene Description, Product Detection, Settings.

---

### 5.5 Source Code — Organized & Documented

**Project structure:**
```
lib/
├── main.dart
├── features/
│   ├── auth/
│   ├── ocr/          # Scan & Read
│   ├── scene/        # VLM description
│   └── product/      # Product detection
├── services/
│   ├── supabase_service.dart
│   ├── tts_service.dart
│   └── vlm_service.dart
└── shared/
    └── widgets/
```

For each feature folder, include:
- Purpose of the module
- Key classes/functions with 1-line descriptions
- Code snippet of the most important function (e.g., the OCR pipeline)

---

### 5.6 Test Plan and Test Cases

| # | Feature | Input | Expected Output | Pass/Fail |
|---|---|---|---|---|
| TC-01 | OCR — clear text | Printed page | Correct text spoken | |
| TC-02 | OCR — handwriting | Handwritten note | Best-effort text or error message | |
| TC-03 | Scene description | Outdoor photo | Descriptive sentence spoken | |
| TC-04 | Product detection | Barcode / product | Product name spoken | |
| TC-05 | Auth — sign up | Valid email/password | Account created, redirected to home | |
| TC-06 | Auth — login | Valid credentials | Logged in successfully | |
| TC-07 | Auth — wrong password | Invalid credentials | Error message spoken/shown | |
| TC-08 | Scan history saved | Complete OCR scan | Entry appears in Supabase | |
| TC-09 | TTS speed setting | Change speed in settings | Next readout uses new speed | |

---

### 5.7 Testing Core Features with Sample Data

Run each test case above. For each:
- Screenshot of the input
- Screenshot of the result
- Whether it passed or failed + notes

Use real data: print a sample page for OCR, use a real product for detection, etc.

---

## Chapter 6: Conclusions and Future Work

### 6.1 Introduction
This chapter summarizes the project outcomes and identifies directions for future development.

---

### 6.2 Project Summary
Wareeny is an AI-powered mobile application designed to assist blind and low-vision users through three core capabilities: OCR-based text reading, AI scene description, and product/object detection — all delivered via voice output. Built with Flutter and Supabase, the app operates on Android/iOS with on-device ML and cloud AI.

---

### 6.3 Project Contributions

- Delivered a functional assistive app addressing real accessibility needs
- Integrated on-device OCR (no internet required for text reading)
- Combined multiple AI modalities (OCR, VLM, object detection) in one accessible interface
- Designed with blind users as the primary user — audio-first UX
- Open-source codebase available as a reference for assistive tech development

---

### 6.4 Conclusion and Future Work

**Conclusion:** Wareeny demonstrates that modern on-device ML and cloud AI can be packaged into an accessible, voice-driven mobile app. The system meets its core objectives of helping blind/low-vision users interact with their environment independently.

**Future Work:**

| Enhancement | Description |
|---|---|
| Offline VLM | Run scene description fully on-device (no API cost) |
| Arabic language support | OCR + TTS in Arabic for Egyptian users |
| Smart home integration | Control lights/appliances by voice via Wareeny |
| Wearable companion | Smart glasses integration for hands-free use |
| Crowdsourced product DB | Users contribute product descriptions |
| Navigation assistance | Indoor/outdoor wayfinding with audio cues |

---

## Notes for the Writer

- **Section 4.4:** Thesis supervisors may expect a traditional "website map" — explain it's a mobile screen map and include the navigation diagram above.
- **Section 4.6:** Export actual table schema from Supabase dashboard to fill in exact columns.
- **Section 5.5:** Copy real code snippets from the repo — don't paraphrase code.
- **Chapter 5 screenshots:** Run the app on a real device or emulator and capture actual screens.
- **Word count guidance:** Chapters 4 and 5 are typically the longest (30–40 pages combined). Chapter 6 is short (5–8 pages).
