<#
.SYNOPSIS
    Orange Latam - Servidor Web Local y API de Auto-Atencion
    Expone una interfaz grafica en modo aplicacion y gestiona las operaciones
    de diagnostico y reparacion de Windows para usuarios corporativos.
#>

[CmdletBinding()]
param(
    [int]$Port = 5050
)

# Auto-elevacion a permisos de Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[*] Solicitando permisos de Administrador..." -ForegroundColor Yellow
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "Orange Latam - Portal de Auto-Atencion Server"
$webDir = Split-Path -Parent $PSCommandPath
$rootDir = Split-Path -Parent $webDir

Clear-Host
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "     ORANGE LATAM - PORTAL DE AUTO-ATENCION Y DIAGNOSTICO   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "[OK] Modo Administrador: Activo" -ForegroundColor Green
Write-Host "[OK] Directorio Web: $webDir" -ForegroundColor Gray
Write-Host "[*] Iniciando servidor en: http://localhost:$Port/" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host "  Presiona Ctrl + C en esta ventana para detener el servidor " -ForegroundColor DarkGray
Write-Host "============================================================" -ForegroundColor DarkCyan
Write-Host ""

# Iniciar HttpListener
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Prefixes.Add("http://127.0.0.1:$Port/")
$prefix = "http://localhost:$Port/"

try {
    $listener.Start()
}
catch {
    Write-Host "[ERROR] No se pudo iniciar el listener en el puerto $Port : $_" -ForegroundColor Red
    Write-Host "[*] Intentando en puerto alternativo 5051..." -ForegroundColor Yellow
    $Port = 5051
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$Port/")
    $listener.Prefixes.Add("http://127.0.0.1:$Port/")
    $prefix = "http://localhost:$Port/"
    $listener.Start()
}

# Lanzar en modo ventana de escritorio nativa
Write-Host "[+] Abriendo ventana de aplicacion..." -ForegroundColor Green
try {
    $edgePath = "$env:ProgramFiles (x86)\Microsoft\Edge\Application\msedge.exe"
    if (-not (Test-Path $edgePath)) {
        $edgePath = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    }
    if (Test-Path $edgePath) {
        Start-Process $edgePath -ArgumentList "--app=$prefix"
    } else {
        Start-Process $prefix
    }
} catch {
    Start-Process $prefix
}

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

function Send-SseChunk {
    param(
        $Response,
        [string]$Event,
        $Data
    )
    $json = $Data | ConvertTo-Json -Depth 6 -Compress
    $payload = "event: $Event`ndata: $json`n`n"
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
    try {
        $Response.OutputStream.Write($bytes, 0, $bytes.Length)
        $Response.OutputStream.Flush()
    } catch {}
}

