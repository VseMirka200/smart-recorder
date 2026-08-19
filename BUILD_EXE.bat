@echo off
setlocal
cd /d "%~dp0"
echo Building SmartRecorder.exe...
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
