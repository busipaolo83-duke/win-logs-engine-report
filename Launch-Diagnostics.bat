@echo off
title Initializing Diagnostics...

:: 1. Controlla se PowerShell 7 (pwsh) è disponibile nel sistema
where pwsh >nul 2>nul
if %ERRORLEVEL% equ 0 (
    set "PS_EXEC=pwsh"
) else (
    set "PS_EXEC=powershell"
)

:: 2. Avvia lo script passandogli la cartella corrente come riferimento
start "" /b "%PS_EXEC%" -ExecutionPolicy Bypass -NoExit -File "%~dp0Run-Dashboard.ps1"
exit