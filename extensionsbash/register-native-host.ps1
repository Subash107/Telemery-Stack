param(
    [Parameter(Mandatory = $true)]
    [string]$ExtensionId,

    [ValidateSet("chrome", "edge", "both")]
    [string]$Browser = "both"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (
    $ExtensionId -match "^YOUR_" -or
    $ExtensionId -match "EXTENSION_ID" -or
    $ExtensionId -notmatch "^[a-p]{32}$"
) {
    throw "ExtensionId must be your real 32-character Chrome/Edge extension ID from chrome://extensions or edge://extensions."
}

$root = $PSScriptRoot
$hostExe = Join-Path $root "native-host\dist\bbp_url_checker_host.exe"
$manifestPath = Join-Path $root "native-host\com.bbp.url_checker.json"

if (-not (Test-Path $hostExe)) {
    & (Join-Path $root "build-native-host.ps1")
}

$manifest = @{
    name = "com.bbp.url_checker"
    description = "Native messaging host for the Python URL checker browser extension"
    path = $hostExe
    type = "stdio"
    allowed_origins = @("chrome-extension://$ExtensionId/")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText(
    $manifestPath,
    ($manifest | ConvertTo-Json -Depth 5),
    $utf8NoBom
)

$registryRoots = switch ($Browser) {
    "chrome" { @("HKCU:\Software\Google\Chrome\NativeMessagingHosts") }
    "edge" { @("HKCU:\Software\Microsoft\Edge\NativeMessagingHosts") }
    default {
        @(
            "HKCU:\Software\Google\Chrome\NativeMessagingHosts",
            "HKCU:\Software\Microsoft\Edge\NativeMessagingHosts"
        )
    }
}

foreach ($registryRoot in $registryRoots) {
    $keyPath = Join-Path $registryRoot "com.bbp.url_checker"
    New-Item -Path $keyPath -Force | Out-Null
    Set-Item -Path $keyPath -Value $manifestPath
}

Write-Host ""
Write-Host "Native host registered successfully." -ForegroundColor Green
Write-Host "Extension ID : $ExtensionId"
Write-Host "Manifest path: $manifestPath"
Write-Host "Host exe path: $hostExe"
Write-Host "Browser target: $Browser"
