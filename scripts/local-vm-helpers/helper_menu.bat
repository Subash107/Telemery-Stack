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
    pause
    exit /b 1
)

if not exist "helper_menu.py" (
    echo Could not find helper_menu.py in:
    echo %CD%
    pause
    exit /b 1
)

%PYTHON_CMD% -u "%~dp0helper_menu.py"
exit /b %ERRORLEVEL%
