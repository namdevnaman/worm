@echo off
setlocal enabledelayedexpansion

echo =======================================================
echo Building Worm for Windows (Self-Contained Single Binary)
echo =======================================================

cd /d "%~dp0\.."

dotnet --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] .NET 9 SDK is not installed or not in PATH.
    echo Please install .NET 9 SDK from https://dotnet.microsoft.com/download
    exit /b 1
)

echo [1/3] Restoring dependencies...
dotnet restore Worm.sln
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo [2/3] Publishing Worm x64 (Single-File Executable)...
dotnet publish src\WormUI\WormUI.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:EnableCompressionInSingleFile=true -o dist\win-x64
if %ERRORLEVEL% NEQ 0 exit /b %ERRORLEVEL%

echo.
echo =======================================================
echo Build Successful!
echo Executable generated at:
echo %CD%\dist\win-x64\Worm.exe
echo =======================================================
