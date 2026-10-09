@echo off
title Cerrar Procesos Bloqueados - Orange Latam
cd /d "%~dp0"

:: Auto-elevacion a Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo Forzando cierre de AsistenciaOrange.exe y utilidades...
taskkill /F /IM AsistenciaOrange.exe /T 2>nul
taskkill /F /IM UtilidadOrangeLatam.exe /T 2>nul
taskkill /F /IM ActualizarApps.exe /T 2>nul
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Process -Name 'AsistenciaOrange','UtilidadOrangeLatam','ActualizarApps' -ErrorAction SilentlyContinue | Stop-Process -Force" 2>nul

echo.
echo Proceso finalizado. Se han cerrado todas las instancias.
timeout /t 2 >nul
exit /b
