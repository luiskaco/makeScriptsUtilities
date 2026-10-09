@echo off
title Asistencia Orange
cd /d "%~dp0"

if exist "%~dp0AsistenciaOrange.exe" (
    start "" "%~dp0AsistenciaOrange.exe"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0AsistenciaOrange.ps1"
exit /b
