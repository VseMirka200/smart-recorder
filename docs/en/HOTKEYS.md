# Hotkeys

The following hotkeys are registered by the current `SmartRecorder.ahk`.

> **Русский:** [Открыть русскую версию](../HOTKEYS.md).

| Key | Action |
|---|---|
| `F1` | show or hide the action journal |
| `F2` | use the current test-profile age |
| `F3` | run the sex-selection workflow |
| `F4` | run the current answer/screenshot workflow |
| `F5` | generate a new test profile |
| `F6` | enable or disable the OCR assistant |
| `F7` | run the OCR assistant action / type the suggested answer |
| `F8` | start or stop action recording |
| `F9` | start playback of the current recording |
| `F10` | stop playback |
| `F11` | show or hide the status panel |
| `F12` | show or hide the settings window |
| `Esc` | exit Smart Recorder |

## F8 — recording

When recording starts, the application captures supported mouse and keyboard events. Pressing F8 again stops recording and saves the working recording.

While the application's own GUI is being changed, some events may temporarily be ignored so internal actions are not recorded.

## F9 — playback

Before playback starts, the application applies the settings from the control window:

- repetition count;
- speed;
- cooldown range;
- test-profile options.

If profile regeneration before each repetition is enabled, age and sex are updated according to the selected settings.

## F10 — stop

F10 requests immediate playback termination. After stopping, the application should restore a safe internal state and release any keys that may have been held during playback.

## F2/F3/F5 — profile

- `F2` uses the current profile age;
- `F3` handles sex selection;
- `F5` generates a completely new profile.

Exact behavior depends on the current form and profile settings.

## F6/F7 — OCR

OCR is optional. If the OCR dependency is unavailable, the application should report it through the UI or journal without breaking normal recording and playback.

## F4

F4 is a special application workflow. When its behavior changes, this document and the README should be updated together.
