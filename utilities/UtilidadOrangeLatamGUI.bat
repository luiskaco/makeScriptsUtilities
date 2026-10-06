@echo off
:: Launcher para la interfaz grafica WPF de Utilidad Orange Latam
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0UtilidadOrangeLatam.GUI.ps1"
