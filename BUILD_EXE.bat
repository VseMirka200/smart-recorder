@echo off
setlocal
cd /d "%~dp0"
echo Building SmartRecorder_F4_PlaybackScreenshots_v27.exe...
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD_EXE.ps1"
if errorlevel 1 (
  echo.
  echo BUILD FAILED.
  pause
  exit /b 1
)
echo.
echo BUILD COMPLETE.
pause
