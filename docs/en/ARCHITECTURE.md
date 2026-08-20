# Smart Recorder Architecture

Smart Recorder is a monolithic AutoHotkey v2 application. Most behavior lives in `SmartRecorder.ahk`; external files are used for the application icon, local build helpers, and the optional OCR dependency.

> **Русский:** [Открыть русскую версию](../ARCHITECTURE.md).

## Main parts

### 1. Initialization

At startup, the script:

- configures mouse and pixel coordinate modes;
- initializes global settings and application state;
- checks whether OCR is available;
- applies the application icon;
- creates the settings, status, and journal windows;
- loads the last saved recording when available.

### 2. GUI

The application uses several windows:

- the settings window for run parameters, timing, and profile options;
- the status panel for the current mode;
- the journal for recent actions and diagnostic messages.

The GUI is connected directly to the global settings used before recording or playback starts.

### 3. Hotkeys

F1–F12 and Esc are the primary quick-control interface. Each hotkey calls a handler that works with the current application state.

See [`HOTKEYS.md`](HOTKEYS.md) for the detailed list.

### 4. Recording

The recording subsystem stores events in an internal array. Events include timing information, mouse and keyboard activity, and selected application-level events.

Important state includes:

- whether recording is active;
- recording start time;
- last mouse position;
- action counters;
- whether application-generated input should temporarily be ignored.

### 5. Playback

Playback executes saved events while respecting:

- selected speed;
- repetition count;
- random cooldowns;
- immediate stop requests;
- held-key state.

The application may pre-calculate cooldowns to estimate expected total runtime.

### 6. Test profile

A profile contains age and sex. Age is generated within a configured range, while sex may be selected explicitly or generated randomly.

The profile can be regenerated before every repetition.

### 7. OCR

OCR is used only in workflows that require recognition of interface content. Because the dependency is optional, the application checks availability first and should continue operating when OCR is unavailable.

### 8. Screenshots

Special F4-related workflows may save screenshots to a dedicated folder. Capture logic must account for screen boundaries and multi-monitor setups.

### 9. Recording storage

The default working recording is stored at:

```text
recordings/last_recording.srm
```

The currently selected recording path is tracked separately, so another file can be loaded through the UI.

Runtime data is not intended to be committed to Git.

## Local build helpers

The repository contains `BUILD_EXE.bat` and `BUILD_EXE.ps1` for local compilation. They are implementation helpers rather than a separate documentation section.

## Possible refactoring

If the application grows further, the monolithic script can gradually be split into modules such as:

```text
src/
  Gui.ahk
  Recorder.ahk
  Playback.ahk
  Profile.ahk
  OcrHelper.ahk
  Storage.ahk
```

Such a migration should be incremental, keeping the application functional after each step.
