# Troubleshooting

> **Русский:** [Открыть русскую версию](../TROUBLESHOOTING.md).

## The application does not start

If you run the `.ahk` source:

1. Make sure AutoHotkey v2, not v1, is installed.
2. Check that `SmartRecorder.ahk` was not damaged during copying.
3. Start the script from the directory containing the related project files.

If a compiled EXE does not start, try rebuilding it locally with `BUILD_EXE.bat`.

## OCR is unavailable

If the UI reports that OCR is not ready:

1. Run `Install_OCR.bat`.
2. Make sure `OCR.ahk` appears next to the main script.
3. Restart Smart Recorder.

`OCR.ahk` is a downloadable dependency and may be absent from a clean checkout.

## OCR recognizes the wrong text

Try to:

- make sure the target element is fully visible;
- close overlapping windows;
- check Windows scaling;
- increase the contrast of the form UI;
- reproduce the issue using a short, stable test scenario.

Do not use real sensitive information in diagnostic screenshots.

## F8 recording does not work

Check that:

- the application is not currently playing a recording;
- recording actually entered the active state;
- actions are performed after recording starts;
- another application is not intercepting the same global hotkeys.

## Playback is too fast or too slow

Check the `Скорость` (Speed) field in settings. For diagnostics, start with speed `1.0` and one repetition.

## F10 does not stop immediately

Press `F10` again. If the interface is not responding, use `Esc` to exit the application.

If the issue is reproducible, save a minimal test sequence and create a Bug Report.

## A recording cannot be loaded

Make sure that:

- the file exists;
- it was created by a compatible Smart Recorder version;
- it is not empty or corrupted;
- the application has access to the file location.

## Screenshot area is incorrect

This can depend on:

- screen resolution;
- multiple monitors;
- window placement near a display edge;
- Windows DPI/scaling.

Include resolution, scaling, and monitor layout in the report.

## GUI text is clipped

Include the following in an Issue:

- Windows scaling;
- display resolution;
- Windows version;
- a screenshot of the Smart Recorder interface only.

Text clipping is often related to DPI and system font metrics.
