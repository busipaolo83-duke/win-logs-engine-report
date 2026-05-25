@echo off
title Initializing Diagnostics...

:: 1. Check if PowerShell 7 (pwsh) is available on your system
where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXEC=pwsh"
) else (
    set "PS_EXEC=powershell"
)

:: 2. Start the script by passing it the current folder as a reference
start "" /b "%PS_EXEC%" -ExecutionPolicy Bypass -NoExit -File "%~dp0Run-Dashboard.ps1"
exit