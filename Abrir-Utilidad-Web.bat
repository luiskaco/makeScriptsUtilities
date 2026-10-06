@echo off
title Orange Latam Utilities - Panel Web
cd /d "%~dp0"

:: Auto-elevacion a Administrador para que los reinicios de servicios tengan privilegios
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo ========================================================
echo   INICIANDO PANEL WEB DE UTILIDADES (ORANGE LATAM)
echo ========================================================
echo.
echo Servidor iniciando...
echo Se abrira automaticamente tu navegador (Chrome / Edge)...
echo.

node "%~dp0web\server.js"
if %errorLevel% neq 0 (
    echo [!] Node.js no pudo iniciar el servidor. Intentando con PowerShell...
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0web\server.ps1"
    pause
)
