@echo off
title Utilidades Orange Latam
cd /d "%~dp0"

if exist "%~dp0UtilidadOrangeLatam.exe" (
    start "" "%~dp0UtilidadOrangeLatam.exe"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0UtilidadOrangeLatam.GUI.ps1"
exit /b
