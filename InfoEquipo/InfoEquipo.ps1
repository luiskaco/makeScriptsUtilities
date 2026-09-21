# Script de información de hardware del equipo
# Recolecta CPU, GPU, RAM, Disco, Red, Monitor, Sistema Operativo,
# Placa base, Batería/Fuente de poder y Temperatura via WMI/CIM.
# La fuente de poder (wattage real) no es legible por software en la mayoría
# de los PC de escritorio: no existe un sensor estándar expuesto por WMI.
# La temperatura via MSAcpi_ThermalZoneTemperature depende del fabricante:
# muchos equipos (sobre todo laptops modernas) no la exponen por ahí. Leerla
# de forma confiable requeriría un driver de terceros (LibreHardwareMonitor,
# HWiNFO), que no se instala automáticamente desde este script.

$Host.UI.RawUI.WindowTitle = "Información del equipo"
$width = 64

function Write-Banner {
    $line = "═" * ($width - 2)
    Write-Host ""
    Write-Host "╔$line╗" -ForegroundColor DarkCyan
    Write-Host ("║{0}║" -f "  INFORMACIÓN DEL EQUIPO".PadRight($width - 2)) -ForegroundColor Cyan
    Write-Host ("║{0}║" -f "  $(Get-Date -Format 'dddd, dd MMMM yyyy - HH:mm')".PadRight($width - 2)) -ForegroundColor DarkGray
    Write-Host "╚$line╝" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Section {
    param([string]$Title, [string]$Icon = "▸")
    Write-Host ""
    Write-Host "$Icon $Title" -ForegroundColor Yellow
    Write-Host ("─" * $width) -ForegroundColor DarkGray
}

function Write-Field {
    param([string]$Label, [string]$Value)
    Write-Host ("  {0,-22} {1}" -f "$($Label):", $Value) -ForegroundColor Gray
}

function Format-Bytes {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N0} MB" -f ($Bytes / 1MB) }
    return "$Bytes B"
}

function Convert-WmiCharArray {
    param([byte[]]$Bytes)
    if (-not $Bytes) { return $null }
    $text = [System.Text.Encoding]::ASCII.GetString($Bytes) -replace "`0", ""
    return $text.Trim()
}

function Format-BitRate {
    param([double]$BitsPerSecond)
    if ($BitsPerSecond -ge 1e9) { return "{0:N1} Gbps" -f ($BitsPerSecond / 1e9) }
    if ($BitsPerSecond -ge 1e6) { return "{0:N0} Mbps" -f ($BitsPerSecond / 1e6) }
    if ($BitsPerSecond -ge 1e3) { return "{0:N0} Kbps" -f ($BitsPerSecond / 1e3) }
    return "$BitsPerSecond bps"
}

Write-Banner

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$logDir = Join-Path $scriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "infoequipo-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
Start-Transcript -Path $logFile | Out-Null

