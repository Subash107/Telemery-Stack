@echo off
setlocal
cd /d "%~dp0"
set "REPORTS_DIR=%~dp0reports"
if not exist "%REPORTS_DIR%" mkdir "%REPORTS_DIR%" >nul 2>&1

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

for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TIMESTAMP=%%I"
set "OUTPUT_FILE=%REPORTS_DIR%\kali_port_summary_%TIMESTAMP%.txt"
set "TMP_LOCAL=%TEMP%\kali_port_summary_local_%TIMESTAMP%.txt"
set "TMP_VM=%TEMP%\kali_port_summary_vm_%TIMESTAMP%.txt"

echo Kali VM Open Port Summary > "%OUTPUT_FILE%"
echo ================================================================ >> "%OUTPUT_FILE%"
echo Generated on Windows side: %DATE% %TIME% >> "%OUTPUT_FILE%"
echo Remote host: %KALI_HOST% >> "%OUTPUT_FILE%"
echo Summary type: open TCP ports and detected service names only >> "%OUTPUT_FILE%"
echo Collection mode: read-only checks only; no services modified >> "%OUTPUT_FILE%"
echo. >> "%OUTPUT_FILE%"

echo [Scanning localhost TCP ports]
%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "nmap -sT -sV -p- 127.0.0.1" > "%TMP_LOCAL%" 2>&1
echo ================================================================ >> "%OUTPUT_FILE%"
echo Open TCP ports on 127.0.0.1 >> "%OUTPUT_FILE%"
echo ================================================================ >> "%OUTPUT_FILE%"
powershell -NoProfile -Command "$m = Get-Content -LiteralPath '%TMP_LOCAL%' | Where-Object { $_ -match '^\d+/tcp\s+open\s+' }; if($m){ $m } else { 'No open TCP ports found.' }" >> "%OUTPUT_FILE%"
echo. >> "%OUTPUT_FILE%"

echo [Scanning VM IP TCP ports]
%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "nmap -sT -sV -p- %KALI_HOST%" > "%TMP_VM%" 2>&1
echo ================================================================ >> "%OUTPUT_FILE%"
echo Open TCP ports on %KALI_HOST% >> "%OUTPUT_FILE%"
echo ================================================================ >> "%OUTPUT_FILE%"
powershell -NoProfile -Command "$m = Get-Content -LiteralPath '%TMP_VM%' | Where-Object { $_ -match '^\d+/tcp\s+open\s+' }; if($m){ $m } else { 'No open TCP ports found.' }" >> "%OUTPUT_FILE%"
echo. >> "%OUTPUT_FILE%"

del /q "%TMP_LOCAL%" "%TMP_VM%" >nul 2>&1

echo.
echo Port summary complete.
echo Summary saved to:
echo %OUTPUT_FILE%
pause
exit /b 0
