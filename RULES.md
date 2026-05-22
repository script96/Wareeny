# Wareeny Codebase Rules

These rules keep the Flutter codebase clean and predictable. Share this file with teammates and mention it to any coding agent before they work on the app.

## Main Entry Point

- Keep `Wareeny/lib/main.dart` minimal.
- Do not put feature logic, helper functions, widgets, routing details, or large setup code in `main.dart`.
- App startup belongs in `Wareeny/lib/app/`.
- `main.dart` should only call the app bootstrap function.

## Presentation Layer Structure

- Screen-level surfaces belong in `Wareeny/lib/presentation/` with a clear feature folder, such as `camera`.
- Navigation shell and destination definitions belong in `Wareeny/lib/presentation/navigation/`.
- Reusable presentation widgets belong in `Wareeny/lib/presentation/reusable/`.
- Theme and styling constants belong in `Wareeny/lib/core/theme/`.
- Platform bridges and native contracts belong outside presentation, under `Wareeny/lib/shared/bridges/`.

## Reusable Widgets

- Extract any widget used more than once into `presentation/reusable`.
- Use clear names such as `InfoCard`, `PrimaryActionButton`, `SectionHeader`, `LoadingState`, or `EmptyState`.
- Avoid copying cards, buttons, headers, text fields, spacing blocks, or empty/loading states across screens.

## File and Class Size

- Try to keep each class under 120 lines.
- Split large screens into private widgets or reusable widgets when it improves readability.
- Do not split code so aggressively that the flow becomes harder to understand.

## Readability

- Keep imports clean and remove unused imports.
- Use consistent names for files, classes, routes, services, and widgets.
- Avoid deeply nested widget trees by extracting meaningful pieces.
- Prefer small, focused files over large mixed-purpose files.

## Theme and Styling

- Do not repeat colors, text styles, spacing, shapes, or decorations across many widgets.
- Put shared values in `core/theme`.
- Keep touch targets large and text readable.
- Prefer Material defaults unless the app has a clear design reason to customize.

## Safety Rules

- Do not change app logic during cleanup unless the refactor requires it.
- Do not remove existing features.
- Do not rename public APIs, routes, providers, controllers, bridge method names, or state classes unless absolutely necessary.
- After refactoring, the app should run the same way as before.

## Native Bridge Contracts

- Define method-channel names in `shared/bridges/native_bridge_channels.dart`.
- Keep bridge method names explicit and stable.
- Add native Android/iOS implementation against the Dart bridge contracts instead of calling method channels directly from screens.
