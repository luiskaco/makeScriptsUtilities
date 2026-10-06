@echo off
title Asistencia Orange
cd /d "%~dp0\.."

powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0..\AsistenciaOrange.ps1"
