@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
set "REPORTS_DIR=%~dp0reports"
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%" >nul 2>&1

set "PYTHON_CMD="
set "SSH_SCRIPT=Finalscriptkalisubash.py"
set "DEFAULT_HOST=192.168.1.22"
set "DEFAULT_TEST_TOPIC=sensor/debug/manual"
set "DEFAULT_MQTT_PORT=8883"
set "DEFAULT_CA_FILE=~/mqtt-project/mosquitto/config/certs/ca.crt"
set "DEFAULT_MQTT_USERNAME=subash"
set "DEFAULT_PUBLISH=no"

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
echo Telemetry debug modes:
echo 1. Read-only health report only  ^(recommended for safe checks^)
echo 2. Health report plus one live telemetry probe through sensor/#
echo.
echo Note: your current broker bridges sensor/#, so a live probe can also leave the VM.
echo Live probe credentials are read from local environment variables, not from this repo.
set /p "RUN_PROBE=Publish one live telemetry probe? [no]: "
if not defined RUN_PROBE set "RUN_PROBE=%DEFAULT_PUBLISH%"
if "%RUN_PROBE: =%"=="" set "RUN_PROBE=%DEFAULT_PUBLISH%"

set "LIVE_PROBE=no"
if /I "%RUN_PROBE%"=="y" set "LIVE_PROBE=yes"
if /I "%RUN_PROBE%"=="yes" set "LIVE_PROBE=yes"

set "TEST_TOPIC=%DEFAULT_TEST_TOPIC%"
set "MQTT_PORT=%DEFAULT_MQTT_PORT%"
set "CA_FILE=%DEFAULT_CA_FILE%"
set "MQTT_USERNAME=%KALI_MQTT_USERNAME%"
set "MQTT_PASSWORD=%KALI_MQTT_PASSWORD%"

if /I "%LIVE_PROBE%"=="yes" (
    set /p "TEST_TOPIC=Enter live probe topic [%DEFAULT_TEST_TOPIC%]: "
    if not defined TEST_TOPIC set "TEST_TOPIC=%DEFAULT_TEST_TOPIC%"
    if "!TEST_TOPIC: =!"=="" set "TEST_TOPIC=%DEFAULT_TEST_TOPIC%"

    :prompt_mqtt_port
    set /p "MQTT_PORT=Enter MQTT port for the probe [%DEFAULT_MQTT_PORT%]: "
    if not defined MQTT_PORT set "MQTT_PORT=%DEFAULT_MQTT_PORT%"
    if "!MQTT_PORT: =!"=="" set "MQTT_PORT=%DEFAULT_MQTT_PORT%"
    powershell -NoProfile -Command "if ('!MQTT_PORT!' -match '^\d+$' -and [int]'!MQTT_PORT!' -ge 1 -and [int]'!MQTT_PORT!' -le 65535) { exit 0 } else { exit 1 }" >nul 2>&1
    if errorlevel 1 (
        echo Invalid port. Enter a numeric port such as 1883 or 8883.
        goto prompt_mqtt_port
    )

    if "!MQTT_PORT!"=="8883" (
        set /p "CA_FILE=Enter CA file for TLS publish [%DEFAULT_CA_FILE%]: "
        if not defined CA_FILE set "CA_FILE=%DEFAULT_CA_FILE%"
        if "!CA_FILE: =!"=="" set "CA_FILE=%DEFAULT_CA_FILE%"
    )

    if not defined MQTT_USERNAME set "MQTT_USERNAME=%DEFAULT_MQTT_USERNAME%"
    if "!MQTT_USERNAME: =!"=="" set "MQTT_USERNAME=%DEFAULT_MQTT_USERNAME%"

    if not defined MQTT_PASSWORD (
        echo.
        echo Live probe skipped because KALI_MQTT_PASSWORD is not set in your local environment.
        echo Set KALI_MQTT_USERNAME and KALI_MQTT_PASSWORD before rerunning if you want to publish a test message.
        set "LIVE_PROBE=no"
    )
)

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"
set "TEST_ID=debug-%TIMESTAMP%"
set "OUTPUT_FILE=%REPORTS_DIR%\telemetry_debug_%TIMESTAMP%.txt"

echo Kali VM Telemetry Debug Report > "%OUTPUT_FILE%"
echo ================================================================ >> "%OUTPUT_FILE%"
echo Generated on Windows side: %DATE% %TIME% >> "%OUTPUT_FILE%"
echo Remote host: %KALI_HOST% >> "%OUTPUT_FILE%"
echo Live probe enabled: %LIVE_PROBE% >> "%OUTPUT_FILE%"
echo Probe topic: %TEST_TOPIC% >> "%OUTPUT_FILE%"
echo Probe message: %TEST_ID% >> "%OUTPUT_FILE%"
if /I "%LIVE_PROBE%"=="yes" (
    echo Probe port: %MQTT_PORT% >> "%OUTPUT_FILE%"
)
echo. >> "%OUTPUT_FILE%"