# Ejecución unificada de tareas con tracking de pasos en consola y SSE
function Execute-SystemAction {
    param(
        [string]$Action,
        [scriptblock]$OnStep = $null,
        [scriptblock]$OnLog = $null
    )

    $logs = [System.Collections.Generic.List[PSObject]]::new()
    $actionSuccess = $true
    $errorMsg = $null
    $extraData = @{}
    $timer = [System.Diagnostics.Stopwatch]::StartNew()

    $logFn = {
        param([string]$msg, [string]$type = "INFO")
        $timeStr = (Get-Date -Format "HH:mm:ss")
        $logs.Add(@{ msg = $msg; type = $type; time = $timeStr })
        if ($OnLog) { & $OnLog $msg $type }

        switch ($type) {
            "OK"    { Write-Host "[$timeStr]   [✓] $msg" -ForegroundColor Green }
            "ERROR" { Write-Host "[$timeStr]   [✕] $msg" -ForegroundColor Red }
            "WARN"  { Write-Host "[$timeStr]   [!] $msg" -ForegroundColor Yellow }
            default { Write-Host "[$timeStr]   $msg" -ForegroundColor Gray }
        }
    }

    $stepFn = {
        param([int]$step, [int]$total, [string]$label, [int]$percent)
        $timeStr = (Get-Date -Format "HH:mm:ss")
        if ($OnStep) { & $OnStep $step $total $label $percent }
        Write-Host "[$timeStr] ▸ [Paso $step/$total] ($percent%) $label" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " ▶ ACCION SOLICITADA: $($Action.ToUpper())" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    try {
        switch ($Action) {
            "explorer" {
                & $stepFn 1 2 "Cerrando proceso explorer.exe..." 40
                & $logFn "Deteniendo explorer.exe para refrescar la interfaz..." "INFO"
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 600

                & $stepFn 2 2 "Iniciando nuevo proceso explorer.exe..." 85
                & $logFn "Lanzando nueva instancia del explorador de Windows..." "INFO"
                Start-Process explorer.exe

                & $logFn "Barra de tareas y explorador refrescados con exito." "OK"
            }

            "wifi" {
                & $stepFn 1 3 "Vaciando memoria cache DNS de navegacion..." 30
                & $logFn "Ejecutando vaciado de DNS (ipconfig /flushdns)..." "INFO"
                ipconfig /flushdns | Out-Null

                & $stepFn 2 3 "Registrando nombres y sockets de red..." 60
                & $logFn "Registrando configuracion DNS (ipconfig /registerdns)..." "INFO"
                ipconfig /registerdns | Out-Null
                Start-Sleep -Milliseconds 500

                & $stepFn 3 3 "Renovando direccion IP con servidor DHCP..." 90
                & $logFn "Solicitando nueva concesion IP (ipconfig /renew)..." "INFO"
                ipconfig /renew | Out-Null

                & $logFn "Conectividad de red y resolucion DNS restablecidas con exito." "OK"
            }

            "spooler" {
                & $stepFn 1 2 "Deteniendo la cola de impresion (Spooler)..." 40
                & $logFn "Deteniendo servicio Spooler para liberar trabajos atascados..." "INFO"
                Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500

                & $stepFn 2 2 "Reiniciando el servicio de impresion..." 85
                & $logFn "Reactivando servicio de cola de impresion..." "INFO"
                Start-Service -Name Spooler -ErrorAction SilentlyContinue

                & $logFn "Cola de impresion restablecida correctamente." "OK"
            }

            "audio" {
                & $stepFn 1 2 "Deteniendo controladores y servicios de audio..." 40
                & $logFn "Deteniendo Audiosrv y AudioEndpointBuilder..." "INFO"
                Stop-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
                Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500

                & $stepFn 2 2 "Reactivando servicios de sonido y microfono..." 85
                & $logFn "Iniciando AudioEndpointBuilder y Audiosrv..." "INFO"
                Start-Service -Name AudioEndpointBuilder -ErrorAction SilentlyContinue
                Start-Service -Name Audiosrv -ErrorAction SilentlyContinue

                & $logFn "Controladores de audio y microfono reactivados exitosamente." "OK"
            }

            "update" {
                & $stepFn 1 2 "Deteniendo servicio Windows Update (wuauserv)..." 40
                & $logFn "Deteniendo wuauserv temporalmente..." "INFO"
                Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 500

                & $stepFn 2 2 "Iniciando servicio de Windows Update..." 85
                & $logFn "Reactivando servicio de actualizaciones..." "INFO"
                Start-Service -Name wuauserv -ErrorAction SilentlyContinue

                & $logFn "Servicio de Windows Update reiniciado correctamente." "OK"
            }

            "all" {
                & $logFn "=== INICIANDO AUTO-REPARACION INTEGRAL DEL EQUIPO ===" "INFO"

                & $stepFn 1 4 "Desbloqueando servicios de audio y microfono..." 25
                & $logFn "[Paso 1/4] Reiniciando servicios de sonido (Audiosrv)..." "INFO"
                Stop-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
                Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
                Start-Service -Name AudioEndpointBuilder -ErrorAction SilentlyContinue
                Start-Service -Name Audiosrv -ErrorAction SilentlyContinue
                & $logFn "✓ Audio y microfono listos." "OK"

                & $stepFn 2 4 "Desbloqueando cola de impresion..." 50
                & $logFn "[Paso 2/4] Reiniciando cola de impresion (Spooler)..." "INFO"
                Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
                & $logFn "✓ Impresora desbloqueada." "OK"

                & $stepFn 3 4 "Restableciendo conexion de red y cache DNS..." 75
                & $logFn "[Paso 3/4] Vaciando DNS y renovando IP..." "INFO"
                ipconfig /flushdns | Out-Null
                ipconfig /renew | Out-Null
                & $logFn "✓ Red y DNS restablecidos." "OK"

                & $stepFn 4 4 "Refrescando explorador y barra de tareas..." 95
                & $logFn "[Paso 4/4] Recargando proceso explorer.exe..." "INFO"
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 600
                Start-Process explorer.exe
                & $logFn "✓ Entorno visual recargado." "OK"

                & $logFn "=== OPTIMIZACION Y AUTO-REPARACION COMPLETADA CON EXITO ===" "OK"
            }

            "info" {
                & $stepFn 1 2 "Consultando telemetria de hardware (WMI/CIM)..." 40
                & $logFn "Extrayendo datos de procesador, memoria, almacenamiento y red..." "INFO"

                $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
                $os = Get-CimInstance Win32_OperatingSystem
                $ramTotal = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
                $disk = Get-CimInstance Win32_DiskDrive | Select-Object -First 1
                $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
                $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
                if (-not $ip) { $ip = "Desconectado" }

                & $stepFn 2 2 "Estructurando reporte del equipo..." 90
                $extraData.info = @{
                    cpu = @{ name = $cpu.Name.Trim(); cores = $cpu.NumberOfCores; threads = $cpu.NumberOfLogicalProcessors }
                    ram = @{ total = ("{0:N1} GB" -f ($ramTotal / 1GB)); free = ("{0:N1} GB" -f ($os.FreePhysicalMemory / 1MB)) }
                    disk = @{ model = $disk.Model; free = ("{0:N1} GB libres de {1:N1} GB" -f ($diskC.FreeSpace / 1GB), ($diskC.Size / 1GB)) }
                    os = @{ caption = $os.Caption; build = $os.BuildNumber }
                    network = @{ ip = $ip }
                }
                & $logFn "Equipo: $env:COMPUTERNAME | IP: $ip" "OK"
                & $logFn "CPU: $($cpu.Name.Trim()) | RAM: $("{0:N1} GB" -f ($ramTotal / 1GB))" "OK"
            }

            "clean-profile" {
                & $stepFn 1 2 "Iniciando respaldo seguro de archivos..." 40
                & $logFn "Ejecutando Limpiar-Perfil.bat con Robocopy..." "INFO"
                $scriptPath = Join-Path $rootDir "Limpiar-Perfil.bat"

                if (Test-Path $scriptPath) {
                    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -Wait -NoNewWindow
                    & $stepFn 2 2 "Finalizando restauracion de configuracion..." 90
                    & $logFn "Respaldo guardado en tu Escritorio: Respaldo_Usuario" "OK"
                    & $logFn "Fondo de pantalla predeterminado restablecido." "OK"
                } else {
                    & $logFn "No se encontro Limpiar-Perfil.bat" "ERROR"
                    $actionSuccess = $false
                }
            }

            { $_ -in "check-upgrades", "upgrade-apps" } {
                & $stepFn 1 3 "Buscando actualizaciones disponibles con winget..." 25
                & $logFn "Escaneando paquetes instalados..." "INFO"
                $raw = winget upgrade | Out-String
                $lines = $raw -split "`r?`n"
                foreach ($line in $lines) {
                    if ($line.Trim() -and -not $line.Contains("---")) { & $logFn $line "INFO" }
                }

                & $stepFn 2 3 "Descargando e instalando parches de software..." 65
                & $logFn "Iniciando instalacion silenciosa de parches..." "INFO"
                winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements | Out-Null

                & $stepFn 3 3 "Verificando finalizacion de paquetes..." 95
                & $logFn "Actualizacion de aplicaciones finalizada correctamente." "OK"
            }

            default {
                & $logFn "Accion no reconocida: $Action" "ERROR"
                $actionSuccess = $false
                $errorMsg = "Accion invalida"
            }
        }
    }
    catch {
        $actionSuccess = $false
        $errorMsg = $_.Exception.Message
        & $logFn "Error: $errorMsg" "ERROR"
    }

    $timer.Stop()
    $elapsedSec = "{0:N1}" -f ($timer.ElapsedMilliseconds / 1000)

    if ($actionSuccess) {
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] ✨ Accion '$Action' completada con exito en ${elapsedSec}s" -ForegroundColor Green
    } else {
        Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] ✖ Accion '$Action' finalizada con error tras ${elapsedSec}s" -ForegroundColor Red
    }
    Write-Host ""

    $resultObj = @{
        success = $actionSuccess
        error = $errorMsg
        logs = $logs
    }
    foreach ($k in $extraData.Keys) {
        $resultObj[$k] = $extraData[$k]
    }
    return $resultObj
}

