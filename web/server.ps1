<#
.SYNOPSIS
    Orange Latam - Servidor Web Local y API de Utilidades
    Expone una interfaz gráfica en el navegador web (Chrome, Edge, Firefox)
    y gestiona las operaciones de administración de Windows en segundo plano.
#>

[CmdletBinding()]
param(
    [int]$Port = 5050
)

# Auto-elevación a permisos de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[*] Solicitando permisos de Administrador..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Orange Latam Web Dashboard Server - Puerto $Port"
$webDir = Split-Path -Parent $PSCommandPath
$rootDir = Split-Path -Parent $webDir

Clear-Host
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "     ORANGE LATAM • SERVIDOR WEB DE CONTROL WINDOWS         " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "[✓] Modo Administrador: Activo" -ForegroundColor Green
Write-Host "[✓] Directorio Web: $webDir" -ForegroundColor Gray
Write-Host "[*] Iniciando servidor en: http://localhost:$Port/" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "  Presiona Ctrl + C en esta ventana para detener el servidor " -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""

# Iniciar HttpListener
$listener = New-Object System.Net.HttpListener
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)

try {
    $listener.Start()
}
catch {
    Write-Host "[✕ ERROR] No se pudo iniciar el listener en el puerto $Port: $_" -ForegroundColor Red
    Write-Host "[*] Intentando en puerto alternativo 5051..." -ForegroundColor Yellow
    $Port = 5051
    $prefix = "http://localhost:$Port/"
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add($prefix)
    $listener.Start()
}

# Abrir el navegador predeterminado automáticamente
Write-Host "[+] Abriendo navegador web en: $prefix" -ForegroundColor Green
Start-Process $prefix

function Send-JsonResponse {
    param(
        $Response,
        $Data,
        [int]$StatusCode = 200
    )
    $json = $Data | ConvertTo-Json -Depth 6 -Compress
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.ContentLength64 = $buffer.Length
    $Response.AddHeader("Access-Control-Allow-Origin", "*")
    $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    $Response.OutputStream.Close()
}

function Send-FileResponse {
    param(
        $Response,
        [string]$FilePath,
        [string]$ContentType
    )
    if (Test-Path $FilePath) {
        $content = [System.IO.File]::ReadAllBytes($FilePath)
        $Response.StatusCode = 200
        $Response.ContentType = $ContentType
        $Response.ContentLength64 = $content.Length
        $Response.OutputStream.Write($content, 0, $content.Length)
    } else {
        $Response.StatusCode = 404
        $notFoundMsg = [System.Text.Encoding]::UTF8.GetBytes("404 - Not Found")
        $Response.OutputStream.Write($notFoundMsg, 0, $notFoundMsg.Length)
    }
    $Response.OutputStream.Close()
}

