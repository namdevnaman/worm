@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo  Building Worm for Windows (self-contained folder + ZIP)
echo =======================================================

cd /d "%~dp0\.."

dotnet --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] .NET 9 SDK is not installed or not in PATH.
    echo         Install it from https://dotnet.microsoft.com/download
    exit /b 1
)

if exist dist rmdir /s /q dist
mkdir dist\win-x64

echo [1/3] Restoring dependencies...
dotnet restore Worm.sln
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

REM NOTE: no PublishSingleFile / EnableCompressionInSingleFile.
REM WPF BAML resources cannot be reliably read from a compressed single-file
REM bundle, which is what made v1.0.2 fail to start on Windows.
echo [2/3] Publishing Worm x64 (self-contained folder)...
dotnet publish src\WormUI\WormUI.csproj -c Release -r win-x64 --self-contained true -o dist\win-x64
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo [3/3] Packaging ZIP and checksums...
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package.ps1 -PublishDir dist\win-x64 -OutDir dist
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo.
echo =======================================================
echo  Build Successful!
echo  Portable folder : %CD%\dist\win-x64
echo  ZIP            : %CD%\dist\Worm-Windows-x64.zip
echo  Checksums      : %CD%\dist\SHA256SUMS.txt
echo.
echo  Reminder: Worm is not code-signed, so Windows SmartScreen may warn on
echo  first launch. See README "Windows: if SmartScreen blocks Worm".
echo =======================================================
