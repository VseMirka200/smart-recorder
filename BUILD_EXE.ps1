$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Source = Join-Path $Root 'SmartRecorder_F4_PlaybackScreenshots_v27.ahk'
$Output = Join-Path $Root 'SmartRecorder_F4_PlaybackScreenshots_v27.exe'
$OcrFile = Join-Path $Root 'OCR.ahk'
$Tools = Join-Path $Root '.buildtools'
$AhkVersion = '2.0.26'
$AhkZip = Join-Path $Tools "AutoHotkey_$AhkVersion.zip"
$AhkDir = Join-Path $Tools "AutoHotkey_$AhkVersion"
$ExpectedAhkSha256 = '43522AA3122A57784AC5DB30ABF85C2244475C36ACD7796E2C993355F9E926AE'

function Download-File([string]$Url, [string]$Destination) {
    Write-Host "Downloading: $Url"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
}

if (-not (Test-Path $Source)) {
    throw "Source not found: $Source"
}

New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# OCR is compiled into the final EXE by Ahk2Exe via #Include.
if (-not (Test-Path $OcrFile)) {
    Download-File 'https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk' $OcrFile
}

# Pin the current stable AutoHotkey v2 toolchain for reproducible builds.
if (-not (Test-Path $AhkZip)) {
    Download-File "https://www.autohotkey.com/download/2.0/AutoHotkey_$AhkVersion.zip" $AhkZip
}

$ActualSha = (Get-FileHash -Algorithm SHA256 $AhkZip).Hash.ToUpperInvariant()
if ($ActualSha -ne $ExpectedAhkSha256) {
    Remove-Item -Force $AhkZip -ErrorAction SilentlyContinue
    throw "AutoHotkey ZIP SHA256 mismatch. Expected $ExpectedAhkSha256, got $ActualSha"
}

if (-not (Test-Path $AhkDir)) {
    New-Item -ItemType Directory -Force -Path $AhkDir | Out-Null
    Expand-Archive -Path $AhkZip -DestinationPath $AhkDir -Force
}

$Base = Get-ChildItem -Path $AhkDir -Recurse -File -Filter 'AutoHotkey64.exe' | Select-Object -First 1
$Compiler = Get-ChildItem -Path $AhkDir -Recurse -File -Filter 'Ahk2Exe.exe' | Select-Object -First 1

# Some portable layouts may omit Compiler. Download the official Ahk2Exe release if needed.
if (-not $Compiler) {
    Write-Host 'Ahk2Exe.exe not found in AutoHotkey package; downloading official compiler...'
    $Releases = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent' = 'SmartRecorder-Build' } -Uri 'https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases?per_page=20'
    $Asset = $null
    foreach ($Release in $Releases) {
        foreach ($A in $Release.assets) {
            if ($A.name -match '^Ahk2Exe.*\.zip$' -or $A.name -eq 'Ahk2Exe.zip') {
                $Asset = $A
                break
            }
        }
        if ($Asset) { break }
    }
    if (-not $Asset) { throw 'Could not locate an Ahk2Exe ZIP release asset.' }

    $CompilerZip = Join-Path $Tools $Asset.name
    $CompilerDir = Join-Path $Tools 'Ahk2Exe'
    Download-File $Asset.browser_download_url $CompilerZip
    New-Item -ItemType Directory -Force -Path $CompilerDir | Out-Null
    Expand-Archive -Path $CompilerZip -DestinationPath $CompilerDir -Force
    $Compiler = Get-ChildItem -Path $CompilerDir -Recurse -File -Filter 'Ahk2Exe.exe' | Select-Object -First 1
}

if (-not $Base) { throw 'AutoHotkey64.exe was not found in the downloaded AutoHotkey package.' }
if (-not $Compiler) { throw 'Ahk2Exe.exe was not found.' }

# Put the supplied recording where the script expects it at runtime.
$RecordingsDir = Join-Path $Root 'recordings'
New-Item -ItemType Directory -Force -Path $RecordingsDir | Out-Null
$ProvidedRecording = Join-Path $Root 'last_recording_WITH_NEXT.srm'
$RuntimeRecording = Join-Path $RecordingsDir 'last_recording.srm'
if ((Test-Path $ProvidedRecording) -and -not (Test-Path $RuntimeRecording)) {
    Copy-Item $ProvidedRecording $RuntimeRecording
}

Remove-Item -Force $Output -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'Compiling SmartRecorder...'
& $Compiler.FullName /in $Source /out $Output /base $Base.FullName
$ExitCode = $LASTEXITCODE

if ($ExitCode -ne 0 -or -not (Test-Path $Output)) {
    throw "Ahk2Exe failed (exit code $ExitCode)."
}

$ExeHash = (Get-FileHash -Algorithm SHA256 $Output).Hash
Write-Host ''
Write-Host 'BUILD OK'
Write-Host "EXE: $Output"
Write-Host "SHA256: $ExeHash"
