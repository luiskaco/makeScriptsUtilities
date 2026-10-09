@echo off
title Compilador de Binarios Orange Latam
cd /d "%~dp0"

:: Auto-elevacion a Administrador
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0compilar-binarios.ps1"

echo.
echo Presiona cualquier tecla para cerrar...
pause >nul