set "REMOTE_COMMAND=date -Is && printf '\n'; hostnamectl || uname -a"
call :RunSection "Host Summary"

set "REMOTE_COMMAND=ss -tulpn | grep -E ':(1883|1884|8883|3000|5000|8000|8080|9090)\b' || echo No matching telemetry ports found."
call :RunSection "Listening Telemetry Ports"

set "REMOTE_COMMAND=docker ps --format ""table {{.Names}}\t{{.Status}}\t{{.Ports}}"""
call :RunSection "Docker Containers"

set "REMOTE_COMMAND=curl -s http://127.0.0.1:5000/ || echo Dashboard root did not respond."
call :RunSection "Dashboard Root"

set "REMOTE_COMMAND=curl -s http://127.0.0.1:5000/data || echo Dashboard data did not respond."
call :RunSection "Dashboard Data Before Probe"

set "REMOTE_COMMAND=curl -s http://127.0.0.1:8000/metrics | grep -E 'mqtt_messages_total|kafka_messages_total|kafka_errors_total' || echo Metrics not available."
call :RunSection "App Metrics Before Probe"

set "REMOTE_COMMAND=python3 -c 'import json,urllib.request; data=json.load(urllib.request.urlopen(""http://127.0.0.1:9090/api/v1/targets?state=active"")); print(""Prometheus active targets:""); [print("" - {} health={} lastError={}"".format(t.get(""scrapeUrl""), t.get(""health""), t.get(""lastError""))) for t in data.get(""data"",{}).get(""activeTargets"",[])]'"
call :RunSection "Prometheus Targets"

if /I "%LIVE_PROBE%"=="yes" (
    if "%MQTT_PORT%"=="8883" (
        set "REMOTE_COMMAND=mosquitto_pub -h 127.0.0.1 -p %MQTT_PORT% --cafile '%CA_FILE%' -u '%MQTT_USERNAME%' -P '%MQTT_PASSWORD%' -t '%TEST_TOPIC%' -m '%TEST_ID%' && echo Published telemetry probe: %TEST_ID% || echo Failed to publish telemetry probe."
    ) else (
        set "REMOTE_COMMAND=mosquitto_pub -h 127.0.0.1 -p %MQTT_PORT% -u '%MQTT_USERNAME%' -P '%MQTT_PASSWORD%' -t '%TEST_TOPIC%' -m '%TEST_ID%' && echo Published telemetry probe: %TEST_ID% || echo Failed to publish telemetry probe."
    )
    call :RunSection "Publish Telemetry Probe"

    set "REMOTE_COMMAND=sleep 2; curl -s http://127.0.0.1:5000/data | grep -F '%TEST_ID%' && echo Probe found in dashboard data. || echo Probe not found in dashboard data."
    call :RunSection "Dashboard Probe Lookup"

    set "REMOTE_COMMAND=sleep 1; curl -s http://127.0.0.1:8000/metrics | grep -E 'mqtt_messages_total|kafka_messages_total|kafka_errors_total' || echo Metrics not available."
    call :RunSection "App Metrics After Probe"
) else (
    >> "%OUTPUT_FILE%" echo ================================================================
    >> "%OUTPUT_FILE%" echo Live Probe Skipped
    >> "%OUTPUT_FILE%" echo ================================================================
    >> "%OUTPUT_FILE%" echo.
    >> "%OUTPUT_FILE%" echo Read-only mode was used. No test message was published into sensor/#.
    >> "%OUTPUT_FILE%" echo Run this launcher again and choose yes if you want an end-to-end live probe.
    >> "%OUTPUT_FILE%" echo.
)

set "REMOTE_COMMAND=docker logs --tail 40 mqtt-kafka-app 2>&1"
call :RunSection "mqtt-kafka-app Logs"

set "REMOTE_COMMAND=docker logs --tail 40 kafka-consumer 2>&1"
call :RunSection "kafka-consumer Logs"

set "REMOTE_COMMAND=docker logs --tail 40 mqtt-dashboard 2>&1"
call :RunSection "mqtt-dashboard Logs"

set "REMOTE_COMMAND=docker logs --tail 40 mqtt-broker 2>&1"
call :RunSection "mqtt-broker Logs"

echo.
echo Telemetry debug complete.
echo Report saved to:
echo %OUTPUT_FILE%
pause
exit /b 0

:RunSection
set "SECTION_TITLE=%~1"

echo [%SECTION_TITLE%]
>> "%OUTPUT_FILE%" echo ================================================================
>> "%OUTPUT_FILE%" echo %SECTION_TITLE%
>> "%OUTPUT_FILE%" echo ================================================================
>> "%OUTPUT_FILE%" echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "%REMOTE_COMMAND%" >> "%OUTPUT_FILE%" 2>&1

>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo.
exit /b 0
