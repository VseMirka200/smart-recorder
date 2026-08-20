# Contributing to Smart Recorder

Thank you for your interest in Smart Recorder. The project is small, so changes that simplify the interface, improve recording/playback reliability, and keep the application easy to use are especially valuable.

> **Русский:** [Открыть русскую версию](../CONTRIBUTING.md).

## Before you start

1. Check existing Issues to avoid duplicating an already discussed task.
2. For significant interface or behavior changes, open an Issue first with a short proposal.
3. Do not commit user recordings, form screenshots, logs containing personal data, or other local runtime data.

## Development environment

Windows 10/11 and AutoHotkey v2 are recommended.

Main application file:

```text
SmartRecorder.ahk
```

Local EXE helpers are available as `BUILD_EXE.bat` and `BUILD_EXE.ps1`.

## Branches

Create a separate branch from the current `main` for changes. Examples:

```text
feature/compact-settings
fix/f4-screenshot
fix/gender-recognition
docs/update-readme
```

## Code style

When editing `SmartRecorder.ahk`:

- keep AutoHotkey v2 compatibility;
- use clear function and variable names;
- avoid unnecessary globals;
- group related functions and settings;
- preserve the existing comment and section style;
- avoid duplicating the same logic across handlers;
- test GUI changes at standard Windows scaling;
- avoid fixed delays when state checks are possible.

## Commits

Each commit message should describe one logical change clearly.

Recommended format:

```text
type: short description
```

Examples:

```text
feat: add screenshot-area setting
fix: align profile fields
refactor: simplify playback handler
docs: update hotkey documentation
```

## Before opening a Pull Request

Check that:

- the script starts without syntax errors;
- F8 recording and F9 playback work;
- F10 stops playback correctly;
- settings are applied without errors;
- recording save/load still works;
- OCR behavior is tested both with and without the OCR dependency when relevant;
- new files do not contain personal data;
- documentation is updated when user-visible behavior changes.

## Pull Requests

Include:

- what changed;
- why the change is needed;
- how to test it;
- which parts of the application are affected;
- a GUI screenshot when the interface changes.

Avoid mixing unrelated refactoring, new features, and cosmetic changes in one large PR unless necessary.
