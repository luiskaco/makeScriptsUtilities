@echo off
title Cerrar Procesos Bloqueados - Orange Latam
cd /d "%~dp0"

echo Forzando cierre de AsistenciaOrange.exe y utilidades...
taskkill /F /IM AsistenciaOrange.exe /T 2>nul
taskkill /F /IM UtilidadOrangeLatam.exe /T 2>nul
wmic process where "name='AsistenciaOrange.exe'" call terminate 2>nul

echo.
echo Proceso finalizado. Puedes cerrar esta ventana.
timeout /t 3 >nul
