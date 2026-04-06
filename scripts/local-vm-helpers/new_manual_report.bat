@echo off
setlocal
cd /d "%~dp0"

set "PYTHON_CMD="

where py >nul 2>&1
if not errorlevel 1 set "PYTHON_CMD=py"

if not defined PYTHON_CMD (
    where python >nul 2>&1
    if not errorlevel 1 set "PYTHON_CMD=python"
)

if not defined PYTHON_CMD (
    echo Python was not found on this computer.
    echo Install Python and run this file again.
    if not defined NO_PAUSE pause
    exit /b 1
)

if not exist "create_manual_report.py" (
    echo Could not find create_manual_report.py in:
    echo %CD%
    if not defined NO_PAUSE pause
    exit /b 1
)

%PYTHON_CMD% -u "%~dp0create_manual_report.py" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not defined NO_PAUSE pause
exit /b %EXIT_CODE%