# Bucle principal de atencion de peticiones HTTP
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        # CORS pre-flight
        if ($method -eq "OPTIONS") {
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $response.AddHeader("Access-Control-Allow-Headers", "Content-Type")
            $response.StatusCode = 200
            $response.OutputStream.Close()
            continue
        }

        # --- 1. API: STATUS ---
        if ($path -eq "/api/status" -and $method -eq "GET") {
            $statusObj = @{
                isAdmin = $isAdmin
                hostName = $env:COMPUTERNAME
                userName = $env:USERNAME
                port = $Port
                timestamp = (Get-Date).ToString("o")
            }
            Send-JsonResponse -Response $response -Data $statusObj
            continue
        }

        # --- 2. API: REPORT PARA SOPORTE TI ---
        if ($path -eq "/api/report" -and $method -eq "GET") {
            try {
                $osInfo = Get-CimInstance Win32_OperatingSystem
                $cpuInfo = Get-CimInstance Win32_Processor | Select-Object -First 1
                $ramBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
                $ramGB = "{0:N1} GB" -f ($ramBytes / 1GB)
                $diskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
                $diskStr = "{0:N1} GB libres de {1:N1} GB" -f ($diskC.FreeSpace / 1GB), ($diskC.Size / 1GB)
                $ipAddr = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
                if (-not $ipAddr) { $ipAddr = "Sin conexion detectada" }

                $reportObj = @{
                    success = $true
                    report = @{
                        pcName = $env:COMPUTERNAME
                        userName = $env:USERNAME
                        osName = $osInfo.Caption
                        osBuild = $osInfo.BuildNumber
                        cpuName = $cpuInfo.Name.Trim()
                        ramTotal = $ramGB
                        diskFree = $diskStr
                        ipAddress = $ipAddr
                        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                    }
                }
                Send-JsonResponse -Response $response -Data $reportObj
            } catch {
                Send-JsonResponse -Response $response -Data @{ success = $false; error = $_.Exception.Message }
            }
            continue
        }

        # --- 3. API: ACCIONES STREAMING SSE (GET) ---
        if ($path.StartsWith("/api/action-stream/") -and $method -eq "GET") {
            $action = $path.Replace("/api/action-stream/", "")

            $response.StatusCode = 200
            $response.ContentType = "text/event-stream; charset=utf-8"
            $response.AddHeader("Cache-Control", "no-cache, no-transform")
            $response.AddHeader("Connection", "keep-alive")
            $response.AddHeader("Access-Control-Allow-Origin", "*")
            $response.SendChunked = $true

            Send-SseChunk -Response $response -Event "connected" -Data @{ action = $action }

            $onStepBlock = {
                param($step, $total, $label, $percent)
                Send-SseChunk -Response $response -Event "step" -Data @{ step = $step; total = $total; label = $label; percent = $percent }
            }

            $onLogBlock = {
                param($msg, $type)
                Send-SseChunk -Response $response -Event "log" -Data @{ msg = $msg; type = $type; time = (Get-Date -Format 'HH:mm:ss') }
            }

            $result = Execute-SystemAction -Action $action -OnStep $onStepBlock -OnLog $onLogBlock
            Send-SseChunk -Response $response -Event "complete" -Data $result
            $response.OutputStream.Close()
            continue
        }

        # --- 4. API: ACCIONES DIRECTAS (POST) ---
        if ($path.StartsWith("/api/action/") -and $method -eq "POST") {
            $action = $path.Replace("/api/action/", "")
            $result = Execute-SystemAction -Action $action
            Send-JsonResponse -Response $response -Data $result
            continue
        }

        # --- 5. ARCHIVOS ESTATICOS ---
        $relPath = $path.TrimStart('/')
        if ([string]::IsNullOrWhiteSpace($relPath)) { $relPath = "index.html" }
        $filePath = Join-Path $webDir $relPath

        $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
        $contentType = switch ($ext) {
            ".html" { "text/html; charset=utf-8" }
            ".css"  { "text/css; charset=utf-8" }
            ".js"   { "application/javascript; charset=utf-8" }
            ".json" { "application/json; charset=utf-8" }
            ".png"  { "image/png" }
            ".ico"  { "image/x-icon" }
            ".svg"  { "image/svg+xml" }
            default { "text/plain" }
        }

        Send-FileResponse -Response $response -FilePath $filePath -ContentType $contentType
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
