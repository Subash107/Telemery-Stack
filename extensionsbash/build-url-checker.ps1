param(
    [string]$PythonExe = "python"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
$venvPath = Join-Path $root ".url-checker-build-venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$distPath = Join-Path $root "url-checker-app\dist"
$workPath = Join-Path $root "url-checker-app\build"
$specPath = Join-Path $root "url-checker-app"
$entryScript = Join-Path $root "url_checker.pyw"

if (-not (Test-Path $venvPython)) {
    & $PythonExe -m venv $venvPath
}

& $venvPython -m pip install --upgrade pip pyinstaller

& $venvPython -m PyInstaller `
    --noconfirm `
    --clean `
    --onefile `
    --noconsole `
    --name bbp_url_checker `
    --distpath $distPath `
    --workpath $workPath `
    --specpath $specPath `
    $entryScript

Write-Host ""
Write-Host "No-console URL checker build completed:" -ForegroundColor Green
Write-Host (Join-Path $distPath "bbp_url_checker.exe")
