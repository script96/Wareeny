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
- `lib/presentation/reusable`: reusable presentation widgets.
- `lib/shared/bridges`: native method-channel bridge contracts.
- `docs`: architecture, contracts, examples, and roadmap.

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
