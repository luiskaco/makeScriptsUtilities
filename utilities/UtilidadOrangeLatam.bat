@echo off
:: Auto-elevación a permisos de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    powershell -Command "Start-Process cmd -ArgumentList '/c \"%~f0\"' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ===========================================
echo       MENU DE REINICIO DE SERVICIOS
echo ===========================================
echo 1) Reiniciar Explorador de Windows
echo 2) Reiniciar Wi-Fi / Red (Flush DNS + Adaptador)
echo 3) Reiniciar Cola de Impresion (Spooler)
echo 4) Reiniciar Servicio de Audio
echo 5) Reiniciar Windows Update
echo 6) Salir
echo ===========================================
set /p opcion="Selecciona una opcion [1-6]: "

if "%opcion%"=="1" goto RESTART_EXPLORER
if "%opcion%"=="2" goto RESTART_NET
if "%opcion%"=="3" goto RESTART_SPOOLER
if "%opcion%"=="4" goto RESTART_AUDIO
if "%opcion%"=="5" goto RESTART_UPDATE
if "%opcion%"=="6" exit /b
goto MENU

:RESTART_EXPLORER
echo Reiniciando Explorador de Windows...
taskkill /f /im explorer.exe >nul 2>&1
start explorer.exe
pause
goto MENU

:RESTART_NET
echo Reiniciando adaptador Wi-Fi...
netsh interface set interface name="Wi-Fi" admin=disable
timeout /t 2 /nobreak >nul
netsh interface set interface name="Wi-Fi" admin=enable

echo Vaciando cache DNS...
ipconfig /flushdns

echo Esperando conexion a la red...
timeout /t 4 /nobreak >nul
ipconfig /renew
pause
goto MENU

:RESTART_SPOOLER
echo Reiniciando Cola de Impresion...
net stop Spooler
net start Spooler
pause
goto MENU

:RESTART_AUDIO
echo Reiniciando Audio de Windows...
net stop Audiosrv
net start Audiosrv
net stop AudioEndpointBuilder
net start AudioEndpointBuilder
pause
goto MENU

:RESTART_UPDATE
echo Reiniciando Windows Update...
net stop wuauserv
net start wuauserv
pause
goto MENU


