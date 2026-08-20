# Changelog

All notable Smart Recorder changes are recorded in this file.

> **Русский:** [Открыть русскую историю изменений](CHANGELOG.md).

The format follows the spirit of Keep a Changelog: changes are grouped by meaning rather than internal implementation details.

## Unreleased

### Added

- repository documentation set;
- Issue and Pull Request templates;
- separate architecture, hotkey, FAQ, troubleshooting, roadmap, and English documentation pages.

## 2026-08-19 — interface and behavior overhaul

### Added

- custom application icon for the window, tray, and compiled EXE;
- compact launch and timing settings;
- updated test-profile controls;
- automatic handling of the current recording;
- screenshot saving for F4 workflows;
- recognition and selection of sex options through F3.

### Changed

- reorganized interface layout;
- reduced unnecessary spacing and aligned input fields;
- simplified recording-file loading controls;
- improved `SmartRecorder.exe` build helpers;
- updated labels, tooltips, and time-format examples.

### Fixed

- clipped GUI labels;
- incorrect spacing between settings fields;
- application icon transparency issues;
- several sex-selection and OCR workflow problems.

## Initial version

### Added

- mouse and keyboard action recording;
- playback with configurable speed;
- configurable repetition count;
- random cooldown between repetitions;
- action journal and status panel;
- test profile with age and sex;
- OCR assistant;
- recording save/load support;
- local EXE build scripts.
