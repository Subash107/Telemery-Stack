@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "REPORTS_DIR=%~dp0reports"
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%" >nul 2>&1

set "PYTHON_CMD="
set "SSH_SCRIPT=Finalscriptkalisubash.py"
set "DEFAULT_KALI_HOST=192.168.1.22"
set "DEFAULT_PORT=443"
set "SAMPLE_HOSTNAME=unifi.ui.com"
set "SAMPLE_IP=13.227.173.96"

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

set /p "KALI_HOST=Enter Kali VM IP/hostname [%DEFAULT_KALI_HOST%]: "
if not defined KALI_HOST set "KALI_HOST=%DEFAULT_KALI_HOST%"
if "%KALI_HOST: =%"=="" set "KALI_HOST=%DEFAULT_KALI_HOST%"

echo.
echo Public TLS / HTTPS sample options:
echo 1. Sample website by hostname  - %SAMPLE_HOSTNAME%:443
echo 2. Sample website by IP        - %SAMPLE_IP%:443, verify %SAMPLE_HOSTNAME%
echo 3. Custom public hostname
echo 4. Custom public IP/host with separate verify hostname
set /p "TARGET_CHOICE=Choose option [1]: "
if not defined TARGET_CHOICE set "TARGET_CHOICE=1"
if "%TARGET_CHOICE: =%"=="" set "TARGET_CHOICE=1"

set "TARGET_HOST="
set "VERIFY_NAME="
set "TARGET_PORT=%DEFAULT_PORT%"

if "%TARGET_CHOICE%"=="1" (
    set "TARGET_HOST=%SAMPLE_HOSTNAME%"
    set "VERIFY_NAME=%SAMPLE_HOSTNAME%"
) else if "%TARGET_CHOICE%"=="2" (
    set "TARGET_HOST=%SAMPLE_IP%"
    set "VERIFY_NAME=%SAMPLE_HOSTNAME%"
) else if "%TARGET_CHOICE%"=="3" (
    set /p "TARGET_HOST=Enter public hostname [%SAMPLE_HOSTNAME%]: "
    if not defined TARGET_HOST set "TARGET_HOST=%SAMPLE_HOSTNAME%"
    if "!TARGET_HOST: =!"=="" set "TARGET_HOST=%SAMPLE_HOSTNAME%"
    set /p "VERIFY_NAME=Enter certificate verify hostname [!TARGET_HOST!]: "
    if not defined VERIFY_NAME set "VERIFY_NAME=!TARGET_HOST!"
    if "!VERIFY_NAME: =!"=="" set "VERIFY_NAME=!TARGET_HOST!"
) else if "%TARGET_CHOICE%"=="4" (
    set /p "TARGET_HOST=Enter public IP/host [%SAMPLE_IP%]: "
    if not defined TARGET_HOST set "TARGET_HOST=%SAMPLE_IP%"
    if "!TARGET_HOST: =!"=="" set "TARGET_HOST=%SAMPLE_IP%"
    set /p "VERIFY_NAME=Enter certificate verify hostname [%SAMPLE_HOSTNAME%]: "
    if not defined VERIFY_NAME set "VERIFY_NAME=%SAMPLE_HOSTNAME%"
    if "!VERIFY_NAME: =!"=="" set "VERIFY_NAME=%SAMPLE_HOSTNAME%"
) else (
    echo Invalid choice. Using option 1.
    set "TARGET_HOST=%SAMPLE_HOSTNAME%"
    set "VERIFY_NAME=%SAMPLE_HOSTNAME%"
)

:prompt_target_port
set /p "TARGET_PORT=Enter HTTPS/TLS port [%DEFAULT_PORT%]: "
if not defined TARGET_PORT set "TARGET_PORT=%DEFAULT_PORT%"
if "%TARGET_PORT: =%"=="" set "TARGET_PORT=%DEFAULT_PORT%"
powershell -NoProfile -Command "if ('%TARGET_PORT%' -match '^\d+$' -and [int]'%TARGET_PORT%' -ge 1 -and [int]'%TARGET_PORT%' -le 65535) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo Invalid port. Enter a numeric port such as 443.
    goto prompt_target_port
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"
set "OUTPUT_FILE=%REPORTS_DIR%\public_tls_check_%TIMESTAMP%.txt"

set "REMOTE_CMD=bash ~/tls_web_sample.sh --host '%TARGET_HOST%' --verify-name '%VERIFY_NAME%' --port '%TARGET_PORT%'"

echo.
echo Running public TLS test from Kali...
echo SSH target: %KALI_HOST%
echo Connect host: %TARGET_HOST%
echo Verify hostname: %VERIFY_NAME%
echo Port: %TARGET_PORT%
echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "!REMOTE_CMD!" > "%OUTPUT_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

type "%OUTPUT_FILE%"
echo.

if not "%EXIT_CODE%"=="0" (
    echo Public TLS test finished with an error.
) else (
    echo Public TLS test completed successfully.
)

echo Report saved to:
echo %OUTPUT_FILE%
pause
exit /b %EXIT_CODE%
