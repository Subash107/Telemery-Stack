@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "REPORTS_DIR=%~dp0reports"
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%" >nul 2>&1

set "PYTHON_CMD="
set "SSH_SCRIPT=Finalscriptkalisubash.py"
set "DEFAULT_HOST=192.168.1.22"
set "DEFAULT_TLS_PORT=8883"
set "DEFAULT_MQTT_TOPIC=test/local/8883"

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

echo.
echo TLS target options on the Kali VM:
echo 1. 127.0.0.1
echo 2. localhost
echo 3. %KALI_HOST%  (same as the Kali VM host above)
echo 4. Custom hostname/IP
set /p "TARGET_CHOICE=Choose TLS target [3]: "
if not defined TARGET_CHOICE set "TARGET_CHOICE=3"
if "%TARGET_CHOICE: =%"=="" set "TARGET_CHOICE=3"

set "TLS_HOST="
set "VERIFY_NAME="

if "%TARGET_CHOICE%"=="1" (
    set "TLS_HOST=127.0.0.1"
    set "VERIFY_NAME=127.0.0.1"
) else if "%TARGET_CHOICE%"=="2" (
    set "TLS_HOST=localhost"
    set "VERIFY_NAME=localhost"
) else if "%TARGET_CHOICE%"=="3" (
    set "TLS_HOST=%KALI_HOST%"
    set "VERIFY_NAME=%KALI_HOST%"
) else if "%TARGET_CHOICE%"=="4" (
    set /p "TLS_HOST=Enter TLS connect host/IP [%KALI_HOST%]: "
    if not defined TLS_HOST set "TLS_HOST=%KALI_HOST%"
    if "!TLS_HOST: =!"=="" set "TLS_HOST=%KALI_HOST%"

    set /p "VERIFY_NAME=Enter certificate verify name [!TLS_HOST!]: "
    if not defined VERIFY_NAME set "VERIFY_NAME=!TLS_HOST!"
    if "!VERIFY_NAME: =!"=="" set "VERIFY_NAME=!TLS_HOST!"
) else (
    echo Invalid choice. Using option 3.
    set "TLS_HOST=%KALI_HOST%"
    set "VERIFY_NAME=%KALI_HOST%"
)

:prompt_tls_port
set /p "TLS_PORT=Enter TLS port [%DEFAULT_TLS_PORT%]: "
if not defined TLS_PORT set "TLS_PORT=%DEFAULT_TLS_PORT%"
if "%TLS_PORT: =%"=="" set "TLS_PORT=%DEFAULT_TLS_PORT%"
powershell -NoProfile -Command "if ('%TLS_PORT%' -match '^\d+$' -and [int]'%TLS_PORT%' -ge 1 -and [int]'%TLS_PORT%' -le 65535) { exit 0 } else { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo Invalid port. Enter a numeric port such as 8883.
    goto prompt_tls_port
)

set /p "RUN_MQTT=Run MQTT publish/subscribe test also? [yes]: "
if not defined RUN_MQTT set "RUN_MQTT=yes"
if "%RUN_MQTT: =%"=="" set "RUN_MQTT=yes"

set "MQTT_MODE=--mqtt"
set "MQTT_HOST="
set "MQTT_TOPIC=%DEFAULT_MQTT_TOPIC%"

if /I "%RUN_MQTT%"=="n" set "MQTT_MODE=--no-mqtt"
if /I "%RUN_MQTT%"=="no" set "MQTT_MODE=--no-mqtt"

if /I "!MQTT_MODE!"=="--mqtt" (
    set /p "MQTT_HOST=Enter MQTT hostname/IP for TLS validation [%VERIFY_NAME%]: "
    if not defined MQTT_HOST set "MQTT_HOST=%VERIFY_NAME%"
    if "!MQTT_HOST: =!"=="" set "MQTT_HOST=%VERIFY_NAME%"

    set /p "MQTT_TOPIC=Enter MQTT test topic [%DEFAULT_MQTT_TOPIC%]: "
    if not defined MQTT_TOPIC set "MQTT_TOPIC=%DEFAULT_MQTT_TOPIC%"
    if "!MQTT_TOPIC: =!"=="" set "MQTT_TOPIC=%DEFAULT_MQTT_TOPIC%"
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"
set "OUTPUT_FILE=%REPORTS_DIR%\kali_tls_test_%TIMESTAMP%.txt"

set "REMOTE_CMD=bash ~/tls_test_kali.sh --host '%TLS_HOST%' --port '%TLS_PORT%' --verify-name '%VERIFY_NAME%'"
if /I "!MQTT_MODE!"=="--mqtt" (
    set "REMOTE_CMD=!REMOTE_CMD! --mqtt --mqtt-host '%MQTT_HOST%' --mqtt-topic '%MQTT_TOPIC%'"
) else (
    set "REMOTE_CMD=!REMOTE_CMD! --no-mqtt"
)

echo.
echo Running TLS test on %KALI_HOST%...
echo TLS connect host: %TLS_HOST%
echo Certificate verify name: %VERIFY_NAME%
if /I "!MQTT_MODE!"=="--mqtt" (
    echo MQTT host: %MQTT_HOST%
    echo MQTT topic: %MQTT_TOPIC%
)
echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "!REMOTE_CMD!" > "%OUTPUT_FILE%" 2>&1
set "EXIT_CODE=%ERRORLEVEL%"

type "%OUTPUT_FILE%"
echo.

if not "%EXIT_CODE%"=="0" (
    echo TLS test finished with an error.
) else (
    echo TLS test completed successfully.
)

echo Report saved to:
echo %OUTPUT_FILE%
pause
exit /b %EXIT_CODE%
