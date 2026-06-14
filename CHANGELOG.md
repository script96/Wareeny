# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- Localized strings for the camera side actions (`flash`, `capture`, `info`),
  the Stuff Finder screen, the COCO object picker, and Stuff Finder status
  messages in `AppLocalizations` (English + Arabic).
- `StuffFinderStatusKind` descriptor on `StuffFinderController` so the
  presentation layer can render the live status through `AppLocalizations`
  without changing the controller's English `status`/TTS behavior.
- Localized screen-reader announcement when a Stuff Finder target is selected.

### Changed

- [thesiss.tex](file:///d:/Wareeny/docs/thesiss.tex): Updated Chapter 4 (System Design) to describe the application directly as a completed/implemented system, removing transitional or prototype-stage phrasing.
- [thesiss.tex](file:///D:/Codes/Wareeny/docs/thesiss.tex): Expanded Section 4.3.2 (Comparative Justification) with statistics-backed comparison rows covering navigation speed/accuracy, Arabic OCR accuracy evidence, and VQA user-outcome improvements to better justify the hybrid architecture.
- [thesiss.tex](file:///D:/Codes/Wareeny/docs/thesiss.tex): Removed the `Current Implementation Boundaries` subsection from Chapter 5 and restored the `Audio and Haptic Delivery` subsection in the implemented core features section.
- [thesiss.tex](file:///D:/Codes/Wareeny/docs/thesiss.tex): Rewrote Chapter 5 testing subsection prose to report representative sample inputs, example outputs, and literature-backed quantitative interpretation for reading, scanning, navigation, stuff finder, persistence, and emergency validation.
- [thesiss.tex](file:///D:/Codes/Wareeny/docs/thesiss.tex): Renamed and refined Section 5.7.6 as `Testing Summary and Interpretation`, removing provisional wording and presenting the testing summary in finalized thesis language.
- [thesiss.tex](file:///D:/Codes/Wareeny/docs/thesiss.tex): Strengthened Section 5.8's comparative capability table with literature-backed numeric evidence for real-time detection, Arabic-reading improvement, localized currency recognition, and VQA task-completion outcomes.

- Navigation shell: the Home/In-Hand fallback now attaches
  `getModeSwitchActions` to its `Semantics`, so TalkBack/VoiceOver users can
  switch modes from the screen reader's local actions menu.
- Camera side buttons (`_GlassIconButton`): touch target raised to 48×48
  logical pixels (visual circle kept at 44) and labels/tooltips now come from
  `AppLocalizations` instead of hardcoded English.
- Stuff Finder screen, COCO object picker, and status chip now use
  `AppLocalizations` for all user-facing and screen-reader strings.
- Settings: haptics toggle wrapped in `MergeSemantics` so the label and switch
  read as a single operable toggle.
- Emergency contacts tile: the name/phone block is merged into one semantics
  node while edit and delete remain separate, independently operable actions;
  the decorative avatar is hidden from screen readers.

- Stuff Finder picker (`CocoObjectPicker`): removed the search text field (no
  typing for screen-reader users); now opens a short shortlist of common
  objects (`commonStuffFinderClasses`) with a "More objects" action that
  reveals the full catalogue. Title is a semantics header; drag handle hidden.
  Each object tile now reads just its name (e.g. "Wallet") plus button/selected
  role — the category subtitle ("Custom Stuff Finder model" / "Everyday COCO
  object" / "COCO object") was removed so TalkBack no longer reads it for every
  item. Removed the now-unused localization strings for those subtitles and the
  old search hint.

### Changed

- Navigation sub-mode control (`_NavSubModeToggle`): replaced the two separate
  Indoor/Outdoor buttons with a single cycling toggle ("Navigation type:
  Indoor. Double tap to switch to Outdoor.") that is fast to reach and flips on
  one double-tap. Read screen toggle labels/announcements localized to match.
- `CameraTopBar` wrapped in `ExcludeSemantics` (decorative brand/live/mode
  chrome) so the first focusable element is the actionable sub-mode toggle.

### Fixed

- Raw camera/detector platform surfaces (`CameraFeedView` and the navigation /
  Stuff Finder `YOLOView`s) are wrapped in `ExcludeSemantics` so TalkBack/
  VoiceOver no longer focus the empty preview or emit redundant focus frames.
- `NavigationShell.dispose` no longer performs an inherited-widget lookup
  (`AppScope.of(context)`) on a deactivated element; the `EmergencyController`
  is cached when armed and disarmed via that reference. This was throwing
  "Looking up a deactivated widget's ancestor is unsafe" and failing the
  widget tests at teardown.

### Removed
