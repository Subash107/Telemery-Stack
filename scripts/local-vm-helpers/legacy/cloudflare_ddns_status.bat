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

set /p "KALI_HOST=Enter Kali VM IP/hostname [%DEFAULT_HOST%]: "
if not defined KALI_HOST set "KALI_HOST=%DEFAULT_HOST%"
if "%KALI_HOST: =%"=="" set "KALI_HOST=%DEFAULT_HOST%"

echo.
echo Checking Cloudflare DDNS status on %KALI_HOST%...
echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "printf 'Cloudflare DDNS files\n======================\n'; for f in /usr/local/bin/cloudflare-ddns.py /usr/local/bin/install-cloudflare-ddns.sh /etc/systemd/system/cloudflare-ddns.service /etc/systemd/system/cloudflare-ddns.timer /etc/cloudflare-ddns.env.example /etc/cloudflare-ddns.env ~/setup_cloudflare_ddns.sh; do if [ -e \"$f\" ]; then ls -l \"$f\"; else echo \"missing: $f\"; fi; done; printf '\nTimer state\n===========\n'; systemctl is-enabled cloudflare-ddns.timer 2>/dev/null || echo disabled; systemctl status cloudflare-ddns.timer --no-pager 2>/dev/null || true; printf '\nLast service logs\n=================\n'; journalctl -u cloudflare-ddns.service -n 20 --no-pager 2>/dev/null || echo 'No service logs yet or access is restricted.';" 

echo.
pause
exit /b 0
