@echo off
REM ===================================================================
REM  Worm for Windows - double-click uninstaller
REM
REM  Removes the app, its shortcuts and its Start-menu entry.
REM  Your logs and protected-path settings are kept unless you type -Purge.
REM ===================================================================
setlocal
title Worm Uninstaller

echo.
echo   ============================================
echo           Worm  -  Uninstall
echo   ============================================
echo.

cd /d "%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo   [X] Windows PowerShell is not available on this system.
    echo.
    pause
    exit /b 1
)

REM If this script was run from the Start-menu uninstall entry, the PowerShell
REM uninstaller sits next to it. Otherwise fall back to the default location.
set "PS1=%~dp0Uninstall-Worm.ps1"
if not exist "%PS1%" set "PS1=%LOCALAPPDATA%\Programs\Worm\Uninstall-Worm.ps1"

if not exist "%PS1%" (
    echo   [X] Could not find Uninstall-Worm.ps1.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" echo   Uninstall did not complete ^(exit code %RC%^).
echo.
pause
exit /b %RC%
