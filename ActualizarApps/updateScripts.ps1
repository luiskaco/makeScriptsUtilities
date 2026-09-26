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

function Get-BrowserCandidateIds {
    # Algunos navegadores (sobre todo builds localizados, ej. Firefox en español)
    # quedan en "winget list" con Id placeholder "ARP\..." y Source vacío: winget
    # no logra correlacionar el paquete instalado contra su catálogo por nombre
    # exacto, así que el "winget upgrade" general nunca los ofrece (verificado:
    # Firefox (x64 es-ES) no aparece en la lista general, pero "winget upgrade
    # --id Mozilla.Firefox.es-ES" sí lo encuentra y lo actualiza). Acá se arma el
    # Id real del catálogo -vendor + código de idioma tomado del propio nombre
    # instalado- para forzar el chequeo puntual de esos casos.
    $vendorMap = [ordered]@{
        'Mozilla Firefox ESR' = 'Mozilla.Firefox.ESR'
        'Mozilla Firefox'     = 'Mozilla.Firefox'
        'Google Chrome'       = 'Google.Chrome'
        'Microsoft Edge'      = 'Microsoft.Edge'
        'Brave'               = 'BraveSoftware.BraveBrowser'
        'Opera GX'            = 'Opera.OperaGX'
        'Opera'               = 'Opera.Opera'
    }

    $raw = winget list | Out-String
    $candidates = @()
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -notmatch '(ARP|MSIX)\\') { continue }
        foreach ($vendor in $vendorMap.Keys) {
            # Exige que tras el nombre del vendor venga un dígito o un paréntesis
            # (versión o locale), para no confundir "Microsoft Edge" con
            # "Microsoft Edge WebView2 Runtime", que es otro paquete.
            if ($line -notmatch "^$([regex]::Escape($vendor))\s+[\d(]") { continue }
            $locale = $null
            if ($line -match '\(x64\s+([a-zA-Z-]+)\)') { $locale = $Matches[1] }
            $baseId = $vendorMap[$vendor]
            $id = if ($locale) { "$baseId.$locale" } else { $baseId }
            $candidates += [PSCustomObject]@{ Name = $vendor; Id = $id }
            break
        }
    }
    return ,($candidates | Sort-Object Id -Unique)
}

function Get-NvidiaDriverInstalledVersion {
    param([string]$NamePattern = "NVIDIA Graphics Driver*")
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $entry = Get-ItemProperty -Path $paths -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $NamePattern } |
        Select-Object -First 1
    if ($entry) { return $entry.DisplayVersion }
    return $null
}

function Get-NvidiaLatestDriverInfo {
    # Usa la API pública (no documentada oficialmente, pero es la misma que usa
    # la página de descargas de nvidia.com) para resolver psid/pfid/osID a partir
    # del nombre real de la GPU y del sistema operativo, sin hardcodear esos ids:
    # cambian por modelo y se rompería en cualquier GPU o Windows distinto.
    param([string]$GpuName)
    try {
        $series = Invoke-RestMethod -Uri "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=3" -TimeoutSec 15
        $family = $series.LookupValueSearch.LookupValues.LookupValue | Where-Object { $_.Name -eq $GpuName } | Select-Object -First 1
        if (-not $family) { return $null }

        $osList = Invoke-RestMethod -Uri "https://www.nvidia.com/Download/API/lookupValueSearch.aspx?TypeID=4" -TimeoutSec 15
        $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption
        $osName = if ($osCaption -match "Windows 11") { "Windows 11" } elseif ($osCaption -match "Windows 10") { "Windows 10 64-bit" } else { $null }
        if (-not $osName) { return $null }
        $osEntry = $osList.LookupValueSearch.LookupValues.LookupValue | Where-Object { $_.Name -eq $osName } | Select-Object -First 1
        if (-not $osEntry) { return $null }

        $uri = "https://gfwsl.geforce.com/services_toolkit/services/com/nvidia/services/AjaxDriverService.php" +
               "?func=DriverManualLookup&psid=$($family.ParentID)&pfid=$($family.Value)&osID=$($osEntry.Value)" +
               "&languageCode=1033&isWHQL=1&dch=1&sort1=0&numberOfResults=1"
        $result = Invoke-RestMethod -Uri $uri -TimeoutSec 15
        $info = $result.IDS[0].downloadInfo
        if (-not $info -or $info.Success -ne "1") { return $null }

        return [PSCustomObject]@{
            Version     = $info.Version
            ReleaseDate = $info.ReleaseDateTime
            DetailsUrl  = $info.DetailsURL
        }
    } catch {
        return $null
    }
}