try {
    # --- CPU ---
    Write-Section -Title "Procesador (CPU)" -Icon "①"
    $cpus = Get-CimInstance Win32_Processor
    foreach ($cpu in $cpus) {
        Write-Field "Nombre" $cpu.Name.Trim()
        Write-Field "Fabricante" $cpu.Manufacturer
        Write-Field "Núcleos / Hilos" "$($cpu.NumberOfCores) núcleos / $($cpu.NumberOfLogicalProcessors) hilos"
        Write-Field "Velocidad base" "$($cpu.MaxClockSpeed) MHz"
        Write-Field "Socket" $cpu.SocketDesignation
    }

    # --- GPU ---
    Write-Section -Title "Tarjeta gráfica (GPU)" -Icon "②"
    $gpus = Get-CimInstance Win32_VideoController
    foreach ($gpu in $gpus) {
        Write-Field "Nombre" $gpu.Name
        if ($gpu.AdapterRAM -gt 0) {
            Write-Field "Memoria dedicada" (Format-Bytes $gpu.AdapterRAM)
        }
        Write-Field "Resolución actual" "$($gpu.CurrentHorizontalResolution) x $($gpu.CurrentVerticalResolution)"
        Write-Field "Versión de driver" $gpu.DriverVersion
        Write-Host ""
    }

    # --- RAM ---
    Write-Section -Title "Memoria RAM" -Icon "③"
    $memModules = Get-CimInstance Win32_PhysicalMemory
    $totalRam = 0
    $i = 0
    foreach ($mem in $memModules) {
        $i++
        $totalRam += $mem.Capacity
        $manufacturer = if ($mem.Manufacturer) { $mem.Manufacturer.Trim() } else { "Desconocido" }
        $partNumber = if ($mem.PartNumber) { $mem.PartNumber.Trim() } else { "N/D" }
        Write-Field "Módulo $i" "$(Format-Bytes $mem.Capacity) - $($mem.Speed) MHz - $manufacturer ($partNumber)"
    }
    Write-Host ""
    Write-Field "Total instalado" (Format-Bytes $totalRam)

    # --- Disco ---
    Write-Section -Title "Almacenamiento (Disco)" -Icon "④"
    $disks = Get-CimInstance Win32_DiskDrive
    foreach ($disk in $disks) {
        $mediaType = if ($disk.MediaType) { $disk.MediaType } else { "Desconocido" }
        Write-Field "Modelo" $disk.Model
        Write-Field "Interfaz / Tipo" "$($disk.InterfaceType) - $mediaType"
        Write-Field "Capacidad" (Format-Bytes $disk.Size)
        Write-Host ""
    }
    $volumes = Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3"
    foreach ($vol in $volumes) {
        $freePct = if ($vol.Size -gt 0) { [Math]::Round(($vol.FreeSpace / $vol.Size) * 100) } else { 0 }
        Write-Field "Unidad $($vol.DeviceID)" "$(Format-Bytes $vol.FreeSpace) libres de $(Format-Bytes $vol.Size) ($freePct% libre)"
    }

    # --- Red ---
    Write-Section -Title "Red" -Icon "⑤"
    $adapters = Get-CimInstance Win32_NetworkAdapter -Filter "NetEnabled=True"
    if (-not $adapters) {
        Write-Host "  Sin adaptadores de red activos." -ForegroundColor Gray
    }
    foreach ($adapter in $adapters) {
        $config = Get-CimInstance Win32_NetworkAdapterConfiguration -Filter "Index=$($adapter.Index)"
        $ip = if ($config.IPAddress) { ($config.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' }) -join ", " } else { "Sin IP" }
        Write-Field "Adaptador" $adapter.Name
        Write-Field "IP" $ip
        Write-Field "Velocidad enlace" $(if ($adapter.Speed) { Format-BitRate $adapter.Speed } else { "N/D" })
        Write-Host ""
    }

    # --- Monitor ---
    Write-Section -Title "Monitor(es)" -Icon "⑥"
    $monitors = Get-CimInstance -Namespace "root\wmi" -ClassName WmiMonitorID -ErrorAction SilentlyContinue
    if ($monitors) {
        foreach ($mon in $monitors) {
            $manuf = Convert-WmiCharArray $mon.ManufacturerName
            $model = Convert-WmiCharArray $mon.UserFriendlyName
            $serial = Convert-WmiCharArray $mon.SerialNumberID
            Write-Field "Fabricante" $manuf
            Write-Field "Modelo" $(if ($model) { $model } else { "N/D" })
            Write-Field "Serie" $(if ($serial) { $serial } else { "N/D" })
            Write-Host ""
        }
    } else {
        Write-Host "  No se pudo leer info EDID del monitor (común en laptops o con ciertos drivers)." -ForegroundColor Gray
    }

    # --- Sistema Operativo ---
    Write-Section -Title "Sistema Operativo" -Icon "⑦"
    $os = Get-CimInstance Win32_OperatingSystem
    Write-Field "Nombre" $os.Caption
    Write-Field "Versión / Build" "$($os.Version) (Build $($os.BuildNumber))"
    Write-Field "Arquitectura" $os.OSArchitecture
    Write-Field "Fecha instalación" $os.InstallDate
    Write-Field "Último arranque" $os.LastBootUpTime

    # --- Placa base ---
    Write-Section -Title "Placa base (Motherboard)" -Icon "⑧"
    $board = Get-CimInstance Win32_BaseBoard
    $bios = Get-CimInstance Win32_BIOS
    Write-Field "Fabricante" $board.Manufacturer
    Write-Field "Modelo" $board.Product
    Write-Field "Número de serie" $board.SerialNumber
    Write-Field "Versión BIOS" $bios.SMBIOSBIOSVersion
    Write-Field "Fecha BIOS" ($bios.ReleaseDate)

    # --- Fuente de poder / Batería ---
    Write-Section -Title "Fuente de poder (PSU) / Batería" -Icon "⑨"
    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    if ($battery) {
        foreach ($b in $battery) {
            Write-Field "Batería detectada" $b.Name
            Write-Field "Estado" $b.Status
            Write-Field "Carga estimada" "$($b.EstimatedChargeRemaining)%"
        }
        $staticData = Get-CimInstance -Namespace "root\wmi" -ClassName BatteryStaticData -ErrorAction SilentlyContinue
        $fullCharge = Get-CimInstance -Namespace "root\wmi" -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue
        if ($staticData -and $fullCharge) {
            foreach ($s in $staticData) {
                $fc = ($fullCharge | Where-Object { $_.InstanceName -eq $s.InstanceName } | Select-Object -First 1).FullChargedCapacity
                if ($s.DesignedCapacity -and $fc) {
                    $health = [Math]::Round(($fc / $s.DesignedCapacity) * 100)
                    Write-Field "Capacidad diseño" "$($s.DesignedCapacity) mWh"
                    Write-Field "Capacidad actual máx." "$fc mWh"
                    Write-Field "Salud de batería" "$health%"
                }
            }
        }
        Write-Host ""
        Write-Host "  ℹ Este equipo tiene batería (portátil): no aplica fuente de poder ATX." -ForegroundColor DarkGray
    } else {
        Write-Host "  ⚠ Windows no expone el wattage real de la fuente por WMI." -ForegroundColor Yellow
        Write-Host "    Para saber el modelo y los watts, hay dos opciones:" -ForegroundColor Gray
        Write-Host "      - Leer la etiqueta física de la fuente (dentro del gabinete)." -ForegroundColor Gray
        Write-Host "      - Usar un monitor de hardware como HWiNFO o AIDA64," -ForegroundColor Gray
        Write-Host "        que sí leen el modelo si la fuente es certificada" -ForegroundColor Gray
        Write-Host "        y expone datos por PMBus/SMBus." -ForegroundColor Gray
    }

    # --- Temperatura ---
    Write-Section -Title "Temperatura" -Icon "⑩"
    $thermal = Get-CimInstance -Namespace "root/wmi" -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction SilentlyContinue
    if ($thermal) {
        $t = 0
        foreach ($zone in $thermal) {
            $t++
            $celsius = [Math]::Round((($zone.CurrentTemperature - 2732) / 10.0), 1)
            Write-Field "Zona térmica $t" "$celsius °C"
        }
    } else {
        Write-Host "  No disponible: este equipo no expone temperatura por ACPI/WMI estándar." -ForegroundColor Gray
        Write-Host "  Para verla en tiempo real, usá HWiNFO o LibreHardwareMonitor" -ForegroundColor Gray
        Write-Host "  (no se instalan automáticamente desde este script)." -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host ("═" * $width) -ForegroundColor DarkCyan
    Write-Host "  ✔ Reporte generado. Log guardado en:" -ForegroundColor Green
    Write-Host "  $logFile" -ForegroundColor DarkGray
    Write-Host ("═" * $width) -ForegroundColor DarkCyan
    Write-Host ""
} catch {
    Write-Host ""
    Write-Host "✖ Error al recolectar información: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-Transcript | Out-Null
}

Read-Host "Presiona Enter para salir"
