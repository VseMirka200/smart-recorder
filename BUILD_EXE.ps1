$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Source = Join-Path $Root 'SmartRecorder.ahk'
$Output = Join-Path $Root 'SmartRecorder.exe'
$OcrFile = Join-Path $Root 'OCR.ahk'
$IconFile = Join-Path $Root 'SmartRecorder.ico'
$Tools = Join-Path $Root '.buildtools'
$AhkVersion = '2.0.26'
$AhkZip = Join-Path $Tools "AutoHotkey_$AhkVersion.zip"
$AhkDir = Join-Path $Tools "AutoHotkey_$AhkVersion"
$ExpectedAhkSha256 = '43522AA3122A57784AC5DB30ABF85C2244475C36ACD7796E2C993355F9E926AE'
$AhkDownloadUrl = "https://github.com/AutoHotkey/AutoHotkey/releases/download/v$AhkVersion/AutoHotkey_$AhkVersion.zip"

function Download-File([string]$Url, [string]$Destination) {
    Write-Host "Downloading: $Url"

    $TempFile = "$Destination.download"
    Remove-Item -Force $TempFile -ErrorAction SilentlyContinue

    # curl.exe on Windows runners handles GitHub redirects and transient network
    # errors more reliably than Windows PowerShell Invoke-WebRequest.
    $Curl = Get-Command 'curl.exe' -ErrorAction SilentlyContinue
    if ($Curl) {
        & $Curl.Source `
            --location `
            --fail `
            --silent `
            --show-error `
            --retry 5 `
            --retry-delay 2 `
            --connect-timeout 30 `
            --user-agent 'SmartRecorder-Build' `
            --output $TempFile `
            $Url

        if ($LASTEXITCODE -eq 0 -and (Test-Path $TempFile) -and ((Get-Item $TempFile).Length -gt 0)) {
            Move-Item -Force $TempFile $Destination
            return
        }

        Write-Warning 'curl.exe download failed; falling back to Invoke-WebRequest.'
        Remove-Item -Force $TempFile -ErrorAction SilentlyContinue
    }

    $Headers = @{
        'User-Agent' = 'SmartRecorder-Build'
        'Accept' = 'application/octet-stream'
    }

    Invoke-WebRequest `
        -UseBasicParsing `
        -Uri $Url `
        -OutFile $TempFile `
        -Headers $Headers `
        -MaximumRedirection 10

    if (-not (Test-Path $TempFile) -or ((Get-Item $TempFile).Length -eq 0)) {
        throw "Downloaded file is empty: $Url"
    }

    Move-Item -Force $TempFile $Destination
}

if (-not (Test-Path $Source)) {
    throw "Source not found: $Source"
}
if (-not (Test-Path $IconFile)) {
    throw "Icon not found: $IconFile"
}

New-Item -ItemType Directory -Force -Path $Tools | Out-Null

# OCR is compiled into the final EXE by Ahk2Exe via #Include.
if (-not (Test-Path $OcrFile)) {
    Download-File 'https://raw.githubusercontent.com/Descolada/OCR/main/Lib/OCR.ahk' $OcrFile
}

# Pin the current stable AutoHotkey v2 toolchain for reproducible builds.
# Download from the official GitHub Release rather than autohotkey.com so CI
# does not receive an anti-bot HTML page instead of the ZIP archive.
if (-not (Test-Path $AhkZip)) {
    Download-File $AhkDownloadUrl $AhkZip
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
& $Compiler.FullName /in $Source /out $Output /base $Base.FullName /icon $IconFile
$ExitCode = $LASTEXITCODE

# Ahk2Exe can return exit code 0 before the output file becomes visible to the
# calling PowerShell process on CI. Treat a non-zero code as a real compiler
# error, but give the successfully started compiler time to finish writing EXE.
if ($ExitCode -ne 0) {
    throw "Ahk2Exe failed (exit code $ExitCode)."
}

$BuildDeadline = (Get-Date).AddSeconds(30)
while ((Get-Date) -lt $BuildDeadline) {
    if ((Test-Path $Output) -and ((Get-Item $Output).Length -gt 0)) {
        break
    }
    Start-Sleep -Milliseconds 500
}

if (-not (Test-Path $Output)) {
    throw 'Ahk2Exe returned success, but SmartRecorder.exe was not created within 30 seconds.'
}

$OutputInfo = Get-Item $Output
if ($OutputInfo.Length -le 0) {
    throw 'SmartRecorder.exe was created but is empty.'
}

$ExeHash = (Get-FileHash -Algorithm SHA256 $Output).Hash
Write-Host ''
Write-Host 'BUILD OK'
Write-Host "EXE: $Output"
Write-Host "SIZE: $($OutputInfo.Length) bytes"
Write-Host "SHA256: $ExeHash"