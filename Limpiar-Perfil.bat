@echo off
title Limpiador de Perfil Premium (Vitaminado)
color 0B

:: 1. Definir rutas de origen del usuario actual
set "DESKTOP=%USERPROFILE%\Desktop"
set "DOWNLOADS=%USERPROFILE%\Downloads"
set "DOCUMENTS=%USERPROFILE%\Documents"
set "BACKUP=%USERPROFILE%\Desktop\Respaldo_Usuario"

echo ====================================================================
echo      INICIANDO LIMPIEZA Y RESTABLECIMIENTO AUTOMATICO
echo ====================================================================
echo.

:: 2. Crear la estructura de carpetas de respaldo dentro del Escritorio
if not exist "%BACKUP%\Escritorio" mkdir "%BACKUP%\Escritorio"
if not exist "%BACKUP%\Descargas" mkdir "%BACKUP%\Descargas"
if not exist "%BACKUP%\Documentos" mkdir "%BACKUP%\Documentos"

:: 3. Mover contenido de Escritorio (Excluyendo la propia carpeta Respaldo_Usuario y archivos de sistema)
echo [+] Vaciando contenido de Escritorio...
robocopy "%DESKTOP%" "%BACKUP%\Escritorio" *.* /E /MOVE /XF "desktop.ini" /XD "Respaldo_Usuario" /R:1 /W:1 > nul

:: 4. Mover contenido de Descargas
echo [+] Vaciando contenido de Descargas...
robocopy "%DOWNLOADS%" "%BACKUP%\Descargas" *.* /E /MOVE /R:1 /W:1 > nul

:: 5. Mover contenido de Documentos
echo [+] Vaciando contenido de Documentos...
robocopy "%DOCUMENTS%" "%BACKUP%\Documentos" *.* /E /MOVE /XF "desktop.ini" /R:1 /W:1 > nul

:: 6. Restablecer el Fondo de Pantalla por Defecto de Windows
echo [+] Restableciendo el fondo de pantalla predeterminado...
set "DEFAULT_WALLPAPER=%SystemRoot%\Web\Wallpaper\Windows\img0.jpg"

if exist "%DEFAULT_WALLPAPER%" (
    :: Cambiar el registro para apuntar a la imagen oficial por defecto
    reg add "HKCU\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "%DEFAULT_WALLPAPER%" /f > nul
    reg add "HKCU\Control Panel\Desktop" /v WallpaperStyle /t REG_SZ /d "2" /f > nul
    
    :: Forzar la actualizacion del entorno visual de inmediato sin reiniciar
    RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters > nul
    echo [OK] Fondo de pantalla restablecido.
) else (
    echo [!] No se encontro la imagen por defecto de Windows, se omitio este paso.
)

:: 7. Fin del proceso
echo.
echo ====================================================================
echo   PROCESO TERMINADO CON EXITO
echo   - Escritorio, Descargas y Documentos han sido limpiados.
echo   - Todo se unifico en la carpeta: Escritorio\Respaldo_Usuario
echo   - El fondo de pantalla ha vuelto al original de Windows.
echo ====================================================================
echo.
pause
exit