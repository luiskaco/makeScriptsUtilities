# Script de actualización masiva de aplicaciones
# El .exe compilado (ps2exe -requireAdmin) ya pide elevación vía manifiesto de Windows;
# no hace falta auto-relanzarse aquí. Si se corre como .ps1 directo sin ser admin,
# igual falla más claro al primer winget que requiera privilegios que con un relanzamiento.

$Host.UI.RawUI.WindowTitle = "Actualización de aplicaciones (winget)"
$width = 64

function Write-Banner {
    $line = "═" * ($width - 2)
    Write-Host ""
    Write-Host "╔$line╗" -ForegroundColor DarkCyan
    Write-Host ("║{0}║" -f "  ACTUALIZACIÓN MASIVA DE APLICACIONES".PadRight($width - 2)) -ForegroundColor Cyan
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

function Write-Summary {
    param([string]$Status, [string]$Color, [string]$Detail, [string]$ElapsedStr, [string]$LogPath)
    $line = "═" * ($width - 2)
    Write-Host ""
    Write-Host "╔$line╗" -ForegroundColor $Color
    Write-Host ("║{0}║" -f "  $Status".PadRight($width - 2)) -ForegroundColor $Color
    Write-Host ("║{0}║" -f "  $Detail".PadRight($width - 2)) -ForegroundColor White
    Write-Host ("║{0}║" -f "  Tiempo total: $ElapsedStr".PadRight($width - 2)) -ForegroundColor DarkGray
    Write-Host ("║{0}║" -f "  Log: $LogPath".PadRight($width - 2)) -ForegroundColor DarkGray
    Write-Host "╚$line╝" -ForegroundColor $Color
    Write-Host ""
}

function Get-PendingUpgrades {
    # Parsea la salida en tabla de "winget upgrade" en objetos Name/Id/Version/Available/Source
    $raw = winget upgrade --include-unknown | Out-String
    $lines = $raw -split "`r?`n"

    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\s+Version') {
            $headerIndex = $i
            break
        }
    }
    if ($headerIndex -eq -1) { return ,@() }

    $header = $lines[$headerIndex]
    $idStart = $header.IndexOf("Id")
    $versionStart = $header.IndexOf("Version")
    $availableStart = $header.IndexOf("Available")
    $sourceStart = $header.IndexOf("Source")

    $apps = @()
    for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        if ($line -match '^\d+ upgrades? available' -or $line -match 'upgrade available') { break }
        if ($line.Length -lt $idStart) { continue }

        $name = $line.Substring(0, $idStart).Trim()
        $id = if ($availableStart -gt $idStart) { $line.Substring($idStart, [Math]::Min($versionStart, $line.Length) - $idStart).Trim() } else { "" }
        $version = if ($line.Length -gt $versionStart) { $line.Substring($versionStart, [Math]::Min($availableStart, $line.Length) - $versionStart).Trim() } else { "" }
        $available = if ($line.Length -gt $availableStart) { $line.Substring($availableStart, [Math]::Min($sourceStart, $line.Length) - $availableStart).Trim() } else { "" }
        $source = if ($line.Length -gt $sourceStart) { $line.Substring($sourceStart).Trim() } else { "" }

        if ($name -and $id) {
            $apps += [PSCustomObject]@{
                Name      = $name
                Id        = $id
                Version   = $version
                Available = $available
                Source    = $source
            }
        }
    }
    # La coma fuerza a devolver siempre un array, incluso con 0 o 1 elementos.
    # Sin ella, PowerShell desenvuelve un array de un solo objeto al valor escalar:
    # $apps.Count queda en $null y "($index-1)/$total" revienta con "divide by zero".
    return ,$apps
}

function Invoke-WingetUpgrade {
    param([string]$Id, [string]$Source, [int]$TimeoutSeconds = 300)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "winget"
    $psi.Arguments = "upgrade --id `"$Id`" --source `"$Source`" --silent --include-unknown --disable-interactivity --accept-package-agreements --accept-source-agreements"
    $psi.UseShellExecute = $false
    # Sin redirigir stdout/stderr: redirigir sin drenar los streams llena el buffer
    # del pipe con la barra de progreso de winget y deja el proceso colgado escribiendo.
    # Heredar la consola evita ese deadlock y da un ExitCode fiable.

    $proc = [System.Diagnostics.Process]::Start($psi)
    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)

    if (-not $finished) {
        try { $proc.Kill() } catch {}
        return [PSCustomObject]@{ Code = -1; TimedOut = $true }
    }
    return [PSCustomObject]@{ Code = $proc.ExitCode; TimedOut = $false }
}

