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
set "OUTPUT_FILE=%REPORTS_DIR%\kali_port_check_%TIMESTAMP%.txt"

echo Kali VM Port Check Report > "%OUTPUT_FILE%"
echo ================================================================ >> "%OUTPUT_FILE%"
echo Generated on Windows side: %DATE% %TIME% >> "%OUTPUT_FILE%"
echo Remote host: %KALI_HOST% >> "%OUTPUT_FILE%"
echo Collection mode: read-only checks only; no services modified >> "%OUTPUT_FILE%"
echo. >> "%OUTPUT_FILE%"

call :RunSection "Listening Ports from ss" "ss -tulpn"
call :RunSection "Docker Published Ports" "docker ps --format ""table {{.Names}}\t{{.Ports}}"""
call :RunSection "Localhost TCP Services" "nmap -sT -sV 127.0.0.1"
call :RunSection "Common TCP Ports on VM IP" "nmap -sT -sV -p 22,80,443,1883,3000,5000,8000,8080,9000 %KALI_HOST%"

echo.
echo Port check complete.
echo Report saved to:
echo %OUTPUT_FILE%
pause
exit /b 0

:RunSection
set "SECTION_TITLE=%~1"
set "REMOTE_COMMAND=%~2"

echo [%SECTION_TITLE%]
>> "%OUTPUT_FILE%" echo ================================================================
>> "%OUTPUT_FILE%" echo %SECTION_TITLE%
>> "%OUTPUT_FILE%" echo ================================================================
>> "%OUTPUT_FILE%" echo.

%PYTHON_CMD% -u "%SSH_SCRIPT%" --host "%KALI_HOST%" -c "%REMOTE_COMMAND%" >> "%OUTPUT_FILE%" 2>&1

>> "%OUTPUT_FILE%" echo.
>> "%OUTPUT_FILE%" echo.
exit /b 0
