param(
    [string]$PythonExe = "python"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$venvPath = Join-Path $root ".native-host-build-venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$distPath = Join-Path $root "native-host\dist"
$workPath = Join-Path $root "native-host\build"
$specPath = Join-Path $root "native-host"
$tempEntryDir = Join-Path $env:TEMP "bbp_url_checker_native_host_build"
$entryScript = Join-Path $tempEntryDir "native_host_console_entry.py"

New-Item -ItemType Directory -Path $tempEntryDir -Force | Out-Null
[System.IO.File]::WriteAllText(
    $entryScript,
    @"
import sys
sys.path.insert(0, r"$root")
from native_host import main

if __name__ == "__main__":
    raise SystemExit(main())
"@
)

if (-not (Test-Path $venvPython)) {
    & $PythonExe -m venv $venvPath
}

& $venvPython -m pip install --upgrade pip pyinstaller

& $venvPython -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --console `
    --name bbp_url_checker_host `
    --distpath $distPath `
    --workpath $workPath `
    --specpath $specPath `
    $entryScript

Write-Host ""
Write-Host "Native host build completed:" -ForegroundColor Green
Write-Host (Join-Path $distPath "bbp_url_checker_host.exe")
