@echo off
REM ===================================================================
REM  Worm for Windows - double-click installer
REM
REM  Windows marks every file downloaded from the internet with a
REM  "Mark of the Web", and because Worm is not code-signed, SmartScreen
REM  refuses to launch it. This installer clears that mark, verifies the
REM  download, installs Worm for the current user (NO administrator rights
REM  needed), creates shortcuts, and launches it.
REM
REM  Just double-click this file. To uninstall, run Uninstall-Worm.cmd.
REM ===================================================================
setlocal
title Worm Installer

echo.
echo   ============================================
echo             Worm  -  Setup
echo   ============================================
echo.

REM Always run the PowerShell installer from THIS folder.
cd /d "%~dp0"

if not exist "Worm.exe" (
    echo   [X] Worm.exe was not found next to this file.
    echo       Extract the whole ZIP first, then run Install-Worm.cmd again.
    echo.
    pause
    exit /b 1
)

where powershell >nul 2>&1
if errorlevel 1 (
    echo   [X] Windows PowerShell is not available on this system.
    echo.
    pause
    exit /b 1
)

REM -NoProfile avoids loading any user profile that could break the run.
REM -ExecutionPolicy Bypass is scoped to this one process only.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Worm.ps1" %*
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
    echo   Setup finished.
) else (
    echo   Setup did not complete ^(exit code %RC%^).
    echo   Scroll up for the error message.
)
echo.
pause
exit /b %RC%
