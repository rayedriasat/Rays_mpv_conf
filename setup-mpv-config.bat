@echo off
REM MPV Configuration Setup Script (Batch Version)
REM This script copies your MPV configuration to %APPDATA%\mpv

echo ========================================
echo   MPV Configuration Setup
echo ========================================
echo.

REM Get the script directory
set "SCRIPT_DIR=%~dp0"
set "TARGET_DIR=%APPDATA%\mpv"
set "SCRIPTS_DIR=%TARGET_DIR%\scripts"

REM Create target directory if it doesn't exist
echo Creating MPV config directory...
if not exist "%TARGET_DIR%" (
    mkdir "%TARGET_DIR%"
    echo   Created: %TARGET_DIR%
) else (
    echo   Directory already exists: %TARGET_DIR%
)

REM Create scripts directory if it doesn't exist
if not exist "%SCRIPTS_DIR%" (
    mkdir "%SCRIPTS_DIR%"
    echo   Created: %SCRIPTS_DIR%
) else (
    echo   Directory already exists: %SCRIPTS_DIR%
)

echo.

REM Copy mpv.conf
if exist "%SCRIPT_DIR%mpv.conf" (
    echo Copying mpv.conf...
    copy /Y "%SCRIPT_DIR%mpv.conf" "%TARGET_DIR%\mpv.conf" >nul
    echo   Copied: mpv.conf
) else (
    echo   Warning: mpv.conf not found in script directory
)

echo.

REM Copy all Lua scripts
if exist "%SCRIPT_DIR%scripts" (
    echo Copying Lua scripts...
    for %%f in ("%SCRIPT_DIR%scripts\*.lua") do (
        copy /Y "%%f" "%SCRIPTS_DIR%\" >nul
        echo   Copied: %%~nxf
    )
) else (
    echo   Warning: scripts directory not found
)

echo.
echo ========================================
echo   Configuration Complete!
echo ========================================
echo.
echo Your MPV configuration has been installed to:
echo   %TARGET_DIR%
echo.

REM Check if MPV is installed
where mpv >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo MPV is already installed!
    echo.
) else (
    echo ========================================
    echo   MPV Installation Required
    echo ========================================
    echo.
    echo MPV is not installed on this system.
    echo.
    echo Installation Options:
    echo.
    echo 1. Chocolatey (Recommended):
    echo    choco install mpv
    echo.
    echo 2. Download from official website:
    echo    https://mpv.io/installation/
    echo.
    echo 3. Scoop:
    echo    scoop install mpv
    echo.
    echo 4. Winget:
    echo    winget install mpv
    echo.
)

echo ========================================
echo.
echo   Success! Your MPV configuration has been installed.
echo.
echo   Press any key to close this window...
echo ========================================
pause >nul
