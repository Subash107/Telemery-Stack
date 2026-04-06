# Python URL Checker Browser Extension

This folder now contains a Chrome/Edge Manifest V3 extension plus a Windows native-messaging host so the browser can safely trigger your Python URL checker. After the script runs, it also opens the second URL automatically.

## What is included

- `manifest.json`, `popup.html`, `popup.css`, `popup.js`: the browser extension UI
- `url_checker.pyw`: shared Python logic
- `New Text Document.pyw`: keeps your original script filename working
- `native_host.pyw`: native-messaging bridge for the extension
- `build-native-host.ps1`: builds the Windows host executable
- `build-url-checker.ps1`: builds `url_checker.pyw` as a standalone no-console Windows executable
- `register-native-host.ps1`: registers the host for Chrome, Edge, or both

## Proxy configuration

The extension popup now includes a `MITM Proxy URL` field. It defaults to:

```text
http://192.168.1.6:8082
```

The Python checker uses that proxy for both HTTP and HTTPS requests and includes the proxy information in the returned results shown in the extension popup.

If your mitmproxy listens on a different port, update that field in the popup before running the script.

## Setup

1. Open `chrome://extensions` or `edge://extensions`.
2. Turn on **Developer mode**.
3. Click **Load unpacked** and select this folder.
4. Copy the extension ID shown on the extensions page.
5. In PowerShell, run:

```powershell
.\register-native-host.ps1 -ExtensionId YOUR_EXTENSION_ID -Browser both
```

6. Click the extension icon, enter two URLs, and run the script.

## Rebuild the native host manually

If you want to rebuild the host executable yourself:

```powershell
.\build-native-host.ps1
```

That script creates a local virtual environment, installs `pyinstaller`, and builds `native-host\dist\bbp_url_checker_host.exe`.

## Build `url_checker.pyw` in no-console mode

If you want a standalone Windows executable for `url_checker.pyw` that runs without opening a console window:

```powershell
.\build-url-checker.ps1
```

That builds:

```text
url-checker-app\dist\bbp_url_checker.exe
```

This no-console build is only for the standalone URL checker app. The browser extension native host must stay as a console-style executable because Chrome native messaging communicates over standard input and output.
