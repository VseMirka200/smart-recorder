# FAQ

> **Русский:** [Открыть русскую версию](../FAQ.md).

## What is Smart Recorder?

Smart Recorder is an AutoHotkey v2 utility for recording and replaying mouse and keyboard actions, repeating scenarios, and automating test forms.

## Is AutoHotkey required?

AutoHotkey v2 is required to run `SmartRecorder.ahk` directly. A compiled `SmartRecorder.exe` normally does not require a separate AutoHotkey installation.

## Where is the recording stored?

The default working recording is stored in the `recordings` directory next to the application. Another recording can be loaded through the UI.

## Why are recordings and screenshots excluded from Git?

These files may contain user input or screen content, so runtime data is excluded through `.gitignore`.

## Why does OCR not work?

Check that:

- the OCR dependency is available;
- the UI shows an OCR-ready status;
- the target element is not covered by another window;
- the text is clearly visible;
- Windows scaling is not interfering with recognition.

Run `Install_OCR.bat` if the OCR dependency needs to be restored.

## Why is the sex option not recognized?

Recognition depends on text, contrast, scaling, and element placement. Make sure the required option is fully visible and OCR is available.

If the issue is reproducible, create an Issue with anonymized screenshots and clear reproduction steps.

## Why does the interface look different on my computer?

AutoHotkey GUI dimensions may vary because of DPI, Windows scaling, fonts, and system theme. Include your Windows scaling value when reporting layout problems.

## Can I use multiple monitors?

The main code uses screen coordinates, but capture and click workflows should be tested on the specific multi-monitor configuration being used.

## What should I do if playback gets stuck?

Press `F10`. If the problem remains, exit with `Esc`, restart the application, and retry with a short test recording.

## How do I report a bug?

Use GitHub Issues and the Bug Report template. Remove personal data from logs and screenshots before publishing them.

## Where can I find all hotkeys?

See [`HOTKEYS.md`](HOTKEYS.md).
