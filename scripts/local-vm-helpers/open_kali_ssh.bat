@echo off
setlocal
cd /d "%~dp0"

set "PYTHON_CMD="
set "DEFAULT_HOST=192.168.1.22"

where py >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=py"

if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_CMD=python"
)

if not defined PYTHON_CMD (
    echo Python was not found on this computer.
    echo Install Python and then run this file again.
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

start "Kali SSH" powershell -NoExit -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '%~dp0'; & %PYTHON_CMD% -u '.\Finalscriptkalisubash.py' --host '%KALI_HOST%'"
exit /b 0
