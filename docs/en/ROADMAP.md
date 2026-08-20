# Roadmap

This document lists possible future directions for Smart Recorder. Items are not delivery promises and may change as the project evolves.

> **Русский:** [Открыть русскую версию](../ROADMAP.md).

## Near-term ideas

- continue simplifying and aligning the GUI;
- reduce repeated hard-coded GUI coordinates;
- improve recording and playback diagnostics;
- display the active recording file more clearly;
- improve OCR error handling;
- test the interface at different Windows scaling levels;
- maintain a stable versioning and release process.

## Reliability

- reduce dependence on fixed delays;
- add more state checks before clicks and text input;
- improve recovery after playback is stopped;
- ensure keys held during playback are always released;
- improve multi-monitor handling.

## Recording and playback

- make the recording format explicitly versioned;
- add compatibility checks for older `.srm` files;
- improve errors for corrupted recordings;
- add a safe preview of recording parameters before playback.

## Interface

- align all settings groups to a consistent spacing grid;
- improve DPI scaling;
- make status information more compact;
- separate primary actions from rarely used settings.

## Development

- keep syntax/build checks in GitHub Actions where useful;
- add small automated tests for time conversion and recording-data helpers;
- formalize versioning rules;
- keep release artifacts reproducible.

## Documentation

- keep the README and hotkey reference synchronized with the code;
- expand the FAQ using real recurring issues;
- record notable changes in [`CHANGELOG_EN.md`](../../CHANGELOG_EN.md).
