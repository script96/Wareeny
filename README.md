# Wareeny Flutter App

Flutter mobile shell for the Wareeny runtime.

## Structure

- `lib/main.dart`: minimal entry point only.
- `lib/app`: bootstrap and root app setup.
- `lib/core/config`: dev/prod environment values.
- `lib/core/di`: app-level service registration.
- `lib/core/theme`: shared theme, colors, and spacing.
- `lib/presentation/camera`: live camera feed surface.
- `lib/presentation/navigation`: top-level navigation shell.
- `lib/presentation/read`: OCR read screen, controller, and sub-widgets (scan overlay, framing overlay, controls bar).
- `lib/presentation/reusable`: reusable presentation widgets.
- `lib/shared/bridges`: native bridge adapters (ML Kit OCR, future native CV).
- `lib/shared/ocr`: OCR models, service (filtering, chunking, framing cues), pure Dart layer.
- `docs`: architecture, contracts, examples, and roadmap.

## Phases

| Phase | Feature Area | Status |
| --- | --- | --- |
| 6 | OCR Reading Core | Complete |
| 7–9 | Remaining features | Planned |

See `docs/roadmap/31-day-roadmap.md` for full task lists and implementation notes per phase.

## Run

```bash
flutter run
```

Use dev or prod values with:

```bash
flutter run --dart-define=APP_ENV=dev
flutter run --dart-define=APP_ENV=prod
```

Team cleanup and presentation-layer rules are documented in `../RULES.md`.
