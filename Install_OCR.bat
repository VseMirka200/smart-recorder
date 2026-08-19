@echo off
setlocal
cd /d "%~dp0"
echo Downloading OCR.ahk...

where curl.exe >nul 2>nul
if %errorlevel%==0 goto use_curl

where powershell.exe >nul 2>nul
if %errorlevel%==0 goto use_powershell

echo ERROR: Neither curl.exe nor powershell.exe was found.
echo Please download OCR.ahk manually from Descolada/OCR and place it next to SmartRecorder.ahk.
pause
exit /b 1

:use_curl
curl.exe -L --fail --silent --show-error "https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk" -o "%~dp0OCR.ahk"
goto check_file

:use_powershell
powershell.exe -NoProfile -Command "Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk' -OutFile '%~dp0OCR.ahk'"
goto check_file

:check_file
if exist "%~dp0OCR.ahk" (
    echo.
    echo OK: OCR.ahk was downloaded successfully.
    echo You can now run SmartRecorder.ahk.
    pause
    exit /b 0
)

echo.
echo ERROR: OCR.ahk was not downloaded.
echo Check your Internet connection and try again.
pause
exit /b 1