# Bucle principal de atención de peticiones HTTP
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        $urlPath = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        # Manejo de Pre-flight CORS
        if ($method -eq "OPTIONS") {
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
            $response.StatusCode = 200
            $response.OutputStream.Close()
            continue
        }

        # --- RUTAS ESTÁTICAS ---
        if ($urlPath -eq "/" -or $urlPath -eq "/index.html") {
            Send-FileResponse $response (Join-Path $webDir "index.html") "text/html; charset=utf-8"
            continue
        }
        if ($urlPath -eq "/styles.css") {
            Send-FileResponse $response (Join-Path $webDir "styles.css") "text/css; charset=utf-8"
            continue
        }
        if ($urlPath -eq "/app.js") {
            Send-FileResponse $response (Join-Path $webDir "app.js") "application/javascript; charset=utf-8"
            continue
        }

        # --- API STATUS ---
        if ($urlPath -eq "/api/status" -and $method -eq "GET") {
            $statusObj = @{
                isAdmin = $isAdmin
                hostName = $env:COMPUTERNAME
                port = $Port
                timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            }
            Send-JsonResponse $response $statusObj
            continue
        }

        # --- API ACCIONES ---
        if ($urlPath.StartsWith("/api/action/") -and $method -eq "POST") {
            $action = $urlPath.Substring("/api/action/".Length)
            $logs = [System.Collections.Generic.List[PSObject]]::new()
            $success = $true
            $errorMsg = $null

            Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] Petición API recibida: $action" -ForegroundColor Cyan

            try {
                switch ($action) {
                    # 1. Explorador
                    "explorer" {
                        $logs.Add(@{ msg = "Finalizando proceso explorer.exe..."; type = "INFO" })
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Milliseconds 800
                        $logs.Add(@{ msg = "Iniciando nuevo proceso explorer.exe..."; type = "INFO" })
                        Start-Process "explorer.exe"
                        $logs.Add(@{ msg = "Explorador de Windows reiniciado exitosamente."; type = "OK" })
                    }

                    # 2. Red / Wi-Fi
                    "wifi" {
                        $logs.Add(@{ msg = "Deshabilitando interfaz Wi-Fi..."; type = "INFO" })
                        & netsh interface set interface name="Wi-Fi" admin=disable | Out-Null
                        Start-Sleep -Seconds 2
                        
                        $logs.Add(@{ msg = "Habilitando interfaz Wi-Fi..."; type = "INFO" })
                        & netsh interface set interface name="Wi-Fi" admin=enable | Out-Null
                        
                        $logs.Add(@{ msg = "Vaciando caché DNS (FlushDNS)..."; type = "INFO" })
                        & ipconfig /flushdns | Out-Null
                        
                        Start-Sleep -Seconds 3
                        $logs.Add(@{ msg = "Renovando configuración de IP por DHCP (Renew)..."; type = "INFO" })
                        & ipconfig /renew | Out-Null
                        
                        $logs.Add(@{ msg = "Subsistema de Red y Wi-Fi reiniciado por completo."; type = "OK" })
                    }

                    # 3. Spooler
                    "spooler" {
                        $logs.Add(@{ msg = "Deteniendo servicio de Cola de Impresión (Spooler)..."; type = "INFO" })
                        & net stop Spooler 2>&1 | Out-Null
                        Start-Sleep -Milliseconds 500
                        $logs.Add(@{ msg = "Iniciando servicio Spooler..."; type = "INFO" })
                        & net start Spooler 2>&1 | Out-Null
                        $logs.Add(@{ msg = "Cola de Impresión reiniciada correctamente."; type = "OK" })
                    }

                    # 4. Audio
                    "audio" {
                        $logs.Add(@{ msg = "Deteniendo servicios de Audio (Audiosrv & AudioEndpointBuilder)..."; type = "INFO" })
                        & net stop Audiosrv /y 2>&1 | Out-Null
                        & net stop AudioEndpointBuilder /y 2>&1 | Out-Null
                        Start-Sleep -Milliseconds 500
                        $logs.Add(@{ msg = "Iniciando AudioEndpointBuilder..."; type = "INFO" })
                        & net start AudioEndpointBuilder 2>&1 | Out-Null
                        $logs.Add(@{ msg = "Iniciando Audiosrv..."; type = "INFO" })
                        & net start Audiosrv 2>&1 | Out-Null
                        $logs.Add(@{ msg = "Servicios de audio reiniciados con éxito."; type = "OK" })
                    }

                    # 5. Windows Update
                    "update" {
                        $logs.Add(@{ msg = "Deteniendo servicio de Windows Update (wuauserv)..."; type = "INFO" })
                        & net stop wuauserv 2>&1 | Out-Null
                        Start-Sleep -Milliseconds 500
                        $logs.Add(@{ msg = "Iniciando servicio Windows Update..."; type = "INFO" })
                        & net start wuauserv 2>&1 | Out-Null
                        $logs.Add(@{ msg = "Windows Update reiniciado exitosamente."; type = "OK" })
                    }

                    # 6. Mantenimiento Completo
                    "all" {
                        $logs.Add(@{ msg = "=== INICIANDO MANTENIMIENTO INTEGRAL ==="; type = "INFO" })
                        
                        $logs.Add(@{ msg = "[1/5] Reiniciando Spooler de impresión..."; type = "INFO" })
                        & net stop Spooler 2>&1 | Out-Null
                        & net start Spooler 2>&1 | Out-Null

                        $logs.Add(@{ msg = "[2/5] Reiniciando subsistema de audio..."; type = "INFO" })
                        & net stop Audiosrv /y 2>&1 | Out-Null
                        & net stop AudioEndpointBuilder /y 2>&1 | Out-Null
                        & net start AudioEndpointBuilder 2>&1 | Out-Null
                        & net start Audiosrv 2>&1 | Out-Null

                        $logs.Add(@{ msg = "[3/5] Reiniciando servicio de Windows Update..."; type = "INFO" })
                        & net stop wuauserv 2>&1 | Out-Null
                        & net start wuauserv 2>&1 | Out-Null

                        $logs.Add(@{ msg = "[4/5] Reiniciando red y resolviendo DNS..."; type = "INFO" })
                        & netsh interface set interface name="Wi-Fi" admin=disable 2>&1 | Out-Null
                        Start-Sleep -Seconds 2
                        & netsh interface set interface name="Wi-Fi" admin=enable 2>&1 | Out-Null
                        & ipconfig /flushdns | Out-Null
                        Start-Sleep -Seconds 2
                        & ipconfig /renew | Out-Null

                        $logs.Add(@{ msg = "[5/5] Reiniciando interfaz gráfica del explorador..."; type = "INFO" })
                        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                        Start-Sleep -Milliseconds 800
                        Start-Process "explorer.exe"

                        $logs.Add(@{ msg = "=== MANTENIMIENTO INTEGRAL FINALIZADO ==="; type = "OK" })
                    }

                    # 7. Hardware Info
                    "info" {
                        $logs.Add(@{ msg = "Consultando telemetría WMI/CIM..."; type = "INFO" })
                        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
                        $os = Get-CimInstance Win32_OperatingSystem
                        $ramTotal = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
                        $disk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
                        $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

                        $infoData = @{
                            cpu = @{
                                name = $cpu.Name.Trim()
                                cores = $cpu.NumberOfCores
                                threads = $cpu.NumberOfLogicalProcessors
                            }
                            ram = @{
                                total = "{0:N1} GB" -f ($ramTotal / 1GB)
                                free = "{0:N1} GB" -f ($os.FreePhysicalMemory / 1MB)
                            }
                            disk = @{
                                model = $disk.Model
                                free = "{0:N1} GB libres de {1:N1} GB" -f ($diskC.FreeSpace / 1GB), ($diskC.Size / 1GB)
                            }
                            os = @{
                                caption = $os.Caption
                                build = $os.BuildNumber
                            }
                        }

                        $logs.Add(@{ msg = "Métricas recopiladas: CPU: $($cpu.Name.Trim()), RAM: {0:N1} GB" -f ($ramTotal / 1GB); type = "OK" })

                        Send-JsonResponse $response @{
                            success = $true
                            logs = $logs
                            info = $infoData
                        }
                        continue
                    }

                    # 8. Limpiar Perfil
                    "clean-profile" {
                        $logs.Add(@{ msg = "Iniciando respaldo y limpieza de perfil de usuario..."; type = "INFO" })
                        $userProfile = $env:USERPROFILE
                        $backupDir = Join-Path $userProfile "Desktop\Respaldo_Usuario"
                        
                        New-Item -ItemType Directory -Path "$backupDir\Escritorio" -Force | Out-Null
                        New-Item -ItemType Directory -Path "$backupDir\Descargas" -Force | Out-Null
                        New-Item -ItemType Directory -Path "$backupDir\Documentos" -Force | Out-Null

                        $logs.Add(@{ msg = "Moviendo archivos de Escritorio a Respaldo_Usuario..."; type = "INFO" })
                        & robocopy "$userProfile\Desktop" "$backupDir\Escritorio" *.* /E /MOVE /XF "desktop.ini" /XD "Respaldo_Usuario" /R:1 /W:1 2>&1 | Out-Null

                        $logs.Add(@{ msg = "Moviendo archivos de Descargas..."; type = "INFO" })
                        & robocopy "$userProfile\Downloads" "$backupDir\Descargas" *.* /E /MOVE /R:1 /W:1 2>&1 | Out-Null

                        $logs.Add(@{ msg = "Moviendo archivos de Documentos..."; type = "INFO" })
                        & robocopy "$userProfile\Documents" "$backupDir\Documentos" *.* /E /MOVE /XF "desktop.ini" /R:1 /W:1 2>&1 | Out-Null

                        $logs.Add(@{ msg = "Restableciendo fondo de pantalla predeterminado..."; type = "INFO" })
                        $defaultWallpaper = "$env:SystemRoot\Web\Wallpaper\Windows\img0.jpg"
                        if (Test-Path $defaultWallpaper) {
                            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "Wallpaper" -Value $defaultWallpaper
                            Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WallpaperStyle" -Value "2"
                            rundll32.exe user32.dll,UpdatePerUserSystemParameters
                        }

                        $logs.Add(@{ msg = "Perfil respaldado en '$backupDir' y limpiado con éxito."; type = "OK" })
                    }

                    # 9. Comprobar Actualizaciones Winget
                    "check-upgrades" {
                        $logs.Add(@{ msg = "Ejecutando 'winget upgrade' para escanear paquetes..."; type = "INFO" })
                        $wingetOutput = & winget upgrade 2>&1 | Out-String
                        $lines = $wingetOutput -split "`r?`n"
                        foreach ($line in $lines) {
                            if (-not [string]::IsNullOrWhiteSpace($line)) {
                                $logs.Add(@{ msg = $line; type = "INFO" })
                            }
                        }
                        $logs.Add(@{ msg = "Escaneo de actualizaciones finalizado.", type = "OK" })
                    }

                    # 10. Actualizar Apps Winget
                    "upgrade-apps" {
                        $logs.Add(@{ msg = "Iniciando actualización masiva con winget upgrade --all..."; type = "INFO" })
                        & winget upgrade --all --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
                        $logs.Add(@{ msg = "Proceso de actualización masiva completado.", type = "OK" })
                    }

                    default {
                        $logs.Add(@{ msg = "Acción desconocida: $action"; type = "ERROR" })
                        $success = $false
                        $errorMsg = "Acción no implementada."
                    }
                }
            }
            catch {
                $success = $false
                $errorMsg = $_.Exception.Message
                $logs.Add(@{ msg = "Error: $errorMsg"; type = "ERROR" })
            }

            Send-JsonResponse $response @{
                success = $success
                error = $errorMsg
                logs = $logs
            }
            continue
        }

        # Ruta no encontrada
        Send-FileResponse $response (Join-Path $webDir "index.html") "text/html; charset=utf-8"
    }
}
finally {
    $listener.Stop()
    $listener.Close()
    Write-Host "[*] Servidor detenido." -ForegroundColor Yellow
}
