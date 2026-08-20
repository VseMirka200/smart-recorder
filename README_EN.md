<p align="center">
  <img src="SmartRecorder.png" alt="Smart Recorder" width="180">
</p>

<h1 align="center">Smart Recorder</h1>

<p align="center">
  A desktop AutoHotkey v2 utility for recording and replaying mouse and keyboard actions, running repeatable test scenarios, and assisting with form automation.
</p>

<p align="center">
  <a href="https://github.com/VseMirka200/smart-recorder/archive/refs/heads/main.zip"><img alt="Download source" src="https://img.shields.io/badge/Download-source-2ea44f?style=for-the-badge&logo=github"></a>
  <a href="README.md"><img alt="Русский" src="https://img.shields.io/badge/Русский-README-2563eb?style=for-the-badge"></a>
  <a href="docs/en/README.md"><img alt="Documentation" src="https://img.shields.io/badge/Documentation-open-6f42c1?style=for-the-badge"></a>
  <a href="https://github.com/VseMirka200/smart-recorder/issues/new/choose"><img alt="Report an issue" src="https://img.shields.io/badge/Report-an%20issue-d73a49?style=for-the-badge&logo=github"></a>
</p>

<p align="center">
  <img alt="Windows" src="https://img.shields.io/badge/Windows-desktop-0078D4?logo=windows&logoColor=white">
  <img alt="AutoHotkey v2" src="https://img.shields.io/badge/AutoHotkey-v2-334455">
  <img alt="Language" src="https://img.shields.io/badge/UI-Russian-informational">
</p>

> **Русский:** [Открыть русскую версию README](README.md).

## About

Smart Recorder records mouse and keyboard actions and replays them with configurable speed, repetition count, and cooldown intervals. It also includes a test-profile generator, OCR-assisted actions, a status panel, an action journal, and automatic recording persistence.

The project is intended for automation of your own and test scenarios. Recorded input and screenshots may contain sensitive information, so runtime data should be reviewed before sharing.

## Features

- record mouse and keyboard actions;
- replay recordings at a configurable speed;
- choose the number of full repetitions;
- random cooldown between repetitions;
- automatic saving and loading of the working recording;
- load another recording from the application UI;
- generate a test profile with age and sex;
- optionally generate a new random profile before every repetition;
- OCR assistance for form-related test scenarios;
- `F3` workflow for selecting the required sex option;
- `F4` special answer/screenshot workflow;
- action journal and separate status panel;
- custom application icon.

## Download

Use the **Download source** button above to get a ZIP archive of the current `main` branch, or clone the repository:

```bash
git clone https://github.com/VseMirka200/smart-recorder.git
```

## Quick start

1. Install AutoHotkey v2 if you run the `.ahk` source directly.
2. Clone or download the repository.
3. Run `Install_OCR.bat` if OCR support is needed.
4. Start `SmartRecorder.ahk`.

The `OCR.ahk` dependency can be restored when needed and does not have to be stored in a clean checkout.

## Hotkeys

| Key | Action |
|---|---|
| `F1` | show or hide the action journal |
| `F2` | action using the current profile age |
| `F3` | sex selection workflow |
| `F4` | special answer/screenshot workflow |
| `F5` | generate a new test profile |
| `F6` | enable or disable OCR |
| `F7` | OCR assistant action |
| `F8` | start or stop recording |
| `F9` | start playback |
| `F10` | stop playback |
| `F11` | show or hide the status panel |
| `F12` | show or hide settings |
| `Esc` | exit |

Detailed reference: [`docs/en/HOTKEYS.md`](docs/en/HOTKEYS.md).

## Main settings

The application window provides controls for:

- repetition count;
- playback speed;
- cooldown range;
- supported time-format examples;
- age range;
- sex mode;
- random profile regeneration before each repetition;
- OCR enable/disable;
- loading another recording.

## Supported time formats

Cooldown fields accept values such as:

```text
3м
3м30с
90с
00:03:30
```

The current UI uses Russian abbreviations for minutes and seconds.

## Repository structure

```text
SmartRecorder.ahk        main application code
SmartRecorder.ico        Windows application icon
SmartRecorder.png        source icon image
BUILD_EXE.bat            local build helper
BUILD_EXE.ps1            PowerShell build script
Install_OCR.bat          manual OCR dependency installer
README.md                Russian project overview
README_EN.md             English project overview
CHANGELOG.md             Russian changelog
CHANGELOG_EN.md          English changelog
docs/                    Russian documentation
docs/en/                 English documentation
.github/                 Russian project policies and GitHub templates
.github/en/              English policy translations
```

## Runtime data

During operation, Smart Recorder may create:

```text
recordings/
screenshots/
```

These folders may contain user input or screen contents and should not be committed or published without review.

## Documentation

English documentation index: **[`docs/en/README.md`](docs/en/README.md)**.

- [Changelog](CHANGELOG_EN.md)
- [Architecture](docs/en/ARCHITECTURE.md)
- [Hotkeys](docs/en/HOTKEYS.md)
- [FAQ](docs/en/FAQ.md)
- [Troubleshooting](docs/en/TROUBLESHOOTING.md)
- [Roadmap](docs/en/ROADMAP.md)
- [Contributing](.github/en/CONTRIBUTING.md)
- [Support](.github/en/SUPPORT.md)
- [Security](.github/en/SECURITY.md)
- [Code of Conduct](.github/en/CODE_OF_CONDUCT.md)

Russian documentation is available from [`docs/README.md`](docs/README.md).

## Issues and feature requests

Use [GitHub Issues](https://github.com/VseMirka200/smart-recorder/issues/new/choose) for bug reports and feature requests.

Before attaching screenshots, logs, or recordings, remove personal and confidential information.
