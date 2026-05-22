@echo off
setlocal EnableDelayedExpansion
title Radd Hub v3.0

:: Use venv python if available, otherwise prefer py launcher
set "PYTHON="
if exist "%~dp0.venv\Scripts\python.exe" (
    set "PYTHON=%~dp0.venv\Scripts\python.exe"
) else (
    where py >nul 2>&1
    if not errorlevel 1 (
        py -3 -c "import sys; raise SystemExit(0 if sys.version_info[:2] >= (3,10) else 1)" >nul 2>&1
        if not errorlevel 1 set "PYTHON=py -3"
    )
    if not defined PYTHON set "PYTHON=python"
)

echo.
echo  Starting Radd Hub v3.0 ...
echo  Press Ctrl+C to stop.
echo.

!PYTHON! radd_hub.py run
if errorlevel 1 (
    echo.
    echo  [ERROR] Radd Hub exited with an error.
    echo  If this is a fresh install, run setup.bat first.
    pause
)
endlocal
