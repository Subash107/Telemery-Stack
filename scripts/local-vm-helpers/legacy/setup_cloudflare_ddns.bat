@echo off
setlocal
cd /d "%~dp0"

set "PYTHON_CMD="
set "SSH_SCRIPT=Finalscriptkalisubash.py"
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

echo.
echo Opening Cloudflare DDNS setup on %KALI_HOST%...
echo Suggested values:
echo   Zone name   : subashlama.com
echo   Zone ID     : fb30a1edffe8ea1ebd8fefefa38159b6
echo   DNS record  : home.subashlama.com
echo   Record type : A
echo   Proxied     : no
echo.
echo Important:
echo   The value above is a Cloudflare Zone ID, not an API token.
echo   Create a fresh API token using the "Edit zone DNS" template for subashlama.com.
echo.

start "Cloudflare DDNS Setup" powershell -NoExit -ExecutionPolicy Bypass -Command "Set-Location -LiteralPath '%~dp0'; & %PYTHON_CMD% -u '.\Finalscriptkalisubash.py' --host '%KALI_HOST%' -c '~/setup_cloudflare_ddns.sh'"
exit /b 0