function Write-AppsTable {
    param([array]$Apps)
    $nameWidth = [Math]::Min(30, (($Apps | ForEach-Object { $_.Name.Length } | Measure-Object -Maximum).Maximum))
    if ($nameWidth -lt 15) { $nameWidth = 15 }
    Write-Host ("  {0}  {1,-12}  {2,-12}" -f "Aplicación".PadRight($nameWidth), "Actual", "Disponible") -ForegroundColor DarkCyan
    Write-Host ("  " + ("─" * ($nameWidth + 30))) -ForegroundColor DarkGray
    foreach ($app in $Apps) {
        $name = if ($app.Name.Length -gt $nameWidth) { $app.Name.Substring(0, $nameWidth - 1) + "…" } else { $app.Name.PadRight($nameWidth) }
        Write-Host ("  {0}  {1,-12}  {2,-12}" -f $name, $app.Version, $app.Available) -ForegroundColor Gray
    }
    Write-Host ""
}

Write-Banner

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "✖ winget no está instalado o no se encuentra en el PATH." -ForegroundColor Red
    Read-Host "Presiona Enter para salir"
    exit 1
}

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$logDir = Join-Path $scriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "update-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
Start-Transcript -Path $logFile | Out-Null

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$results = @()

try {
    Write-Section -Title "Actualizando repositorio de fuentes" -Icon "①"
    winget source update

    Write-Section -Title "Revisando aplicaciones con actualización pendiente" -Icon "②"
    $apps = Get-PendingUpgrades

    if ($apps.Count -eq 0) {
        Write-Host "  ✔ No hay aplicaciones pendientes de actualizar." -ForegroundColor Green
    } else {
        Write-Host "  Se encontraron $($apps.Count) aplicación(es) con actualización disponible:" -ForegroundColor White
        Write-Host ""
        Write-AppsTable -Apps $apps

        Write-Section -Title "Aplicando actualizaciones" -Icon "③"
        $total = $apps.Count
        $index = 0

        foreach ($app in $apps) {
            $index++
            $percent = [int](($index - 1) / $total * 100)
            Write-Progress -Activity "Actualizando aplicaciones" -Status "$index de $total : $($app.Name)" -PercentComplete $percent

            $appTimer = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Invoke-WingetUpgrade -Id $app.Id -Source $app.Source -TimeoutSeconds 300
            $appTimer.Stop()

            $ok = (-not $result.TimedOut -and $result.Code -eq 0)
            $results += [PSCustomObject]@{
                Name     = $app.Name
                Ok       = $ok
                Code     = $result.Code
                TimedOut = $result.TimedOut
                Elapsed  = "{0:mm\:ss}" -f $appTimer.Elapsed
            }

            if ($result.TimedOut) {
                Write-Host ("  ⏱ {0,-30} sin respuesta tras {1} — cancelado" -f $app.Name, $results[-1].Elapsed) -ForegroundColor Yellow
            } else {
                $icon = if ($ok) { "✔" } else { "✖" }
                $color = if ($ok) { "Green" } else { "Red" }
                Write-Host ("  {0} {1,-30} ({2})" -f $icon, $app.Name, $results[-1].Elapsed) -ForegroundColor $color
            }
        }
        Write-Progress -Activity "Actualizando aplicaciones" -Completed
    }

    $stopwatch.Stop()
    $elapsed = "{0:mm\:ss}" -f $stopwatch.Elapsed
    $failed = @($results | Where-Object { -not $_.Ok })

    if ($apps.Count -eq 0) {
        Write-Summary -Status "✔ PROCESO FINALIZADO CORRECTAMENTE" -Color Green -Detail "No había actualizaciones pendientes." -ElapsedStr $elapsed -LogPath $logFile
    } elseif ($failed.Count -eq 0) {
        Write-Summary -Status "✔ PROCESO FINALIZADO CORRECTAMENTE" -Color Green -Detail "$($results.Count) aplicación(es) actualizada(s) con éxito." -ElapsedStr $elapsed -LogPath $logFile
    } else {
        Write-Section -Title "Aplicaciones con errores" -Icon "⚠"
        foreach ($f in $failed) {
            $reason = if ($f.TimedOut) { "sin respuesta (posible prompt bloqueado)" } else { "código $($f.Code)" }
            Write-Host ("  ✖ {0,-30} {1}" -f $f.Name, $reason) -ForegroundColor Red
        }
        Write-Summary -Status "⚠ PROCESO FINALIZADO CON AVISOS" -Color Yellow -Detail "$($failed.Count) de $($results.Count) fallaron." -ElapsedStr $elapsed -LogPath $logFile
    }
} catch {
    $stopwatch.Stop()
    Write-Summary -Status "✖ ERROR DURANTE LA ACTUALIZACIÓN" -Color Red -Detail "$($_.Exception.Message)" -ElapsedStr ("{0:mm\:ss}" -f $stopwatch.Elapsed) -LogPath $logFile
} finally {
    Stop-Transcript | Out-Null
}

Read-Host "Presiona Enter para salir"