function Get-WingetErrorMessage {
    # Códigos de winget que valen un mensaje claro en vez de un número.
    # -1978335090 confirmado en este equipo con Microsoft Edge: winget detecta la
    # actualización pero no puede aplicarla in-place porque la instalación actual
    # y la nueva usan tecnologías distintas (MSI vs EXE); "--force" NO lo resuelve
    # (probado), hace falta desinstalar y reinstalar a mano.
    param([int]$Code)
    switch ($Code) {
        -1978335090 { return "tecnología de instalación distinta a la actual — desinstalar y reinstalar a mano" }
        default { return "código $Code" }
    }
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
            } elseif ($ok) {
                Write-Host ("  ✔ {0,-30} ({1})" -f $app.Name, $results[-1].Elapsed) -ForegroundColor Green
            } else {
                Write-Host ("  ✖ {0,-30} {1}" -f $app.Name, (Get-WingetErrorMessage $result.Code)) -ForegroundColor Red
            }
        }
        Write-Progress -Activity "Actualizando aplicaciones" -Completed
    }

    Write-Section -Title "Navegadores no cubiertos por el listado general" -Icon "④"
    $listedIds = $apps | ForEach-Object { $_.Id }
    $browserCandidates = Get-BrowserCandidateIds | Where-Object { $listedIds -notcontains $_.Id }
    if ($browserCandidates.Count -eq 0) {
        Write-Host "  No hay navegadores adicionales que revisar por esta vía." -ForegroundColor Gray
    } else {
        foreach ($cand in $browserCandidates) {
            $appTimer = [System.Diagnostics.Stopwatch]::StartNew()
            $result = Invoke-WingetUpgrade -Id $cand.Id -Source "winget" -TimeoutSeconds 300
            $appTimer.Stop()
            $elapsedStr = "{0:mm\:ss}" -f $appTimer.Elapsed

            if ($result.Code -eq 20) {
                # El Id armado (vendor + locale) no aplica a este equipo: no es un error, es un intento descartado.
                continue
            } elseif ($result.Code -eq 43) {
                Write-Host ("  ✔ {0,-30} ya estaba en su última versión" -f $cand.Name) -ForegroundColor Green
            } elseif ($result.TimedOut) {
                $results += [PSCustomObject]@{ Name = $cand.Name; Ok = $false; Code = $result.Code; TimedOut = $true; Elapsed = $elapsedStr }
                Write-Host ("  ⏱ {0,-30} sin respuesta tras {1} — cancelado" -f $cand.Name, $elapsedStr) -ForegroundColor Yellow
            } else {
                $ok = ($result.Code -eq 0)
                $results += [PSCustomObject]@{ Name = $cand.Name; Ok = $ok; Code = $result.Code; TimedOut = $false; Elapsed = $elapsedStr }
                if ($ok) {
                    Write-Host ("  ✔ {0,-30} ({1})" -f $cand.Name, $elapsedStr) -ForegroundColor Green
                } else {
                    Write-Host ("  ✖ {0,-30} {1}" -f $cand.Name, (Get-WingetErrorMessage $result.Code)) -ForegroundColor Red
                }
            }
        }
    }

    Write-Section -Title "Verificando driver de NVIDIA" -Icon "⑤"
    $nvidiaGpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match "NVIDIA" } | Select-Object -First 1
    if (-not $nvidiaGpu) {
        Write-Host "  No se detectó GPU NVIDIA en este equipo." -ForegroundColor Gray
    } else {
        $installedVersion = Get-NvidiaDriverInstalledVersion
        $latest = Get-NvidiaLatestDriverInfo -GpuName $nvidiaGpu.Name
        if (-not $installedVersion) {
            Write-Host "  No se pudo leer la versión instalada del driver desde el registro." -ForegroundColor Yellow
        } elseif (-not $latest) {
            Write-Host "  ⚠ No se pudo consultar el sitio de NVIDIA (sin conexión o cambió su API)." -ForegroundColor Yellow
            Write-Host "    Versión instalada: $installedVersion — revisá manualmente en nvidia.com/drivers" -ForegroundColor Gray
        } else {
            $needsUpdate = $false
            try { $needsUpdate = ([version]$latest.Version -gt [version]$installedVersion) } catch { $needsUpdate = ($latest.Version -ne $installedVersion) }
            if ($needsUpdate) {
                Write-Host ("  ⚠ Hay driver nuevo: {0} → {1} (publicado {2})" -f $installedVersion, $latest.Version, $latest.ReleaseDate) -ForegroundColor Yellow
                Write-Host "    Descarga: $($latest.DetailsUrl)" -ForegroundColor Gray
                Write-Host "    No se instala automáticamente: un update de driver de video" -ForegroundColor Gray
                Write-Host "    puede cortar la pantalla o pedir reinicio." -ForegroundColor Gray
            } else {
                Write-Host ("  ✔ Driver NVIDIA al día ({0})" -f $installedVersion) -ForegroundColor Green
            }
        }
    }

    $stopwatch.Stop()
    $elapsed = "{0:mm\:ss}" -f $stopwatch.Elapsed
    $failed = @($results | Where-Object { -not $_.Ok })

    if ($results.Count -eq 0) {
        Write-Summary -Status "✔ PROCESO FINALIZADO CORRECTAMENTE" -Color Green -Detail "No había actualizaciones pendientes." -ElapsedStr $elapsed -LogPath $logFile
    } elseif ($failed.Count -eq 0) {
        Write-Summary -Status "✔ PROCESO FINALIZADO CORRECTAMENTE" -Color Green -Detail "$($results.Count) aplicación(es) actualizada(s) con éxito." -ElapsedStr $elapsed -LogPath $logFile
    } else {
        Write-Section -Title "Aplicaciones con errores" -Icon "⚠"
        foreach ($f in $failed) {
            $reason = if ($f.TimedOut) { "sin respuesta (posible prompt bloqueado)" } else { Get-WingetErrorMessage $f.Code }
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
