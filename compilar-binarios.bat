@echo off
title Compilador de Binarios Orange Latam
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0compilar-binarios.ps1"

echo.
echo Presiona cualquier tecla para cerrar...
pause >nul
