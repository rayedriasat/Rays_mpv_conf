# MPV Configuration Setup Script
# This script copies your MPV configuration to %APPDATA%\mpv

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MPV Configuration Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get the script directory (where this script is located)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TargetDir = "$env:APPDATA\mpv"
$ScriptsDir = "$TargetDir\scripts"

# Create target directory if it doesn't exist
Write-Host "Creating MPV config directory..." -ForegroundColor Yellow
if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "  Created: $TargetDir" -ForegroundColor Green
} else {
    Write-Host "  Directory already exists: $TargetDir" -ForegroundColor Gray
}

# Create scripts directory if it doesn't exist
if (-not (Test-Path $ScriptsDir)) {
    New-Item -ItemType Directory -Path $ScriptsDir -Force | Out-Null
    Write-Host "  Created: $ScriptsDir" -ForegroundColor Green
} else {
    Write-Host "  Directory already exists: $ScriptsDir" -ForegroundColor Gray
}

Write-Host ""

# Copy mpv.conf
$ConfigFile = Join-Path $ScriptDir "mpv.conf"
if (Test-Path $ConfigFile) {
    Write-Host "Copying mpv.conf..." -ForegroundColor Yellow
    Copy-Item -Path $ConfigFile -Destination $TargetDir -Force
    Write-Host "  Copied: mpv.conf" -ForegroundColor Green
} else {
    Write-Host "  Warning: mpv.conf not found in script directory" -ForegroundColor Red
}

Write-Host ""

# Copy all Lua scripts
$SourceScriptsDir = Join-Path $ScriptDir "scripts"
if (Test-Path $SourceScriptsDir) {
    Write-Host "Copying Lua scripts..." -ForegroundColor Yellow
    $Scripts = Get-ChildItem -Path $SourceScriptsDir -Filter "*.lua"
    if ($Scripts.Count -gt 0) {
        foreach ($Script in $Scripts) {
            Copy-Item -Path $Script.FullName -Destination $ScriptsDir -Force
            Write-Host "  Copied: $($Script.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "  No Lua scripts found" -ForegroundColor Gray
    }
} else {
    Write-Host "  Warning: scripts directory not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your MPV configuration has been installed to:" -ForegroundColor White
Write-Host "  $TargetDir" -ForegroundColor Cyan
Write-Host ""

# Check if MPV is installed
$mpvInstalled = $false
$mpvPath = Get-Command mpv -ErrorAction SilentlyContinue
if ($mpvPath) {
    $mpvInstalled = $true
    Write-Host "MPV is already installed!" -ForegroundColor Green
    Write-Host "  Location: $($mpvPath.Source)" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  MPV Installation Required" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "MPV is not installed on this system." -ForegroundColor White
    Write-Host ""
    Write-Host "Installation Options:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Chocolatey (Recommended):" -ForegroundColor Yellow
    Write-Host "   choco install mpv" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Download from official website:" -ForegroundColor Yellow
    Write-Host "   https://mpv.io/installation/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "3. Scoop:" -ForegroundColor Yellow
    Write-Host "   scoop install mpv" -ForegroundColor White
    Write-Host ""
    Write-Host "4. Winget:" -ForegroundColor Yellow
    Write-Host "   winget install mpv" -ForegroundColor White
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Success! Your MPV configuration has been installed." -ForegroundColor Green
Write-Host ""
Write-Host "  Press any key to close this window..." -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
