@echo off
setlocal enabledelayedexpansion
title Radd Hub v3.0 -- Setup
cd /d "%~dp0"

echo.
echo +====================================================+
echo         Radd Hub v3.0 -- Windows Setup
echo +====================================================+
echo.

:: Step 1: Find Python
set "PYTHON="
where py >nul 2>&1
if not errorlevel 1 (
    py -3 -c "import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)" >nul 2>&1
    if not errorlevel 1 set "PYTHON=py -3"
)
if not defined PYTHON (
    for %%C in (python3 python) do (
        %%C -c "import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)" >nul 2>&1
        if not errorlevel 1 (
            set "PYTHON=%%C"
            goto :py_found
        )
    )
)
if not defined PYTHON (
    echo [FAIL] Python 3.10+ not found.
    pause
    exit /b 1
)
:py_found

:: Step 2: Delegate to radd_hub.py setup
echo [info] Running setup via radd_hub.py ...
!PYTHON! radd_hub.py setup --fix

if errorlevel 1 (
    echo.
    echo [WARN] Setup finished with some warnings.
) else (
    echo.
    echo [SUCCESS] Setup complete.
)

echo.
echo   Start with:  start.bat
echo   Or manually: python radd_hub.py run
echo.
pause
endlocal
