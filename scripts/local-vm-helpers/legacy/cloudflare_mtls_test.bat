@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "REPORTS_DIR=%~dp0reports"
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%" >nul 2>&1

set "PYTHON_CMD="
set "SSH_SCRIPT=Finalscriptkalisubash.py"
set "DEFAULT_HOST=192.168.1.22"
set "DEFAULT_TARGET=subashlama.com"
set "DEFAULT_PORT=443"
set "DEFAULT_CERT=~/cloudflare-mtls/client.crt"
set "DEFAULT_KEY=~/cloudflare-mtls/client.key"
set "DEFAULT_CA=/etc/ssl/certs/ca-certificates.crt"
set "DEFAULT_PATH=/"

where py >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=py"

if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_CMD=python"
)

if not defined PYTHON_CMD (
    echo Python was not found on this computer.
    echo Install Python and run this file again.
    pause
    exit /b 1
)

if not exist "%SSH_SCRIPT%" (
    echo Could not find %SSH_SCRIPT% in:
    echo %CD%
    pause
    exit /b 1
)

%PYTHON_CMD% -c "import paramiko" >nul 2>&1
if errorlevel 1 (
    echo Installing the Python package 'paramiko'...
    %PYTHON_CMD% -m pip install paramiko
    if errorlevel 1 (
        echo Failed to install 'paramiko'.
        pause
        exit /b 1
    )
)

set /p "KALI_HOST=Enter Kali VM IP/hostname [%DEFAULT_HOST%]: "
if not defined KALI_HOST set "KALI_HOST=%DEFAULT_HOST%"
if "%KALI_HOST: =%"=="" set "KALI_HOST=%DEFAULT_HOST%"

set /p "TARGET_HOST=Enter connect host/IP [%DEFAULT_TARGET%]: "
if not defined TARGET_HOST set "TARGET_HOST=%DEFAULT_TARGET%"
if "%TARGET_HOST: =%"=="" set "TARGET_HOST=%DEFAULT_TARGET%"

set /p "VERIFY_NAME=Enter certificate verify hostname [%TARGET_HOST%]: "
if not defined VERIFY_NAME set "VERIFY_NAME=%TARGET_HOST%"
if "%VERIFY_NAME: =%"=="" set "VERIFY_NAME=%TARGET_HOST%"

:prompt_tls_port
set /p "TARGET_PORT=Enter HTTPS/TLS port [%DEFAULT_PORT%]: "
if not defined TARGET_PORT set "TARGET_PORT=%DEFAULT_PORT%"
if "%TARGET_PORT: =%"=="" set "TARGET_PORT=%DEFAULT_PORT%"
powershell -NoProfile -Command "if ('%TARGET_PORT%' -match '^\d+$' -and [int]'%TARGET_PORT%' -ge 1 -and [int]'%TARGET_PORT%' -le 65535) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo Invalid port. Enter a numeric port such as 443.
    goto prompt_tls_port
)

set /p "CERT_FILE=Enter remote client certificate path [%DEFAULT_CERT%]: "
if not defined CERT_FILE set "CERT_FILE=%DEFAULT_CERT%"
if "%CERT_FILE: =%"=="" set "CERT_FILE=%DEFAULT_CERT%"

set /p "KEY_FILE=Enter remote client private key path [%DEFAULT_KEY%]: "
if not defined KEY_FILE set "KEY_FILE=%DEFAULT_KEY%"
if "%KEY_FILE: =%"=="" set "KEY_FILE=%DEFAULT_KEY%"

set /p "CA_FILE=Enter CA bundle path [%DEFAULT_CA%]: "
if not defined CA_FILE set "CA_FILE=%DEFAULT_CA%"
if "%CA_FILE: =%"=="" set "CA_FILE=%DEFAULT_CA%"

set /p "HTTPS_PATH=Enter HTTPS path [%DEFAULT_PATH%]: "
if not defined HTTPS_PATH set "HTTPS_PATH=%DEFAULT_PATH%"
if "%HTTPS_PATH: =%"=="" set "HTTPS_PATH=%DEFAULT_PATH%"

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"
set "OUTPUT_FILE=%REPORTS_DIR%\cloudflare_mtls_test_%TIMESTAMP%.txt"

set "REMOTE_CMD=bash ~/mtls_client_test.sh --host '%TARGET_HOST%' --verify-name '%VERIFY_NAME%' --port '%TARGET_PORT%' --cert-file '%CERT_FILE%' --key-file '%KEY_FILE%' --ca-file '%CA_FILE%' --path '%HTTPS_PATH%'"

echo.
echo Running Cloudflare mTLS client test on %KALI_HOST%...
echo Connect host: %TARGET_HOST%
echo Verify hostname: %VERIFY_NAME%
echo Port: %TARGET_PORT%
echo Client cert: %CERT_FILE%
echo Client key : %KEY_FILE%
echo HTTPS path : %HTTPS_PATH%
echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "!REMOTE_CMD!" > "%OUTPUT_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

type "%OUTPUT_FILE%"
echo.

if not "%EXIT_CODE%"=="0" (
    echo Cloudflare mTLS test finished with an error.
) else (
    echo Cloudflare mTLS test completed successfully.
)

echo Report saved to:
echo %OUTPUT_FILE%
pause
exit /b %EXIT_CODE%
