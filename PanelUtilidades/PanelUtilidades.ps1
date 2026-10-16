<#
.SYNOPSIS
    Panel de utilidades de Windows (Orange Latam) — versión nativa WPF.
.DESCRIPTION
    Reemplaza al antiguo panel web (web/server.js + navegador). Reinicia servicios
    de Windows, muestra el hardware del equipo, busca actualizaciones con winget y
    respalda/limpia el perfil del usuario.

    Cada tarea corre en un runspace aparte para que la ventana no se congele. El
    runspace habla con la interfaz solo a través de $sync.Queue: un DispatcherTimer
    la vacía cada 100 ms en el hilo de la UI.

    Se distribuye compilado como PanelUtilidades.exe (ver CLAUDE.md). Compilado con
    -noConsole, todo lo que llegue al pipeline del script se muestra como un
    MessageBox: por eso los métodos que devuelven valor van con [void].
#>

# --- Elevación ---------------------------------------------------------------

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $PSCommandPath) {
    # Corriendo el .ps1 a mano sin elevación: relanzar como administrador. El .exe
    # ya pide UAC por su manifiesto (-requireAdmin) y no entra acá.
    try {
        Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$PSCommandPath`"")
    } catch {}
    exit
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class PanelNative {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
}
'@

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName) }
$rootDir = Split-Path -Parent $scriptDir

$sync = [hashtable]::Synchronized(@{ Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]' })

# --- Funciones de trabajo (corren dentro del runspace) -------------------------

function Write-Log {
    param([string]$Message, [ValidateSet('INFO', 'OK', 'WARN', 'ERROR', 'STEP')][string]$Type = 'INFO')
    $sync.Queue.Enqueue([pscustomobject]@{ Kind = 'LOG'; Time = (Get-Date); Message = $Message; Type = $Type })
}

function Send-Data {
    param([string]$Key, $Value)
    $sync.Queue.Enqueue([pscustomobject]@{ Kind = 'DATA'; Key = $Key; Value = $Value })
}

function Invoke-Native {
    # Corre un ejecutable sin ventana y devuelve su salida. Compilado con -noConsole,
    # llamar "& winget" o "ipconfig" directo abriría una consola por cada comando.
    # stdout y stderr se leen en paralelo: leer uno y después el otro se cuelga en
    # cuanto el segundo llena el buffer del pipe.
    param([string]$File, [string]$Arguments, [int]$TimeoutSeconds = 120, [switch]$Utf8)
    $psi = New-Object System.Diagnostics.ProcessStartInfo $File, $Arguments
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $encoding = if ($Utf8) { [Text.Encoding]::UTF8 } else { [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) }
    $psi.StandardOutputEncoding = $encoding
    $psi.StandardErrorEncoding = $encoding

    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Close()
    $stdout = $proc.StandardOutput.ReadToEndAsync()
    $stderr = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
        # /T mata también a los hijos: winget lanza el instalador como proceso aparte y
        # Kill() solo cerraría a winget, dejando el instalador corriendo.
        $null = Invoke-Native -File 'taskkill.exe' -Arguments "/PID $($proc.Id) /T /F" -TimeoutSeconds 15
        return [pscustomobject]@{ Code = -1; TimedOut = $true; Output = ''; Error = '' }
    }
    $proc.WaitForExit()
    [pscustomobject]@{ Code = $proc.ExitCode; TimedOut = $false; Output = $stdout.Result; Error = $stderr.Result }
}

function Get-Column {
    param([string]$Line, [int[]]$Starts, [int]$Index)
    if ($Index -ge $Starts.Count -or $Starts[$Index] -ge $Line.Length) { return '' }
    $end = if ($Index + 1 -lt $Starts.Count) { [Math]::Min($Starts[$Index + 1], $Line.Length) } else { $Line.Length }
    $Line.Substring($Starts[$Index], $end - $Starts[$Index]).Trim()
}

function ConvertFrom-WingetTable {
    # Las columnas se ubican por la posición de cada palabra del encabezado (la línea
    # anterior a la de guiones), así sirve con winget en inglés ("Name Id Version
    # Available Source") o en español ("Nombre Id Versión Disponible Origen").
    # Se parte por [\r\n]+ porque el spinner de winget escribe "\r - \r \ " antes
    # de la tabla y quedaría pegado al encabezado.
    param([string]$Text)
    $lines = @($Text -split '[\r\n]+')
    $sep = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^-{10,}\s*$') { $sep = $i; break }
    }
    if ($sep -lt 1) { return , @() }
    $starts = [int[]]@([regex]::Matches($lines[$sep - 1], '\S+') | ForEach-Object { $_.Index })
    if ($starts.Count -lt 4) { return , @() }

    $apps = New-Object System.Collections.Generic.List[object]
    for ($i = $sep + 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\d+ ' -or $line.Length -le $starts[1]) { break }
        $id = Get-Column $line $starts 1
        if (-not $id -or $id -match '\s') { break }
        $apps.Add([pscustomobject]@{
                Name      = Get-Column $line $starts 0
                Id        = $id
                Version   = Get-Column $line $starts 2
                Available = Get-Column $line $starts 3
                Source    = Get-Column $line $starts 4
            })
    }
    return , $apps.ToArray()
}

function Find-PendingUpgrades {
    Write-Log 'Consultando winget (puede tardar hasta un minuto)...'
    $r = Invoke-Native -File 'winget.exe' -Arguments 'upgrade --include-unknown --accept-source-agreements --disable-interactivity' -Utf8 -TimeoutSeconds 180
    if ($r.TimedOut) { throw 'winget no respondió en 3 minutos.' }
    $apps = ConvertFrom-WingetTable $r.Output
    Send-Data 'upgrades' $apps
    if ($apps.Count -gt 0) {
        Write-Log "$($apps.Count) aplicación(es) con actualización disponible." 'OK'
    } else {
        $last = @($r.Output -split '[\r\n]+' | Where-Object { $_ -match '\w{3,}' }) | Select-Object -Last 1
        if ($last) { Write-Log "winget: $($last.Trim())" }
        Write-Log 'No hay aplicaciones con actualización pendiente.' 'OK'
    }
}

function Get-WingetErrorMessage {
    # Mismos códigos que traduce ActualizarApps (ver su comentario para el origen de cada uno).
    param([int]$Code)
    switch ($Code) {
        -1978335090 { 'tecnología de instalación distinta a la actual: desinstalar y reinstalar a mano' }
        default { "código $Code" }
    }
}

function Install-SelectedUpgrades {
    # Instala de a una las apps marcadas, con límite de tiempo por app. Cada cambio de
    # estado va a la tabla por Send-Data; un fallo no corta a las demás.
    param([object[]]$Apps, [int]$TimeoutSeconds = 300)

    if (@(Get-Process -Name winget -ErrorAction SilentlyContinue).Count -gt 0) {
        foreach ($app in $Apps) { Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = 'Pendiente' } }
        throw 'Ya hay otro winget corriendo; dos instalaciones a la vez se pisan. Espera a que termine y vuelve a intentar.'
    }

    $done = 0; $skipped = 0; $failed = 0; $index = 0
    foreach ($app in $Apps) {
        $index++
        Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = 'Instalando…' }
        Write-Log "[$index/$($Apps.Count)] $($app.Name)" 'STEP'

        $wingetArgs = "upgrade --id `"$($app.Id)`" --silent --include-unknown --disable-interactivity --accept-package-agreements --accept-source-agreements"
        if ($app.Source) { $wingetArgs += " --source `"$($app.Source)`"" }
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Native -File 'winget.exe' -Arguments $wingetArgs -Utf8 -TimeoutSeconds $TimeoutSeconds
        $took = '{0:mm\:ss}' -f $clock.Elapsed

        if ($r.TimedOut) {
            $failed++
            Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = 'Sin respuesta' }
            Write-Log "$($app.Name): sin respuesta tras $took, cancelado." 'WARN'
        } elseif ($r.Code -eq 0) {
            $done++
            Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = "Actualizada ($took)" }
            Write-Log "$($app.Name): actualizada en $took." 'OK'
        } elseif ($r.Code -eq -1978335189) {
            # 0x8A15002B: no hay actualización aplicable (p. ej. ya la instaló otro proceso).
            $skipped++
            Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = 'Sin cambios' }
            Write-Log "$($app.Name): sin actualización aplicable (posiblemente ya actualizada)." 'WARN'
        } else {
            $failed++
            $why = Get-WingetErrorMessage $r.Code
            Send-Data 'upgradeStatus' @{ Id = $app.Id; Status = 'Falló' }
            Write-Log "$($app.Name): falló ($why)." 'ERROR'
        }
    }

    $summaryType = if ($failed -gt 0) { 'WARN' } else { 'OK' }
    Write-Log "Resultado: $done actualizada(s), $skipped sin cambios, $failed con error. Usa «Buscar actualizaciones» para refrescar la lista." $summaryType
}

function Find-WindowsUpdates {
    Write-Log 'Buscando actualizaciones de Windows (puede tardar varios minutos)...'
    $session = New-Object -ComObject Microsoft.Update.Session
    $found = $session.CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($u in $found.Updates) {
        $kb = @($u.KBArticleIDs | ForEach-Object { "KB$_" }) -join ', '
        $needsUser = [bool]$u.InstallationBehavior.CanRequestUserInput -or -not $u.EulaAccepted
        $list.Add([pscustomobject]@{
                Id        = $u.Identity.UpdateID
                Title     = $u.Title
                Kb        = $kb
                Type      = if ($u.Type -eq 2) { 'Controlador' } else { 'Software' }
                NeedsUser = $needsUser
            })
    }
    Send-Data 'winUpdates' $list.ToArray()
    if ((New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired) { Send-Data 'winReboot' $true }
    if ($list.Count -gt 0) {
        Write-Log "$($list.Count) actualización(es) de Windows disponible(s)." 'OK'
    } else {
        Write-Log 'Windows está al día.' 'OK'
    }
}

function Install-WindowsUpdates {
    # Descarga e instala de a una para informar el estado de cada fila; una que falla no
    # corta a las demás. Se vuelve a buscar porque los objetos COM de la búsqueda anterior
    # no viajan a este runspace. No se fuerza ningún reinicio: solo se avisa.
    param([string[]]$Ids)

    $session = New-Object -ComObject Microsoft.Update.Session
    $found = $session.CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    $byId = @{}
    foreach ($u in $found.Updates) { $byId[$u.Identity.UpdateID] = $u }

    $done = 0; $skipped = 0; $failed = 0; $reboot = $false; $index = 0
    foreach ($id in $Ids) {
        $index++
        $u = $byId[$id]
        if (-not $u) {
            $skipped++
            Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Ya no aplica' }
            Write-Log "[$index/$($Ids.Count)] Una actualización ya no aparece como pendiente; se omite." 'WARN'
            continue
        }
        Write-Log "[$index/$($Ids.Count)] $($u.Title)" 'STEP'
        if ($u.InstallationBehavior.CanRequestUserInput -or -not $u.EulaAccepted) {
            $skipped++
            Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Requiere interacción' }
            Write-Log 'Pide aceptar una licencia o responder en pantalla; instálala desde Configuración de Windows.' 'WARN'
            continue
        }
        try {
            $coll = New-Object -ComObject Microsoft.Update.UpdateColl
            [void]$coll.Add($u)
            if (-not $u.IsDownloaded) {
                Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Descargando…' }
                $downloader = $session.CreateUpdateDownloader()
                $downloader.Updates = $coll
                $dl = $downloader.Download()
                if ($dl.ResultCode -ne 2) { throw "la descarga terminó con código $($dl.ResultCode)" }
            }
            Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Instalando…' }
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $coll
            $installer.AllowSourcePrompts = $false
            $r = $installer.Install()
            if ($r.RebootRequired) { $reboot = $true }
            switch ([int]$r.ResultCode) {
                2 {
                    $done++
                    $note = if ($r.RebootRequired) { 'Instalada (reiniciar)' } else { 'Instalada' }
                    Send-Data 'winUpdateStatus' @{ Id = $id; Status = $note }
                    Write-Log "$($u.Title): instalada." 'OK'
                }
                3 {
                    $done++
                    Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Instalada con avisos' }
                    Write-Log "$($u.Title): instalada con avisos." 'WARN'
                }
                default { throw ('resultado {0}, HRESULT 0x{1:X8}' -f [int]$r.ResultCode, $r.GetUpdateResult(0).HResult) }
            }
        } catch {
            $failed++
            $why = $_.Exception.Message
            # 0x80070005: el instalador de Windows Update exige permisos de administrador.
            if ($_.Exception.HResult -eq -2147024891) { $why = 'acceso denegado: abre el panel como administrador' }
            Send-Data 'winUpdateStatus' @{ Id = $id; Status = 'Falló' }
            Write-Log "$($u.Title): falló ($why)." 'ERROR'
        }
    }

    $type = if ($failed -gt 0) { 'WARN' } else { 'OK' }
    Write-Log "Resultado: $done instalada(s), $skipped omitida(s), $failed con error." $type
    if ($reboot) {
        Send-Data 'winReboot' $true
        Write-Log 'Hay que reiniciar el equipo para terminar de aplicar las actualizaciones.' 'WARN'
    }
}

function Test-PrinterSocket {
    param([string]$HostName, [int]$Port = 9100, [int]$TimeoutMs = 2000)
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $tcp.BeginConnect($HostName, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            return $true
        }
        return $false
    } catch {
        return $false
    } finally {
        $tcp.Close()
    }
}

function Send-PrinterResult {
    param([string]$Text, [ValidateSet('OK', 'WARN', 'ERROR')][string]$Kind)
    Send-Data 'printerResult' @{ Text = $Text; Kind = $Kind }
}

function Get-PrinterDriverNames {
    $names = @(Get-PrinterDriver -ErrorAction Stop | Select-Object -ExpandProperty Name | Sort-Object -Unique)
    Send-Data 'printerDrivers' $names
    if ($names.Count -gt 0) {
        Write-Log "$($names.Count) controlador(es) de impresora instalado(s) en Windows." 'OK'
    } else {
        Write-Log 'Windows no tiene controladores de impresora instalados; instala primero el del fabricante.' 'WARN'
    }
}

function Test-PrinterConnection {
    param([string]$HostName)
    Write-Log "Probando ${HostName}:9100..."
    if (Test-PrinterSocket -HostName $HostName -TimeoutMs 3000) {
        Write-Log "${HostName}:9100 responde." 'OK'
        Send-PrinterResult "✔ La impresora responde en ${HostName}:9100." 'OK'
    } else {
        Write-Log "${HostName}:9100 no responde." 'WARN'
        Send-PrinterResult "✖ Sin respuesta en ${HostName}:9100. Revisa que esté encendida, en la misma red y con la IP correcta." 'WARN'
    }
}

function Install-NetworkPrinter {
    param([string]$Name, [string]$HostName, [string]$Driver, [bool]$SetDefault, [bool]$TestPage)
    try {
        $port = 9100
        Write-Log "Comprobando ${HostName}:$port..."
        if (Test-PrinterSocket -HostName $HostName -Port $port) {
            Write-Log "${HostName}:$port responde." 'OK'
        } else {
            Write-Log "${HostName}:$port no responde (¿apagada?). Se configura igual en Windows." 'WARN'
        }

        $portName = "IP_$HostName"
        if (Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue) {
            Write-Log "El puerto $portName ya existe; se reutiliza."
        } else {
            Add-PrinterPort -Name $portName -PrinterHostAddress $HostName -PortNumber $port -ErrorAction Stop
            Write-Log "Puerto TCP/IP $portName creado (RAW, $port)." 'OK'
        }

        if (Get-Printer -Name $Name -ErrorAction SilentlyContinue) {
            Write-Log "La impresora «$Name» ya existía: se actualizan su puerto y su controlador." 'WARN'
            Set-Printer -Name $Name -PortName $portName -DriverName $Driver -ErrorAction Stop
        } else {
            Add-Printer -Name $Name -PortName $portName -DriverName $Driver -ErrorAction Stop
        }
        Write-Log "Impresora «$Name» registrada con el controlador «$Driver»." 'OK'

        if ($SetDefault) {
            try {
                (New-Object -ComObject WScript.Network).SetDefaultPrinter($Name)
                Write-Log "«$Name» es ahora la impresora predeterminada." 'OK'
            } catch {
                Write-Log "No se pudo dejar como predeterminada: $($_.Exception.Message)" 'WARN'
            }
        }
        if ($TestPage) {
            try {
                Send-PrinterTestPage -Name $Name
            } catch {
                Write-Log "No se pudo enviar la página de prueba: $($_.Exception.Message)" 'WARN'
            }
        }
        try { Get-InstalledPrinters } catch { Write-Log "No se pudo actualizar la lista de impresoras: $($_.Exception.Message)" 'WARN' }
        Send-PrinterResult "✔ «$Name» quedó instalada en ${HostName}:$port." 'OK'
    } catch {
        Send-PrinterResult "✖ No se pudo instalar: $($_.Exception.Message)" 'ERROR'
        throw
    }
}

function Send-PrinterTestPage {
    param([string]$Name)
    # WQL escapa la comilla simple y la barra invertida con una barra invertida.
    $wql = $Name.Replace('\', '\\').Replace("'", "\'")
    $cim = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$wql'" -ErrorAction Stop
    if (-not $cim) { throw "No se encontró la impresora «$Name»." }
    $null = Invoke-CimMethod -InputObject $cim -MethodName PrintTestPage -ErrorAction Stop
    Write-Log "Página de prueba enviada a «$Name»." 'OK'
}

function Get-InstalledPrinters {
    # Win32_Printer, no Get-Printer: solo WMI informa WorkOffline (impresora USB apagada o desconectada).
    $list = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop | Sort-Object Name | ForEach-Object {
            [pscustomobject]@{
                Name      = $_.Name
                Driver    = $_.DriverName
                Port      = $_.PortName
                Status    = if ($_.WorkOffline) { 'Sin conexión' } else { 'Lista' }
                IsDefault = if ($_.Default) { '✔' } else { '' }
            }
        })
    Send-Data 'printerList' $list
}

function Update-PrinterData {
    Get-PrinterDriverNames
    Get-InstalledPrinters
}

function Set-DefaultPrinterByName {
    param([string]$Name)
    (New-Object -ComObject WScript.Network).SetDefaultPrinter($Name)
    Write-Log "«$Name» es ahora la impresora predeterminada." 'OK'
    Get-InstalledPrinters
}

function Remove-PrinterByName {
    param([string]$Name)
    Remove-Printer -Name $Name -ErrorAction Stop
    Write-Log "Impresora «$Name» quitada. Su puerto TCP/IP se conserva." 'OK'
    Get-InstalledPrinters
}

function Clear-PrintQueueDeep {
    $spool = Join-Path $env:SystemRoot 'System32\spool\PRINTERS'
    Write-Log 'Deteniendo la cola de impresión (Spooler)...'
    Stop-Service -Name 'Spooler' -Force -ErrorAction Stop
    try {
        $removed = 0
        foreach ($f in @(Get-ChildItem -LiteralPath $spool -File -Force -ErrorAction SilentlyContinue)) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $removed++
            } catch {
                Write-Log "No se pudo borrar $($f.Name): $($_.Exception.Message)" 'WARN'
            }
        }
        Write-Log "$removed archivo(s) atascado(s) eliminado(s) de la cola." 'OK'
    } finally {
        # Se reinicia siempre: dejar el Spooler detenido rompe la impresión de todo el equipo.
        Start-Service -Name 'Spooler' -ErrorAction Stop
        Write-Log 'Spooler iniciado.' 'OK'
    }
}

function Test-HostPing {
    # Devuelve los ms de ida y vuelta, o -1 si no responde. Ping de .NET: sin ventana de consola.
    param([string]$Target, [int]$TimeoutMs = 2000)
    $ping = New-Object System.Net.NetworkInformation.Ping
    try {
        $reply = $ping.Send($Target, $TimeoutMs)
        if ($reply.Status -eq 'Success') { return [int]$reply.RoundtripTime }
        return -1
    } catch {
        return -1
    } finally {
        $ping.Dispose()
    }
}

function Resolve-HostName {
    param([string]$Name = 'google.com')
    try {
        $task = [System.Net.Dns]::GetHostAddressesAsync($Name)
        if ($task.Wait(4000)) { return (@($task.Result) | Select-Object -First 1).IPAddressToString }
    } catch {}
    return $null
}

function Get-NetworkDiagnosis {
    Write-Log 'Diagnosticando la red...'
    $rows = New-Object System.Collections.Generic.List[object]
    $add = { param($Test, $Result, $State) $rows.Add([pscustomobject]@{ Test = $Test; Result = $Result; State = $State }) }
    $ok = '✔ OK'; $bad = '✖ Falla'

    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')
    $gateway = $null; $dnsServer = $null
    foreach ($a in $adapters) {
        $cfg = Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue
        $ips = @($cfg.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
        $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
        $dns = @(Get-DnsClientServerAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses })
        & $add 'Adaptador' "$($a.Name) ($($a.InterfaceDescription))" ''
        & $add '   IP' $(if ($ips) { $ips } else { '—' }) ''
        & $add '   Puerta de enlace' $(if ($gw) { $gw } else { '—' }) ''
        & $add '   DNS' $(if ($dns.Count) { $dns -join ', ' } else { '—' }) ''
        & $add '   MAC' $a.MacAddress ''
        if (-not $gateway -and $gw) { $gateway = $gw }
        if (-not $dnsServer -and $dns.Count) { $dnsServer = $dns[0] }
    }
    if ($adapters.Count -eq 0) { & $add 'Adaptadores de red' 'Ninguno conectado' $bad }

    $gwOk = $null; $netOk = $null; $nameOk = $null
    if ($gateway) {
        $ms = Test-HostPing $gateway
        $gwOk = $ms -ge 0
        & $add 'Ping al router' $(if ($gwOk) { "$gateway · $ms ms" } else { "$gateway · sin respuesta" }) $(if ($gwOk) { $ok } else { $bad })
    }
    if ($dnsServer) {
        $ms = Test-HostPing $dnsServer
        & $add 'Ping al servidor DNS' $(if ($ms -ge 0) { "$dnsServer · $ms ms" } else { "$dnsServer · sin respuesta" }) $(if ($ms -ge 0) { $ok } else { $bad })
    }
    $ms = Test-HostPing '1.1.1.1'
    $netOk = $ms -ge 0
    & $add 'Ping a internet (1.1.1.1)' $(if ($netOk) { "$ms ms" } else { 'sin respuesta' }) $(if ($netOk) { $ok } else { $bad })
    $resolved = Resolve-HostName 'google.com'
    $nameOk = [bool]$resolved
    & $add 'Resolución de nombres (google.com)' $(if ($nameOk) { $resolved } else { 'no se pudo resolver' }) $(if ($nameOk) { $ok } else { $bad })

    if ($adapters.Count -eq 0) {
        $summary = 'No hay adaptadores de red conectados: revisa el cable, el Wi-Fi o el modo avión.'; $kind = 'ERROR'
    } elseif ($gateway -and -not $gwOk) {
        $summary = 'El equipo no llega al router: revisa el cable o el Wi-Fi, o reinicia el router.'; $kind = 'ERROR'
    } elseif (-not $netOk) {
        $summary = 'El router responde pero no hay salida a internet: el problema está en el router o en el proveedor.'; $kind = 'WARN'
    } elseif (-not $nameOk) {
        $summary = 'Hay internet pero no se resuelven nombres: el DNS falla. Prueba cambiarlo más abajo.'; $kind = 'WARN'
    } else {
        $summary = 'La red funciona correctamente.'; $kind = 'OK'
    }
    Send-Data 'netDiag' @{ Rows = $rows.ToArray(); Summary = $summary; Kind = $kind }
    Write-Log $summary $kind
}

function Set-DnsPreset {
    # Sin $Servers vuelve a automático (DHCP). La lista de proveedores vive en la UI ($dnsProviders).
    param([string]$Name, [string[]]$Servers)
    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')
    if ($adapters.Count -eq 0) { throw 'No hay adaptadores de red físicos conectados.' }
    foreach ($a in $adapters) {
        if (-not $Servers -or $Servers.Count -eq 0) {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction Stop
            Write-Log "'$($a.Name)': DNS automático (DHCP)." 'OK'
        } else {
            Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $Servers -ErrorAction Stop
            Write-Log "'$($a.Name)': DNS $Name ($($Servers -join ', '))." 'OK'
        }
    }
    Clear-DnsClientCache -ErrorAction Stop
    Write-Log 'Caché DNS vaciada. Usa «Diagnosticar red» para comprobar el resultado.' 'OK'
}

function Get-SupportReport {
    # Texto para pegar en un ticket de soporte; la UI lo copia al portapapeles.
    Write-Log 'Armando el informe para soporte...'
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $sysDrive = $env:SystemDrive
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'"
    $uptime = (Get-Date) - $os.LastBootUpTime

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("INFORME PARA SOPORTE · $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    $lines.Add("Equipo: $env:COMPUTERNAME")
    $lines.Add("Usuario: $env:USERDOMAIN\$env:USERNAME")
    $lines.Add("Fabricante / modelo: $($cs.Manufacturer.Trim()) $($cs.Model.Trim())")
    $lines.Add("Número de serie: $($bios.SerialNumber.Trim())")
    $lines.Add("Sistema: $($os.Caption) · versión $($os.Version) · build $($os.BuildNumber)")
    $lines.Add("Procesador: $($cpu.Name.Trim())")
    $lines.Add(('Memoria RAM: {0:N1} GB ({1:N1} GB libres)' -f ($cs.TotalPhysicalMemory / 1GB), ($os.FreePhysicalMemory * 1KB / 1GB)))
    $lines.Add(('Disco {0} {1:N1} GB libres de {2:N1} GB' -f $sysDrive, ($disk.FreeSpace / 1GB), ($disk.Size / 1GB)))
    $lines.Add(('Encendido hace: {0}d {1}h {2}m' -f $uptime.Days, $uptime.Hours, $uptime.Minutes))
    foreach ($a in @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up')) {
        $cfg = Get-NetIPConfiguration -InterfaceIndex $a.ifIndex -ErrorAction SilentlyContinue
        $ips = @($cfg.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
        $gw = ($cfg.IPv4DefaultGateway | Select-Object -First 1).NextHop
        $lines.Add("Red: $($a.Name) · IP $ips · puerta de enlace $gw · MAC $($a.MacAddress)")
    }
    Send-Data 'supportReport' ($lines -join "`r`n")
}

function Get-HardwareInfo {
    Write-Log 'Leyendo el hardware del equipo...'
    $cpu = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $ramBytes = (Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    $sysDrive = $env:SystemDrive
    $logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$sysDrive'"
    # El modelo del disco del sistema, no el "primer" disco: con dos discos el
    # primero que lista Win32_DiskDrive no siempre es el que tiene a C:.
    $diskModel = try { (Get-Partition -DriveLetter $sysDrive[0] -ErrorAction Stop | Get-Disk -ErrorAction Stop).FriendlyName } catch { (Get-CimInstance Win32_DiskDrive | Select-Object -First 1).Model }
    $uptime = (Get-Date) - $os.LastBootUpTime

    Send-Data 'hardware' @{
        CpuMain    = $cpu.Name.Trim()
        CpuDetail  = '{0} núcleos · {1} hilos · {2:N2} GHz' -f $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors, ($cpu.MaxClockSpeed / 1000)
        GpuMain    = $(if ($gpus.Count) { $gpus[0] } else { 'No detectada' })
        GpuDetail  = $(if ($gpus.Count -gt 1) { 'También: ' + ($gpus[1..($gpus.Count - 1)] -join ', ') } else { '' })
        RamMain    = '{0:N1} GB' -f ($ramBytes / 1GB)
        RamDetail  = '{0:N1} GB libres' -f ($os.FreePhysicalMemory * 1KB / 1GB)
        DiskMain   = $diskModel
        DiskDetail = '{0} {1:N1} GB libres de {2:N1} GB' -f $sysDrive, ($logical.FreeSpace / 1GB), ($logical.Size / 1GB)
        OsMain     = $os.Caption
        OsDetail   = "Versión $($os.Version) · build $($os.BuildNumber)"
        PcMain     = $env:COMPUTERNAME
        PcDetail   = 'Usuario {0} · encendido hace {1}d {2}h {3}m' -f $env:USERNAME, $uptime.Days, $uptime.Hours, $uptime.Minutes
    }
    Write-Log 'Hardware actualizado.' 'OK'
}

function Restart-ExplorerShell {
    Write-Log 'Cerrando explorer.exe...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    # Windows relanza el shell solo (AutoRestartShell). Lanzarlo desde este proceso
    # elevado dejaría el escritorio corriendo como administrador: solo se hace si
    # Windows no lo levantó en 8 s.
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt 8 -and -not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Start-Sleep -Milliseconds 300
    }
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) {
        Write-Log 'Windows no relanzó el shell; iniciándolo...' 'WARN'
        Start-Process explorer.exe
    }
    Write-Log 'Explorador de Windows reiniciado.' 'OK'
}

function Reset-Network {
    # El panel web apagaba una interfaz llamada literalmente "Wi-Fi"; acá se
    # reinician los adaptadores físicos conectados, se llamen como se llamen.
    $adapters = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object Status -eq 'Up')
    if ($adapters.Count -eq 0) {
        Write-Log 'No hay adaptadores de red físicos conectados.' 'WARN'
    }
    foreach ($a in $adapters) {
        Write-Log "Reiniciando adaptador '$($a.Name)' ($($a.InterfaceDescription))..."
        Restart-NetAdapter -Name $a.Name -Confirm:$false -ErrorAction Stop
    }
    if ($adapters.Count) {
        Write-Log 'Esperando a que los adaptadores vuelvan a conectarse...'
        $clock = [Diagnostics.Stopwatch]::StartNew()
        do {
            Start-Sleep -Seconds 1
            $up = @(Get-NetAdapter -Name $adapters.Name -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up').Count
        } while ($up -lt $adapters.Count -and $clock.Elapsed.TotalSeconds -lt 30)
        if ($up -lt $adapters.Count) { Write-Log 'Algún adaptador sigue desconectado tras 30 s.' 'WARN' }
    }

    Write-Log 'Vaciando caché DNS...'
    Clear-DnsClientCache -ErrorAction Stop
    Write-Log 'Renovando IP (ipconfig /renew)...'
    $r = Invoke-Native -File 'ipconfig.exe' -Arguments '/renew' -TimeoutSeconds 90
    if ($r.TimedOut) {
        Write-Log 'ipconfig /renew no respondió en 90 s.' 'WARN'
    } elseif ($r.Code -ne 0) {
        $msg = @(($r.Output + "`n" + $r.Error) -split '[\r\n]+' | Where-Object { $_.Trim() }) | Select-Object -Last 1
        Write-Log "ipconfig /renew terminó con código $($r.Code): $msg" 'WARN'
    }
    Write-Log 'Red restablecida.' 'OK'
}

function Restart-ServiceChecked {
    param([string]$Name, [string]$Label)
    Write-Log "Reiniciando $Label ($Name)..."
    Restart-Service -Name $Name -Force -ErrorAction Stop
    Write-Log "$Label reiniciado." 'OK'
}

function Restart-Spooler { Restart-ServiceChecked -Name 'Spooler' -Label 'Cola de impresión' }

function Restart-WindowsUpdate { Restart-ServiceChecked -Name 'wuauserv' -Label 'Windows Update' }

function Restart-AudioServices {
    # Audiosrv depende de AudioEndpointBuilder: se detienen en ese orden y se
    # arrancan al revés.
    Write-Log 'Deteniendo Audiosrv y AudioEndpointBuilder...'
    Stop-Service -Name 'Audiosrv' -Force -ErrorAction Stop
    Stop-Service -Name 'AudioEndpointBuilder' -Force -ErrorAction Stop
    Write-Log 'Iniciando AudioEndpointBuilder y Audiosrv...'
    Start-Service -Name 'AudioEndpointBuilder' -ErrorAction Stop
    Start-Service -Name 'Audiosrv' -ErrorAction Stop
    Write-Log 'Servicios de audio reiniciados.' 'OK'
}

function Invoke-FullMaintenance {
    # A diferencia del panel web, un paso que falla no corta la secuencia.
    $steps = @(
        @{ Label = 'Cola de impresión'; Command = 'Restart-Spooler' }
        @{ Label = 'Servicios de audio'; Command = 'Restart-AudioServices' }
        @{ Label = 'Windows Update'; Command = 'Restart-WindowsUpdate' }
        @{ Label = 'Red'; Command = 'Reset-Network' }
        @{ Label = 'Explorador de Windows'; Command = 'Restart-ExplorerShell' }
    )
    $failed = 0
    for ($i = 0; $i -lt $steps.Count; $i++) {
        Write-Log ("[{0}/{1}] {2}" -f ($i + 1), $steps.Count, $steps[$i].Label) 'STEP'
        try { & $steps[$i].Command }
        catch {
            $failed++
            Write-Log "$($steps[$i].Label): $($_.Exception.Message)" 'ERROR'
        }
    }
    if ($failed) { Write-Log "Mantenimiento terminado con $failed paso(s) fallido(s)." 'WARN' }
    else { Write-Log 'Mantenimiento completo terminado sin errores.' 'OK' }
}

function Get-ProfileFolders {
    $desktop = [Environment]::GetFolderPath('Desktop')
    # Descargas no está en Environment.SpecialFolder; se lee su ruta real (puede
    # estar movida a otro disco) de User Shell Folders.
    $downloads = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'
    $downloads = if ($downloads) { [Environment]::ExpandEnvironmentVariables($downloads) } else { Join-Path $env:USERPROFILE 'Downloads' }
    [pscustomobject]@{
        Backup  = Join-Path $desktop 'Respaldo_Usuario'
        Folders = @(
            [pscustomobject]@{ Label = 'Escritorio'; Path = $desktop }
            [pscustomobject]@{ Label = 'Descargas'; Path = $downloads }
            [pscustomobject]@{ Label = 'Documentos'; Path = [Environment]::GetFolderPath('MyDocuments') }
        )
    }
}

function Backup-UserProfile {
    $profileInfo = Get-ProfileFolders
    $backup = $profileInfo.Backup
    Write-Log "Destino del respaldo: $backup"

    foreach ($f in $profileInfo.Folders) {
        if (-not (Test-Path $f.Path)) { Write-Log "$($f.Label): no existe ($($f.Path)), se omite." 'WARN'; continue }
        $dest = Join-Path $backup $f.Label
        Write-Log "Moviendo $($f.Label)..."
        # /XJ: Documentos trae junctions heredadas ("Mi música", etc.) que robocopy
        # seguiría. desktop.ini se excluye en las tres: sin él la carpeta pierde su
        # nombre e ícono localizados.
        $robocopyArgs = "`"$($f.Path)`" `"$dest`" *.* /E /MOVE /XJ /XF desktop.ini /XD `"$backup`" /R:1 /W:1 /NP /NFL /NDL /NJH /NJS"
        $r = Invoke-Native -File 'robocopy.exe' -Arguments $robocopyArgs -TimeoutSeconds 3600
        if ($r.TimedOut) {
            Write-Log "$($f.Label): robocopy no terminó en 1 hora." 'ERROR'
        } elseif ($r.Code -ge 8) {
            # 8 o más: hubo archivos que no se pudieron mover (en uso, sin permiso).
            Write-Log "$($f.Label): algunos archivos no se pudieron mover (código $($r.Code))." 'WARN'
            @($r.Output -split '[\r\n]+' | Where-Object { $_ -match 'ERROR' }) | Select-Object -First 5 | ForEach-Object { Write-Log "  $($_.Trim())" 'WARN' }
        } elseif ($r.Code -eq 0) {
            Write-Log "$($f.Label): estaba vacía." 'OK'
        } else {
            Write-Log "$($f.Label): movida al respaldo." 'OK'
        }
    }

    $wallpaper = Join-Path $env:SystemRoot 'Web\Wallpaper\Windows\img0.jpg'
    if (Test-Path $wallpaper) {
        Write-Log 'Restableciendo el fondo de pantalla de Windows...'
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
        Set-ItemProperty 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
        # SPI_SETDESKWALLPAPER (0x14) con SPIF_UPDATEINIFILE | SPIF_SENDCHANGE (0x3)
        # aplica el fondo al instante; el "RUNDLL32 UpdatePerUserSystemParameters"
        # del .bat original no siempre refrescaba.
        if ([PanelNative]::SystemParametersInfo(0x14, 0, $wallpaper, 0x3)) {
            Write-Log 'Fondo de pantalla restablecido.' 'OK'
        } else {
            Write-Log 'Windows rechazó el cambio de fondo de pantalla.' 'WARN'
        }
    } else {
        Write-Log 'No se encontró el fondo por defecto de Windows; se omite.' 'WARN'
    }
}

$workerFunctions = @(
    'Write-Log', 'Send-Data', 'Invoke-Native', 'Get-Column', 'ConvertFrom-WingetTable',
    'Find-PendingUpgrades', 'Get-WingetErrorMessage', 'Install-SelectedUpgrades', 'Find-WindowsUpdates', 'Install-WindowsUpdates', 'Test-PrinterSocket', 'Send-PrinterResult',
    'Get-PrinterDriverNames', 'Test-PrinterConnection', 'Send-PrinterTestPage', 'Get-InstalledPrinters',
    'Update-PrinterData', 'Set-DefaultPrinterByName', 'Remove-PrinterByName', 'Clear-PrintQueueDeep',
    'Install-NetworkPrinter', 'Test-HostPing', 'Resolve-HostName', 'Get-NetworkDiagnosis', 'Set-DnsPreset',
    'Get-SupportReport', 'Get-HardwareInfo', 'Restart-ExplorerShell', 'Reset-Network',
    'Restart-ServiceChecked', 'Restart-Spooler', 'Restart-WindowsUpdate', 'Restart-AudioServices',
    'Invoke-FullMaintenance', 'Get-ProfileFolders', 'Backup-UserProfile'
)

$iss = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
# Sin esto, con la política Restricted (la de fábrica en Windows) el runspace no
# puede autocargar NetAdapter/DnsClient, que traen archivos .ps1xml.
$iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass
$iss.Variables.Add((New-Object Management.Automation.Runspaces.SessionStateVariableEntry 'sync', $sync, ''))
foreach ($name in $workerFunctions) {
    $iss.Commands.Add((New-Object Management.Automation.Runspaces.SessionStateFunctionEntry $name, (Get-Item "function:$name").Definition))
}

# --- Interfaz ----------------------------------------------------------------

function ConvertTo-XmlText { param([string]$Text) [Security.SecurityElement]::Escape($Text) }

function New-ActionCardXaml {
    param([string]$Name, [string]$Glyph, [string]$Color, [string]$Title, [string]$Description, [string]$ButtonText, [string]$ButtonStyle = 'SecondaryButton')
    @"
<Border Style="{StaticResource Card}">
  <DockPanel>
    <Border DockPanel.Dock="Left" Width="36" Height="36" CornerRadius="9" Background="#26$Color" VerticalAlignment="Top" Margin="0,0,14,0">
      <TextBlock Text="$Glyph" FontFamily="Segoe Fluent Icons, Segoe MDL2 Assets" FontSize="17" Foreground="#FF$Color" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Border>
    <Button x:Name="$Name" DockPanel.Dock="Bottom" Content="$(ConvertTo-XmlText $ButtonText)" Style="{StaticResource $ButtonStyle}" Padding="14,6" HorizontalAlignment="Left" Margin="0,12,0,0"/>
    <StackPanel>
      <TextBlock Text="$(ConvertTo-XmlText $Title)" Style="{StaticResource CardTitle}" Margin="0,0,0,4"/>
      <TextBlock Text="$(ConvertTo-XmlText $Description)" Style="{StaticResource CardText}"/>
    </StackPanel>
  </DockPanel>
</Border>
"@
}

function New-InfoCardXaml {
    param([string]$Key, [string]$Label)
    @"
<Border Style="{StaticResource Card}">
  <StackPanel>
    <TextBlock Text="$(ConvertTo-XmlText $Label)" Style="{StaticResource Eyebrow}"/>
    <TextBlock x:Name="hw${Key}Main" Text="—" Style="{StaticResource InfoMain}"/>
    <TextBlock x:Name="hw${Key}Detail" Style="{StaticResource CardText}"/>
  </StackPanel>
</Border>
"@
}

$serviceCards = @(
    New-ActionCardXaml 'btnExplorer' '&#xE8B7;' '8EC5F0' 'Explorador de Windows' 'Reinicia el shell para refrescar la barra de tareas, el escritorio y el explorador de archivos.' 'Reiniciar'
    New-ActionCardXaml 'btnNetwork' '&#xE701;' '8EDCC8' 'Red y Wi-Fi' 'Reinicia los adaptadores conectados, vacía la caché DNS y pide una IP nueva por DHCP.' 'Restablecer'
    New-ActionCardXaml 'btnSpooler' '&#xE749;' 'F5D58A' 'Cola de impresión' 'Reinicia el servicio Spooler para desbloquear trabajos de impresión atascados.' 'Reiniciar'
    New-ActionCardXaml 'btnAudio' '&#xE767;' 'C9A9E8' 'Servicios de audio' 'Reinicia Audiosrv y AudioEndpointBuilder si el sonido se corta o no aparecen salidas.' 'Reiniciar'
    New-ActionCardXaml 'btnUpdate' '&#xE895;' '9FDFBF' 'Windows Update' 'Reinicia el servicio de actualizaciones cuando una descarga o un análisis se queda colgado.' 'Reiniciar'
    New-ActionCardXaml 'btnAll' '&#xE90F;' 'A5B4FC' 'Mantenimiento completo' 'Ejecuta todo lo anterior en secuencia. Si un paso falla, sigue con el siguiente.' 'Ejecutar todo' 'AccentButton'
) -join "`n"

$infoCards = @(
    New-InfoCardXaml 'Cpu' 'PROCESADOR'
    New-InfoCardXaml 'Gpu' 'TARJETA GRÁFICA'
    New-InfoCardXaml 'Ram' 'MEMORIA RAM'
    New-InfoCardXaml 'Disk' 'DISCO DEL SISTEMA'
    New-InfoCardXaml 'Os' 'SISTEMA OPERATIVO'
    New-InfoCardXaml 'Pc' 'EQUIPO'
) -join "`n"

# Proveedores de DNS de la pestaña Red. Una sola lista genera los botones, se lee al aplicar
# y se pasa al worker; para sumar uno basta agregar una fila (sin Servers = automático/DHCP).
$dnsProviders = @(
    @{ Key = 'Auto'; Label = 'Automático (los entrega el router por DHCP)'; Servers = @() }
    @{ Key = 'Google'; Label = 'Google'; Servers = @('8.8.8.8', '8.8.4.4') }
    @{ Key = 'Cloudflare'; Label = 'Cloudflare'; Servers = @('1.1.1.1', '1.0.0.1') }
    @{ Key = 'Quad9'; Label = 'Quad9 (bloquea sitios maliciosos)'; Servers = @('9.9.9.9', '149.112.112.112') }
    @{ Key = 'OpenDNS'; Label = 'OpenDNS (Cisco)'; Servers = @('208.67.222.222', '208.67.220.220') }
    @{ Key = 'AdGuard'; Label = 'AdGuard (bloquea anuncios y rastreadores)'; Servers = @('94.140.14.14', '94.140.15.15') }
    @{ Key = 'CleanBrowsing'; Label = 'CleanBrowsing (filtro familiar)'; Servers = @('185.228.168.168', '185.228.169.168') }
)
$dnsRadios = ($dnsProviders | ForEach-Object {
        $text = if ($_.Servers.Count) { "$($_.Label)  ·  $($_.Servers -join '  y  ')" } else { $_.Label }
        $checked = if ($_.Key -eq 'Auto') { ' IsChecked="True"' } else { '' }
        "<RadioButton x:Name=`"dns$($_.Key)`" Content=`"$(ConvertTo-XmlText $text)`" GroupName=`"dns`"$checked/>"
    }) -join "`n"

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Utilidades de Windows · Orange Latam" MinWidth="760" MinHeight="560"
        WindowStartupLocation="CenterScreen" Background="#0A0B10" Foreground="#C5C9DB"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" UseLayoutRounding="True">
  <Window.Resources>
    <Style x:Key="BaseButton" TargetType="Button">
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Background" Value="#1E2030"/>
      <Setter Property="BorderBrush" Value="#2C2F45"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="16,8"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8"/>
              <Border x:Name="overlay" Background="#18FFFFFF" CornerRadius="8" Opacity="0"/>
              <ContentPresenter Margin="{TemplateBinding Padding}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="overlay" Property="Opacity" Value="1"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="overlay" Property="Background" Value="#30000000"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#C7D2FE"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="GridHeader" TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#11121A"/>
      <Setter Property="Foreground" Value="#7E849E"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Padding" Value="10,8"/>
      <Setter Property="BorderBrush" Value="#22253A"/>
      <Setter Property="BorderThickness" Value="0,0,0,1"/>
    </Style>
    <Style x:Key="GridCell" TargetType="DataGridCell">
      <Setter Property="Padding" Value="10,0"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="DataGridCell">
            <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <ContentPresenter VerticalAlignment="Center"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#33A5B4FC"/>
          <Setter Property="Foreground" Value="#FFFFFF"/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key="DataTable" TargetType="DataGrid">
      <Setter Property="AutoGenerateColumns" Value="False"/>
      <Setter Property="HeadersVisibility" Value="Column"/>
      <Setter Property="GridLinesVisibility" Value="Horizontal"/>
      <Setter Property="HorizontalGridLinesBrush" Value="#22253A"/>
      <Setter Property="CanUserAddRows" Value="False"/>
      <Setter Property="SelectionMode" Value="Single"/>
      <Setter Property="RowHeight" Value="30"/>
      <Setter Property="Background" Value="#171824"/>
      <Setter Property="RowBackground" Value="#171824"/>
      <Setter Property="AlternatingRowBackground" Value="#1A1B28"/>
      <Setter Property="Foreground" Value="#C5C9DB"/>
      <Setter Property="BorderBrush" Value="#22253A"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="ColumnHeaderStyle" Value="{StaticResource GridHeader}"/>
      <Setter Property="CellStyle" Value="{StaticResource GridCell}"/>
    </Style>
    <Style TargetType="RadioButton">
      <Setter Property="Foreground" Value="#C5C9DB"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#11121A"/>
      <Setter Property="Foreground" Value="#C5C9DB"/>
      <Setter Property="CaretBrush" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#2A2E45"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="FontSize" Value="13"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#C5C9DB"/>
      <Setter Property="Margin" Value="0,0,0,6"/>
    </Style>
    <Style x:Key="PickList" TargetType="ListBox">
      <Setter Property="Background" Value="#11121A"/>
      <Setter Property="Foreground" Value="#C5C9DB"/>
      <Setter Property="BorderBrush" Value="#2A2E45"/>
      <Setter Property="ItemContainerStyle">
        <Setter.Value>
          <Style TargetType="ListBoxItem">
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Template">
              <Setter.Value>
                <ControlTemplate TargetType="ListBoxItem">
                  <Border Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
                    <ContentPresenter/>
                  </Border>
                </ControlTemplate>
              </Setter.Value>
            </Setter>
            <Style.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="#1A1B28"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Background" Value="#33A5B4FC"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
            </Style.Triggers>
          </Style>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}"/>
    <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
      <Setter Property="Background" Value="#A5B4FC"/>
      <Setter Property="BorderBrush" Value="#A5B4FC"/>
      <Setter Property="Foreground" Value="#12131F"/>
    </Style>
    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
      <Setter Property="Background" Value="#F2A0A8"/>
      <Setter Property="BorderBrush" Value="#F2A0A8"/>
      <Setter Property="Foreground" Value="#2A1215"/>
    </Style>
    <Style x:Key="GhostButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Padding" Value="10,3"/>
      <Setter Property="FontWeight" Value="Normal"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="#C5C9DB"/>
    </Style>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="#171824"/>
      <Setter Property="BorderBrush" Value="#22253A"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="12"/>
      <Setter Property="Padding" Value="16"/>
      <Setter Property="Margin" Value="0,0,12,12"/>
    </Style>
    <Style x:Key="CardTitle" TargetType="TextBlock">
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="Margin" Value="0,12,0,4"/>
    </Style>
    <Style x:Key="CardText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#8C92AC"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="LineHeight" Value="19"/>
    </Style>
    <Style x:Key="Eyebrow" TargetType="TextBlock">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#C7D2FE"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
    </Style>
    <Style x:Key="InfoMain" TargetType="TextBlock">
      <Setter Property="FontSize" Value="16"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,0,0,4"/>
    </Style>
    <Style x:Key="SectionTitle" TargetType="TextBlock">
      <Setter Property="FontSize" Value="20"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="#FFFFFF"/>
    </Style>
    <Style x:Key="SectionText" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#8C92AC"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="0,4,0,0"/>
    </Style>

    <ControlTemplate x:Key="ScrollThumb" TargetType="Thumb">
      <Border Background="#2C2F45" CornerRadius="4" Margin="2"/>
    </ControlTemplate>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="10"/>
      <Setter Property="MinWidth" Value="10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.Thumb><Thumb Template="{StaticResource ScrollThumb}"/></Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/>
          <Setter Property="MinWidth" Value="0"/>
          <Setter Property="Height" Value="10"/>
          <Setter Property="MinHeight" Value="10"/>
          <Setter Property="Template">
            <Setter.Value>
              <ControlTemplate TargetType="ScrollBar">
                <Track x:Name="PART_Track">
                  <Track.Thumb><Thumb Template="{StaticResource ScrollThumb}"/></Track.Thumb>
                </Track>
              </ControlTemplate>
            </Setter.Value>
          </Setter>
        </Trigger>
      </Style.Triggers>
    </Style>

    <Style x:Key="SubTabs" TargetType="TabControl">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <DockPanel>
              <TabPanel DockPanel.Dock="Top" IsItemsHost="True" Margin="0,0,0,14"/>
              <ContentPresenter ContentSource="SelectedContent"/>
            </DockPanel>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SubTab" TargetType="TabItem">
      <Setter Property="Foreground" Value="#8C92AC"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Border x:Name="pill" CornerRadius="16" Padding="16,6" Margin="0,0,8,0" Cursor="Hand"
                    Background="#171824" BorderBrush="#22253A" BorderThickness="1">
              <ContentPresenter ContentSource="Header" HorizontalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter TargetName="pill" Property="Background" Value="#1E2030"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Foreground" Value="#C7D2FE"/>
                <Setter TargetName="pill" Property="Background" Value="#33A5B4FC"/>
                <Setter TargetName="pill" Property="BorderBrush" Value="#A5B4FC"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <DockPanel>
              <Border DockPanel.Dock="Top" BorderBrush="#1E2030" BorderThickness="0,0,0,1" Padding="20,0">
                <TabPanel IsItemsHost="True"/>
              </Border>
              <ContentPresenter ContentSource="SelectedContent" Margin="24,16,12,0"/>
            </DockPanel>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#7E849E"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Grid Background="Transparent" Cursor="Hand" Margin="0,0,8,0">
              <ContentPresenter ContentSource="Header" Margin="12,9,12,11"/>
              <Border x:Name="line" Height="2" VerticalAlignment="Bottom" Background="#A5B4FC" CornerRadius="1" Visibility="Hidden"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="#FFFFFF"/></Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter TargetName="line" Property="Visibility" Value="Visible"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Grid Background="#0A0B10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*" MinHeight="300"/>
      <RowDefinition Height="5"/>
      <RowDefinition x:Name="consoleRow" Height="120" MinHeight="90"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="24,12,24,8">
      <Border DockPanel.Dock="Right" x:Name="adminBadge" CornerRadius="12" Padding="12,5" VerticalAlignment="Center" Background="#269FDFBF">
        <TextBlock x:Name="adminText" FontSize="12" FontWeight="SemiBold" Foreground="#9FDFBF"/>
      </Border>
      <StackPanel Orientation="Horizontal">
        <Border Width="34" Height="34" CornerRadius="9" Background="#A5B4FC">
          <TextBlock Text="OL" FontSize="14" FontWeight="Bold" Foreground="#12131F" HorizontalAlignment="Center" VerticalAlignment="Center"/>
        </Border>
        <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
          <TextBlock Text="Utilidades de Windows" FontSize="18" FontWeight="SemiBold" Foreground="#FFFFFF"/>
          <TextBlock x:Name="hostText" FontSize="12" Foreground="#7E849E"/>
        </StackPanel>
      </StackPanel>
    </DockPanel>

    <TabControl Grid.Row="1" x:Name="tabs" Background="Transparent" BorderThickness="0">
      <TabItem Header="Servicios">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <StackPanel Margin="0,0,12,14">
              <TextBlock Text="Reinicio rápido de servicios" Style="{StaticResource SectionTitle}"/>
              <TextBlock Text="Arreglos de un clic para fallos comunes de red, audio, impresión y el escritorio." Style="{StaticResource SectionText}"/>
            </StackPanel>
            <UniformGrid x:Name="servicesGrid" Columns="3">
$serviceCards
            </UniformGrid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Hardware">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel>
            <DockPanel Margin="0,0,12,14">
              <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
                <Button x:Name="btnCopyReport" Content="Copiar informe para soporte" Style="{StaticResource AccentButton}" Margin="0,0,8,0"/>
                <Button x:Name="btnRefreshHw" Content="Volver a leer" Style="{StaticResource SecondaryButton}"/>
              </StackPanel>
              <StackPanel>
                <TextBlock Text="Hardware y sistema" Style="{StaticResource SectionTitle}"/>
                <TextBlock Text="Datos leídos de Windows (CIM) al abrir el panel." Style="{StaticResource SectionText}"/>
              </StackPanel>
            </DockPanel>
            <UniformGrid x:Name="hwGrid" Columns="3">
$infoCards
            </UniformGrid>
          </StackPanel>
        </ScrollViewer>
      </TabItem>

      <TabItem Header="Actualizaciones">
        <DockPanel Margin="0,0,12,12">
          <DockPanel DockPanel.Dock="Top" Margin="0,0,0,14">
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
              <Button x:Name="btnScan" Content="Buscar actualizaciones" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
              <Button x:Name="btnRunUpdater" Content="Actualizar todo" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
              <Button x:Name="btnInstallSelected" Content="Actualizar seleccionadas" Style="{StaticResource AccentButton}"/>
            </StackPanel>
            <StackPanel>
              <TextBlock Text="Actualizaciones de software" Style="{StaticResource SectionTitle}"/>
              <TextBlock Text="«Actualizar seleccionadas» instala aquí las marcadas, con límite de 5 min por app. «Actualizar todo» abre ActualizarApps en su propia ventana, con log y revisión de navegadores y driver NVIDIA." Style="{StaticResource SectionText}"/>
            </StackPanel>
          </DockPanel>
          <TextBlock x:Name="upgSummary" DockPanel.Dock="Top" Margin="0,0,0,10" Text="Usa «Buscar actualizaciones» para ver qué aplicaciones tienen versión nueva."/>
          <DataGrid x:Name="upgGrid" Style="{StaticResource DataTable}">
            <DataGrid.Columns>
              <DataGridTemplateColumn Header="" Width="44">
                <DataGridTemplateColumn.CellTemplate>
                  <DataTemplate>
                    <CheckBox IsChecked="{Binding Selected, UpdateSourceTrigger=PropertyChanged}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </DataTemplate>
                </DataGridTemplateColumn.CellTemplate>
              </DataGridTemplateColumn>
              <DataGridTextColumn Header="Aplicación" Binding="{Binding Name}" IsReadOnly="True" Width="2*"/>
              <DataGridTextColumn Header="Id" Binding="{Binding Id}" IsReadOnly="True" Width="2*"/>
              <DataGridTextColumn Header="Instalada" Binding="{Binding Version}" IsReadOnly="True" Width="*"/>
              <DataGridTextColumn Header="Disponible" Binding="{Binding Available}" IsReadOnly="True" Width="*"/>
              <DataGridTextColumn Header="Origen" Binding="{Binding Source}" IsReadOnly="True" Width="0.7*"/>
              <DataGridTextColumn Header="Estado" Binding="{Binding Status}" IsReadOnly="True" Width="1.2*"/>
            </DataGrid.Columns>
          </DataGrid>
        </DockPanel>
      </TabItem>

      <TabItem Header="Windows Update">
        <DockPanel Margin="0,0,12,12">
          <DockPanel DockPanel.Dock="Top" Margin="0,0,0,14">
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
              <Button x:Name="btnWinScan" Content="Buscar actualizaciones" Style="{StaticResource SecondaryButton}" Margin="0,0,8,0"/>
              <Button x:Name="btnWinInstall" Content="Instalar seleccionadas" Style="{StaticResource AccentButton}"/>
            </StackPanel>
            <StackPanel>
              <TextBlock Text="Actualizaciones de Windows" Style="{StaticResource SectionTitle}"/>
              <TextBlock Text="Busca e instala las actualizaciones del sistema, Defender y controladores con la API de Windows Update, de a una. Una acumulativa puede tardar de 10 a 30 min y no tiene límite de tiempo. No reinicia el equipo por su cuenta." Style="{StaticResource SectionText}"/>
            </StackPanel>
          </DockPanel>
          <TextBlock x:Name="winReboot" DockPanel.Dock="Top" Margin="0,0,0,6" Visibility="Collapsed" Foreground="#F5D58A" FontWeight="SemiBold"
                     Text="⚠ Hay un reinicio pendiente. Reinicia el equipo para terminar de aplicar las actualizaciones."/>
          <TextBlock x:Name="winSummary" DockPanel.Dock="Top" Margin="0,0,0,10" Text="Usa «Buscar actualizaciones» para ver qué actualizaciones de Windows hay pendientes (puede tardar unos minutos)."/>
          <DataGrid x:Name="winGrid" Style="{StaticResource DataTable}">
            <DataGrid.Columns>
              <DataGridTemplateColumn Header="" Width="44">
                <DataGridTemplateColumn.CellTemplate>
                  <DataTemplate>
                    <CheckBox IsChecked="{Binding Selected, UpdateSourceTrigger=PropertyChanged}" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  </DataTemplate>
                </DataGridTemplateColumn.CellTemplate>
              </DataGridTemplateColumn>
              <DataGridTextColumn Header="Actualización" Binding="{Binding Title}" IsReadOnly="True" Width="3.5*"/>
              <DataGridTextColumn Header="KB" Binding="{Binding Kb}" IsReadOnly="True" Width="0.9*"/>
              <DataGridTextColumn Header="Tipo" Binding="{Binding Type}" IsReadOnly="True" Width="0.9*"/>
              <DataGridTextColumn Header="Estado" Binding="{Binding Status}" IsReadOnly="True" Width="1.5*"/>
            </DataGrid.Columns>
          </DataGrid>
        </DockPanel>
      </TabItem>

      <TabItem Header="Red">
        <TabControl Style="{StaticResource SubTabs}">
          <TabItem Header="Diagnóstico" Style="{StaticResource SubTab}">
            <DockPanel Margin="0,0,12,12">
              <DockPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                <Button x:Name="btnNetDiag" DockPanel.Dock="Right" Content="Diagnosticar red" Style="{StaticResource AccentButton}" VerticalAlignment="Center" Margin="16,0,0,0"/>
                <TextBlock Text="IP, DNS y MAC de los adaptadores conectados, más pruebas del router, de internet y de la resolución de nombres para ubicar dónde falla." Style="{StaticResource SectionText}" VerticalAlignment="Center"/>
              </DockPanel>
              <TextBlock x:Name="netSummary" DockPanel.Dock="Top" Margin="0,0,0,10" TextWrapping="Wrap" FontWeight="SemiBold" Foreground="#7E849E"
                         Text="Pulsa «Diagnosticar red» para empezar."/>
              <DataGrid x:Name="netGrid" Style="{StaticResource DataTable}" IsReadOnly="True">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="Prueba" Binding="{Binding Test}" Width="2*"/>
                  <DataGridTextColumn Header="Resultado" Binding="{Binding Result}" Width="3*"/>
                  <DataGridTextColumn Header="Estado" Binding="{Binding State}" Width="*"/>
                </DataGrid.Columns>
              </DataGrid>
            </DockPanel>
          </TabItem>
          <TabItem Header="Servidores DNS" Style="{StaticResource SubTab}">
            <StackPanel>
              <Border Style="{StaticResource Card}" Margin="0,0,12,12">
                <StackPanel>
                  <TextBlock Text="SERVIDORES DNS" Style="{StaticResource Eyebrow}"/>
                  <TextBlock Style="{StaticResource CardText}" Margin="0,0,0,12"
                             Text="Se aplican a los adaptadores físicos conectados y vacían la caché DNS. Requiere administrador. Útil cuando hay internet pero algunas páginas no cargan."/>
                  <UniformGrid Columns="2">
$dnsRadios
                  </UniformGrid>
                  <Button x:Name="btnDnsApply" Content="Aplicar DNS" Style="{StaticResource AccentButton}" HorizontalAlignment="Left" Margin="0,6,0,0"/>
                </StackPanel>
              </Border>
            </StackPanel>
          </TabItem>
        </TabControl>
      </TabItem>

      <TabItem Header="Impresoras">
        <TabControl Style="{StaticResource SubTabs}">
          <TabItem Header="Instalar impresora" Style="{StaticResource SubTab}">
            <DockPanel Margin="0,0,12,12">
              <TextBlock DockPanel.Dock="Top" Margin="0,0,0,10" Style="{StaticResource SectionText}"
                         Text="Crea el puerto TCP/IP estándar (RAW, 9100) y registra la impresora con un controlador ya instalado en Windows. Instala antes el del fabricante (Epson, HP, etc.)."/>
              <DockPanel DockPanel.Dock="Bottom" Margin="0,12,0,0">
                <Button x:Name="btnPrnInstall" DockPanel.Dock="Left" Content="Instalar impresora" Style="{StaticResource AccentButton}"/>
                <TextBlock x:Name="prnResult" TextWrapping="Wrap" Margin="16,0,0,0" VerticalAlignment="Center" Foreground="#7E849E"
                           Text="Elige un controlador, revisa la IP y pulsa «Instalar impresora»."/>
              </DockPanel>
              <Border Style="{StaticResource Card}" Margin="0">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="24"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <StackPanel Grid.Column="0">
                    <TextBlock Text="NOMBRE DE LA IMPRESORA" Style="{StaticResource Eyebrow}"/>
                    <TextBox x:Name="prnName" Text="Impresora Oficina - Orange" Margin="0,0,0,14"/>
                    <TextBlock Text="IP O NOMBRE DE HOST" Style="{StaticResource Eyebrow}"/>
                    <DockPanel Margin="0,0,0,14">
                      <Button x:Name="btnPrnTest" DockPanel.Dock="Right" Content="Probar 9100" Style="{StaticResource SecondaryButton}" Margin="8,0,0,0"/>
                      <TextBox x:Name="prnIp" Text="192.168.8.1" FontFamily="Consolas"/>
                    </DockPanel>
                    <CheckBox x:Name="prnDefault" Content="Establecer como impresora predeterminada" IsChecked="True"/>
                    <CheckBox x:Name="prnTestPage" Content="Imprimir una página de prueba al terminar" IsChecked="True"/>
                  </StackPanel>
                  <DockPanel Grid.Column="2">
                    <DockPanel DockPanel.Dock="Top" Margin="0,0,0,6">
                      <Button x:Name="btnPrnReload" DockPanel.Dock="Right" Content="Recargar lista" Style="{StaticResource GhostButton}"/>
                      <TextBlock Text="CONTROLADOR" Style="{StaticResource Eyebrow}" Margin="0" VerticalAlignment="Center"/>
                    </DockPanel>
                    <ListBox x:Name="prnDrivers" Style="{StaticResource PickList}" MinHeight="150"/>
                  </DockPanel>
                </Grid>
              </Border>
            </DockPanel>
          </TabItem>
          <TabItem Header="Impresoras instaladas" Style="{StaticResource SubTab}">
            <DockPanel Margin="0,0,12,12">
              <TextBlock DockPanel.Dock="Bottom" Style="{StaticResource CardText}" Margin="0,2,0,0"
                         Text="«Limpiar cola a fondo» detiene el Spooler, borra los trabajos atascados y lo vuelve a iniciar (administrador). Los trabajos pendientes se pierden."/>
              <WrapPanel DockPanel.Dock="Bottom" Margin="0,12,0,0">
                <Button x:Name="btnPrnDefault" Content="Predeterminada" Style="{StaticResource SecondaryButton}" Margin="0,0,8,6"/>
                <Button x:Name="btnPrnTestPage" Content="Página de prueba" Style="{StaticResource SecondaryButton}" Margin="0,0,8,6"/>
                <Button x:Name="btnPrnRemove" Content="Quitar" Style="{StaticResource DangerButton}" Margin="0,0,8,6"/>
                <Button x:Name="btnPrnClearQueue" Content="Limpiar cola a fondo" Style="{StaticResource SecondaryButton}" Margin="0,0,8,6"/>
              </WrapPanel>
              <DockPanel DockPanel.Dock="Top" Margin="0,0,0,10">
                <Button x:Name="btnPrnRefresh" DockPanel.Dock="Right" Content="Actualizar lista" Style="{StaticResource GhostButton}" Margin="16,0,0,0"/>
                <TextBlock Text="Selecciona una impresora y usa los botones de abajo." Style="{StaticResource SectionText}" VerticalAlignment="Center"/>
              </DockPanel>
              <DataGrid x:Name="prnList" Style="{StaticResource DataTable}" IsReadOnly="True">
                <DataGrid.Columns>
                  <DataGridTextColumn Header="Nombre" Binding="{Binding Name}" Width="2*"/>
                  <DataGridTextColumn Header="Controlador" Binding="{Binding Driver}" Width="1.8*"/>
                  <DataGridTextColumn Header="Puerto" Binding="{Binding Port}" Width="1.3*"/>
                  <DataGridTextColumn Header="Estado" Binding="{Binding Status}" Width="118"/>
                  <DataGridTextColumn Header="Pred." Binding="{Binding IsDefault}" Width="64"/>
                </DataGrid.Columns>
              </DataGrid>
            </DockPanel>
          </TabItem>
        </TabControl>
      </TabItem>
      <TabItem Header="Limpieza de perfil">
        <ScrollViewer VerticalScrollBarVisibility="Auto">
          <StackPanel MaxWidth="760" HorizontalAlignment="Left">
            <StackPanel Margin="0,0,12,14">
              <TextBlock Text="Respaldo y limpieza del perfil" Style="{StaticResource SectionTitle}"/>
              <TextBlock Text="Deja el Escritorio, Descargas y Documentos vacíos sin perder nada: todo pasa a una carpeta de respaldo." Style="{StaticResource SectionText}"/>
            </StackPanel>
            <Border Style="{StaticResource Card}">
              <StackPanel>
                <TextBlock Text="QUÉ HACE" Style="{StaticResource Eyebrow}"/>
                <TextBlock Style="{StaticResource CardText}" Margin="0,0,0,6" Text="•  Mueve el contenido de Escritorio, Descargas y Documentos a Respaldo_Usuario, una subcarpeta por origen."/>
                <TextBlock Style="{StaticResource CardText}" Margin="0,0,0,6" Text="•  No borra archivos. Los que estén abiertos o bloqueados se quedan donde están y se listan en la consola."/>
                <TextBlock Style="{StaticResource CardText}" Margin="0,0,0,6" Text="•  Restablece el fondo de pantalla original de Windows."/>
                <TextBlock x:Name="cleanTarget" Foreground="#C5C9DB" TextWrapping="Wrap" Margin="0,8,0,0"/>
              </StackPanel>
            </Border>
            <Button x:Name="btnClean" Content="Respaldar y limpiar perfil" Style="{StaticResource DangerButton}" HorizontalAlignment="Left" Margin="0,4,0,0"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
    </TabControl>

    <GridSplitter x:Name="consoleSplitter" Grid.Row="2" HorizontalAlignment="Stretch" Background="#0A0B10" ResizeDirection="Rows"/>

    <Border Grid.Row="3" Background="#07080C" BorderBrush="#1E2030" BorderThickness="0,1,0,0">
      <DockPanel>
        <DockPanel DockPanel.Dock="Top" Margin="20,8,20,0">
          <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
            <Button x:Name="btnCopyLog" Content="Copiar" Style="{StaticResource GhostButton}" Margin="0,0,6,0"/>
            <Button x:Name="btnClearLog" Content="Limpiar" Style="{StaticResource GhostButton}" Margin="0,0,6,0"/>
            <Button x:Name="btnToggleLog" Content="Ocultar" Style="{StaticResource GhostButton}" ToolTip="Plegar o desplegar la consola"/>
          </StackPanel>
          <DockPanel VerticalAlignment="Center">
            <TextBlock Text="CONSOLA" FontSize="11" FontWeight="SemiBold" Foreground="#7E849E" VerticalAlignment="Center"/>
            <TextBlock x:Name="statusText" Text="Listo" Margin="12,0,12,0" Foreground="#C5C9DB" VerticalAlignment="Center" TextTrimming="CharacterEllipsis"/>
          </DockPanel>
        </DockPanel>
        <ProgressBar x:Name="busyBar" DockPanel.Dock="Top" Height="2" Margin="20,8,20,0" IsIndeterminate="True"
                     Visibility="Hidden" Foreground="#A5B4FC" Background="Transparent" BorderThickness="0"/>
        <RichTextBox x:Name="logBox" IsReadOnly="True" Background="Transparent" BorderThickness="0" Foreground="#C5C9DB"
                     FontFamily="Cascadia Mono, Consolas" FontSize="12" Padding="14,4" VerticalScrollBarVisibility="Auto">
          <FlowDocument PagePadding="0"/>
        </RichTextBox>
      </DockPanel>
    </Border>
  </Grid>
</Window>
"@

$window = [Windows.Markup.XamlReader]::Parse($xaml)

# Tamaño inicial según el área útil (sin barra de tareas), en DIPs. Un alto fijo de
# 800 no entraba en una pantalla 2560x1600 al 200 % (área útil 1280x752).
$workArea = [Windows.SystemParameters]::WorkArea
$window.Width = [Math]::Max($window.MinWidth, [Math]::Min(1120, $workArea.Width - 48))
$window.Height = [Math]::Max($window.MinHeight, [Math]::Min(820, $workArea.Height - 32))

$ui = @{}
foreach ($name in @('adminBadge', 'adminText', 'hostText', 'tabs', 'statusText', 'busyBar', 'logBox', 'btnCopyLog', 'btnClearLog',
        'btnToggleLog', 'consoleRow', 'consoleSplitter', 'servicesGrid', 'hwGrid',
        'btnExplorer', 'btnNetwork', 'btnSpooler', 'btnAudio', 'btnUpdate', 'btnAll', 'btnRefreshHw',
        'btnScan', 'btnRunUpdater', 'btnInstallSelected', 'upgSummary', 'upgGrid', 'btnClean', 'cleanTarget',
        'btnWinScan', 'btnWinInstall', 'winSummary', 'winReboot', 'winGrid',
        'prnName', 'prnIp', 'prnDrivers', 'prnDefault', 'prnTestPage', 'prnResult', 'btnPrnTest', 'btnPrnReload', 'btnPrnInstall',
        'prnList', 'btnPrnRefresh', 'btnPrnDefault', 'btnPrnTestPage', 'btnPrnRemove', 'btnPrnClearQueue',
        'btnNetDiag', 'netGrid', 'netSummary', 'btnDnsApply', 'btnCopyReport')) {
    $ui[$name] = $window.FindName($name)
}
foreach ($p in $dnsProviders) { $ui["dns$($p.Key)"] = $window.FindName("dns$($p.Key)") }
$hwKeys = @('Cpu', 'Gpu', 'Ram', 'Disk', 'Os', 'Pc')
foreach ($k in $hwKeys) {
    $ui["hw${k}Main"] = $window.FindName("hw${k}Main")
    $ui["hw${k}Detail"] = $window.FindName("hw${k}Detail")
}
$actionButtons = @('btnExplorer', 'btnNetwork', 'btnSpooler', 'btnAudio', 'btnUpdate', 'btnAll',
    'btnRefreshHw', 'btnScan', 'btnRunUpdater', 'btnInstallSelected', 'btnWinScan', 'btnWinInstall',
    'btnPrnTest', 'btnPrnReload', 'btnPrnInstall', 'btnPrnRefresh', 'btnPrnDefault', 'btnPrnTestPage', 'btnPrnRemove',
    'btnPrnClearQueue', 'btnNetDiag', 'btnDnsApply', 'btnCopyReport', 'btnClean') | ForEach-Object { $ui[$_] }

$brushConverter = New-Object Windows.Media.BrushConverter
$logBrushes = @{}
foreach ($pair in @(@('INFO', '#C5C9DB'), @('OK', '#9FDFBF'), @('WARN', '#F5D58A'), @('ERROR', '#F2A0A8'), @('STEP', '#C7D2FE'), @('TIME', '#4E5369'))) {
    $logBrushes[$pair[0]] = $brushConverter.ConvertFromString($pair[1])
}

if ($isAdmin) {
    $ui.adminText.Text = 'Administrador'
} else {
    $ui.adminText.Text = 'Sin permisos de administrador'
    $ui.adminText.Foreground = $logBrushes.WARN
    $ui.adminBadge.Background = $brushConverter.ConvertFromString('#26F5D58A')
}
$ui.hostText.Text = "$env:COMPUTERNAME · $env:USERNAME"
$ui.cleanTarget.Text = "Destino: $((Get-ProfileFolders).Backup)"

function Add-LogLine {
    param($Entry)
    $paragraph = New-Object Windows.Documents.Paragraph
    $paragraph.Margin = New-Object Windows.Thickness 0
    $time = New-Object Windows.Documents.Run ($Entry.Time.ToString('HH:mm:ss') + '  ')
    $time.Foreground = $logBrushes.TIME
    $message = New-Object Windows.Documents.Run $Entry.Message
    $message.Foreground = $logBrushes[$Entry.Type]
    $paragraph.Inlines.Add($time)
    $paragraph.Inlines.Add($message)
    $ui.logBox.Document.Blocks.Add($paragraph)
    $ui.logBox.ScrollToEnd()
    if ($script:consoleCollapsed) {
        # Plegada, la consola muestra el último mensaje en su barra; un error la
        # despliega para que no pase desapercibido.
        if ($Entry.Type -eq 'ERROR') {
            Set-ConsoleCollapsed $false
        } else {
            $ui.statusText.Text = $Entry.Message
            $ui.statusText.Foreground = $logBrushes[$Entry.Type]
        }
    }
}

$script:consoleCollapsed = $false
$script:consoleHeight = 170

function Set-ConsoleCollapsed {
    param([bool]$Collapsed)
    if ($Collapsed -eq $script:consoleCollapsed) { return }
    $script:consoleCollapsed = $Collapsed
    if ($Collapsed) {
        $script:consoleHeight = $ui.consoleRow.ActualHeight
        $ui.consoleRow.MinHeight = 0
        $ui.consoleRow.Height = [Windows.GridLength]::Auto
        $ui.logBox.Visibility = 'Collapsed'
        $ui.consoleSplitter.Visibility = 'Collapsed'
        $ui.btnToggleLog.Content = 'Mostrar'
    } else {
        $ui.logBox.Visibility = 'Visible'
        $ui.consoleSplitter.Visibility = 'Visible'
        $ui.consoleRow.Height = New-Object Windows.GridLength ([Math]::Max(90, $script:consoleHeight))
        $ui.consoleRow.MinHeight = 90
        $ui.btnToggleLog.Content = 'Ocultar'
        $ui.statusText.Foreground = $logBrushes.INFO
        $ui.statusText.Text = if ($script:task) { "$($script:task.Title)…" } else { 'Listo' }
        $ui.logBox.ScrollToEnd()
    }
}

function Receive-Data {
    param($Item)
    switch ($Item.Key) {
        'hardware' {
            foreach ($k in $hwKeys) {
                $ui["hw${k}Main"].Text = $Item.Value["${k}Main"]
                $ui["hw${k}Detail"].Text = $Item.Value["${k}Detail"]
            }
        }
        'upgrades' {
            # Filas propias de la UI: llevan la casilla (marcadas de entrada) y el estado.
            $script:upgRows = @($Item.Value | ForEach-Object {
                    [pscustomobject]@{ Selected = $true; Name = $_.Name; Id = $_.Id; Version = $_.Version; Available = $_.Available; Source = $_.Source; Status = 'Pendiente' }
                })
            $ui.upgGrid.ItemsSource = $script:upgRows
            $ui.upgSummary.Text = if ($script:upgRows.Count) { "$($script:upgRows.Count) aplicación(es) con versión nueva. Desmarca las que no quieras y pulsa «Actualizar seleccionadas»." } else { 'Todo al día: winget no encontró actualizaciones.' }
        }
        'winUpdates' {
            # Las que piden licencia o interacción salen sin marcar y avisadas.
            $script:winRows = @($Item.Value | ForEach-Object {
                    [pscustomobject]@{
                        Selected = -not $_.NeedsUser; Id = $_.Id; Title = $_.Title; Kb = $_.Kb; Type = $_.Type
                        Status   = if ($_.NeedsUser) { 'Requiere interacción' } else { 'Pendiente' }
                    }
                })
            $ui.winGrid.ItemsSource = $script:winRows
            $ui.winSummary.Text = if ($script:winRows.Count) { "$($script:winRows.Count) actualización(es) de Windows. Desmarca las que no quieras y pulsa «Instalar seleccionadas»." } else { 'Windows está al día.' }
        }
        'winUpdateStatus' {
            $row = $script:winRows | Where-Object { $_.Id -eq $Item.Value.Id } | Select-Object -First 1
            if ($row) {
                $row.Status = $Item.Value.Status
                $ui.winGrid.Items.Refresh()
            }
        }
        'winReboot' { $ui.winReboot.Visibility = 'Visible' }
        'printerDrivers' { $ui.prnDrivers.ItemsSource = @($Item.Value) }
        'printerList' { $ui.prnList.ItemsSource = @($Item.Value) }
        'netDiag' {
            $ui.netGrid.ItemsSource = @($Item.Value.Rows)
            $ui.netSummary.Text = $Item.Value.Summary
            $ui.netSummary.Foreground = $logBrushes[$Item.Value.Kind]
        }
        'supportReport' {
            try {
                [Windows.Clipboard]::SetText([string]$Item.Value)
                Write-Log 'Informe copiado al portapapeles: pégalo en el ticket de soporte.' 'OK'
            } catch {
                # El portapapeles puede estar bloqueado un instante por otra aplicación.
                Write-Log "No se pudo copiar al portapapeles: $($_.Exception.Message)" 'WARN'
            }
        }
        'printerResult' {
            $ui.prnResult.Text = $Item.Value.Text
            $ui.prnResult.Foreground = $logBrushes[$Item.Value.Kind]
        }
        'upgradeStatus' {
            $row = $script:upgRows | Where-Object { $_.Id -eq $Item.Value.Id } | Select-Object -First 1
            if ($row) {
                $row.Status = $Item.Value.Status
                $ui.upgGrid.Items.Refresh()
            }
        }
    }
}

function Set-Busy {
    param([bool]$Busy, [string]$Title = '')
    foreach ($b in $actionButtons) { $b.IsEnabled = -not $Busy }
    $ui.busyBar.Visibility = if ($Busy) { 'Visible' } else { 'Hidden' }
    # Con la consola plegada la barra ya muestra el último mensaje de la tarea.
    if (-not $script:consoleCollapsed) {
        $ui.statusText.Text = if ($Busy) { "$Title…" } else { 'Listo' }
    }
}

$script:task = $null

function Start-Task {
    param([string]$Title, [string]$Command, [hashtable]$Parameters)
    if ($script:task) { return }
    $ps = [powershell]::Create($iss)
    [void]$ps.AddCommand($Command)
    if ($Parameters) { [void]$ps.AddParameters($Parameters) }
    Set-Busy $true $Title
    Write-Log $Title 'STEP'
    $script:task = @{ PS = $ps; Handle = $ps.BeginInvoke(); Title = $Title; Clock = [Diagnostics.Stopwatch]::StartNew() }
}

function Complete-Task {
    $t = $script:task
    $script:task = $null
    $ok = $true
    try {
        [void]$t.PS.EndInvoke($t.Handle)
    } catch {
        $ok = $false
        # EndInvoke envuelve el error en una MethodInvocationException, y un
        # -ErrorAction Stop en una ActionPreferenceStopException ("The running command
        # stopped because..."); el mensaje útil está en el ErrorRecord original.
        $ex = if ($_.Exception.InnerException) { $_.Exception.InnerException } else { $_.Exception }
        $msg = if ($ex.ErrorRecord -and $ex.ErrorRecord.Exception) { $ex.ErrorRecord.Exception.Message } else { $ex.Message }
        Write-Log $msg 'ERROR'
        if (-not $isAdmin) { Write-Log 'El panel no corre como administrador; reinicia servicios solo con permisos elevados.' 'WARN' }
    }
    foreach ($e in $t.PS.Streams.Error) { Write-Log $e.ToString() 'WARN' }
    $t.PS.Dispose()
    $state = if ($ok) { 'terminado' } else { 'falló' }
    Write-Log ("{0}: {1} en {2:mm\:ss}" -f $t.Title, $state, $t.Clock.Elapsed) $(if ($ok) { 'INFO' } else { 'ERROR' })
    Set-Busy $false
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(100)
$timer.Add_Tick({
        # Se mira si terminó ANTES de vaciar la cola, para no cerrar la tarea con
        # mensajes suyos todavía sin mostrar.
        $finished = $script:task -and $script:task.Handle.IsCompleted
        $item = $null
        while ($sync.Queue.TryDequeue([ref]$item)) {
            if ($item.Kind -eq 'DATA') { Receive-Data $item } else { Add-LogLine $item }
        }
        if ($finished) { Complete-Task }
    })

$ui.btnExplorer.Add_Click({ Start-Task 'Reiniciar Explorador de Windows' 'Restart-ExplorerShell' })
$ui.btnNetwork.Add_Click({ Start-Task 'Restablecer red' 'Reset-Network' })
$ui.btnSpooler.Add_Click({ Start-Task 'Reiniciar cola de impresión' 'Restart-Spooler' })
$ui.btnAudio.Add_Click({ Start-Task 'Reiniciar servicios de audio' 'Restart-AudioServices' })
$ui.btnUpdate.Add_Click({ Start-Task 'Reiniciar Windows Update' 'Restart-WindowsUpdate' })
$ui.btnAll.Add_Click({ Start-Task 'Mantenimiento completo' 'Invoke-FullMaintenance' })
$ui.btnRefreshHw.Add_Click({ Start-Task 'Leer hardware' 'Get-HardwareInfo' })
$ui.btnScan.Add_Click({ Start-Task 'Buscar actualizaciones' 'Find-PendingUpgrades' })

$ui.btnInstallSelected.Add_Click({
        # Se manda una copia mínima: el runspace no debe tocar los objetos de la tabla.
        $selected = @($script:upgRows | Where-Object { $_.Selected } | ForEach-Object {
                [pscustomobject]@{ Name = $_.Name; Id = $_.Id; Source = $_.Source }
            })
        if ($selected.Count -eq 0) {
            Write-Log 'No hay aplicaciones marcadas. Usa «Buscar actualizaciones» y marca las que quieras instalar.' 'WARN'
            return
        }
        foreach ($row in $script:upgRows) { if ($row.Selected) { $row.Status = 'En cola' } }
        $ui.upgGrid.Items.Refresh()
        Start-Task "Actualizar $($selected.Count) aplicación(es)" 'Install-SelectedUpgrades' @{ Apps = $selected }
    })

$script:driversLoaded = $false

# La lista de controladores se carga al abrir la pestaña por primera vez. SelectionChanged
# burbujea desde controles internos (la lista de controladores), así que se filtra por el origen.
$ui.tabs.Add_SelectionChanged({
        param($s, $e)
        if ($e.OriginalSource -ne $ui.tabs) { return }
        if ($ui.tabs.SelectedItem.Header -eq 'Impresoras' -and -not $script:driversLoaded -and -not $script:task) {
            $script:driversLoaded = $true
            Start-Task 'Leer controladores e impresoras' 'Update-PrinterData'
        }
    })

function Get-PrinterFormError {
    param([string]$PrinterName, [string]$HostName)
    if (-not $PrinterName) { return 'Escribe un nombre para la impresora.' }
    if ($PrinterName -match '[\\,!]') { return 'El nombre no puede llevar \ , ni !.' }
    if (-not $HostName) { return 'Escribe la IP o el nombre de host de la impresora.' }
    if ($HostName -notmatch '^[A-Za-z0-9]([A-Za-z0-9.\-]{0,251}[A-Za-z0-9])?$') { return 'La IP o el host solo puede llevar letras, números, puntos y guiones.' }
    if ($HostName -match '^\d+(\.\d+){3}$' -and -not [System.Net.IPAddress]::TryParse($HostName, [ref]$null)) { return "«$HostName» no es una dirección IP válida." }
    return $null
}

function Set-PrinterFormMessage {
    param([string]$Text)
    $ui.prnResult.Text = $Text
    $ui.prnResult.Foreground = $logBrushes.WARN
    Write-Log $Text 'WARN'
}

$ui.btnNetDiag.Add_Click({ Start-Task 'Diagnosticar red' 'Get-NetworkDiagnosis' })
$ui.btnCopyReport.Add_Click({ Start-Task 'Armar informe para soporte' 'Get-SupportReport' })

$ui.btnDnsApply.Add_Click({
        $provider = $dnsProviders | Where-Object { $ui["dns$($_.Key)"].IsChecked } | Select-Object -First 1
        if (-not $provider) { $provider = $dnsProviders[0] }
        Start-Task "Aplicar DNS ($($provider.Key))" 'Set-DnsPreset' @{ Name = $provider.Key; Servers = [string[]]$provider.Servers }
    })

function Get-SelectedPrinterName {
    $row = $ui.prnList.SelectedItem
    if (-not $row) {
        Write-Log 'Selecciona una impresora de la lista.' 'WARN'
        return $null
    }
    return [string]$row.Name
}

$ui.btnPrnRefresh.Add_Click({ Start-Task 'Leer impresoras' 'Get-InstalledPrinters' })

$ui.btnPrnDefault.Add_Click({
        $name = Get-SelectedPrinterName
        if ($name) { Start-Task "Predeterminada: $name" 'Set-DefaultPrinterByName' @{ Name = $name } }
    })

$ui.btnPrnTestPage.Add_Click({
        $name = Get-SelectedPrinterName
        if ($name) { Start-Task "Página de prueba: $name" 'Send-PrinterTestPage' @{ Name = $name } }
    })

$ui.btnPrnRemove.Add_Click({
        $name = Get-SelectedPrinterName
        if (-not $name) { return }
        $answer = [Windows.MessageBox]::Show($window, "Se quitará la impresora:`n`n$name`n`nSu puerto TCP/IP se conserva. ¿Continuar?",
            'Quitar impresora', 'YesNo', 'Warning', 'No')
        if ($answer -eq 'Yes') { Start-Task "Quitar impresora: $name" 'Remove-PrinterByName' @{ Name = $name } }
    })

$ui.btnPrnClearQueue.Add_Click({
        $answer = [Windows.MessageBox]::Show($window,
            "Se detendrá el Spooler, se borrarán TODOS los trabajos de impresión pendientes y se volverá a iniciar.`n`n¿Continuar?",
            'Limpiar cola de impresión', 'YesNo', 'Warning', 'No')
        if ($answer -eq 'Yes') { Start-Task 'Limpiar cola de impresión a fondo' 'Clear-PrintQueueDeep' }
    })

$ui.btnPrnReload.Add_Click({ Start-Task 'Leer controladores e impresoras' 'Update-PrinterData' })

$ui.btnPrnTest.Add_Click({
        $hostName = $ui.prnIp.Text.Trim()
        $problem = Get-PrinterFormError 'x' $hostName
        if ($problem) { Set-PrinterFormMessage $problem; return }
        Start-Task "Probar $hostName`:9100" 'Test-PrinterConnection' @{ HostName = $hostName }
    })

$ui.btnPrnInstall.Add_Click({
        $printerName = $ui.prnName.Text.Trim()
        $hostName = $ui.prnIp.Text.Trim()
        $problem = Get-PrinterFormError $printerName $hostName
        if (-not $problem -and -not $ui.prnDrivers.SelectedItem) { $problem = 'Elige un controlador de la lista.' }
        if ($problem) { Set-PrinterFormMessage $problem; return }
        Start-Task "Instalar impresora $printerName" 'Install-NetworkPrinter' @{
            Name       = $printerName
            HostName   = $hostName
            Driver     = [string]$ui.prnDrivers.SelectedItem
            SetDefault = [bool]$ui.prnDefault.IsChecked
            TestPage   = [bool]$ui.prnTestPage.IsChecked
        }
    })

$ui.btnWinScan.Add_Click({ Start-Task 'Buscar actualizaciones de Windows' 'Find-WindowsUpdates' })

$ui.btnWinInstall.Add_Click({
        $ids = [string[]]@($script:winRows | Where-Object { $_.Selected } | ForEach-Object { $_.Id })
        if ($ids.Count -eq 0) {
            Write-Log 'No hay actualizaciones de Windows marcadas. Usa «Buscar actualizaciones» y marca las que quieras instalar.' 'WARN'
            return
        }
        foreach ($row in $script:winRows) { if ($row.Selected) { $row.Status = 'En cola' } }
        $ui.winGrid.Items.Refresh()
        Start-Task "Instalar $($ids.Count) actualización(es) de Windows" 'Install-WindowsUpdates' @{ Ids = $ids }
    })

$ui.btnRunUpdater.Add_Click({
        $exe = Join-Path $rootDir 'ActualizarApps\ActualizarApps.exe'
        $ps1 = Join-Path $rootDir 'ActualizarApps\updateScripts.ps1'
        try {
            if (Test-Path $exe) {
                Start-Process -FilePath $exe
            } elseif (Test-Path $ps1) {
                Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ps1`"")
            } else {
                Write-Log "No se encontró ActualizarApps en $rootDir." 'ERROR'
                return
            }
            Write-Log 'ActualizarApps abierto en otra ventana.' 'OK'
        } catch {
            Write-Log "No se pudo abrir ActualizarApps: $($_.Exception.Message)" 'ERROR'
        }
    })

$ui.btnClean.Add_Click({
        $answer = [Windows.MessageBox]::Show($window,
            "Todo el contenido de Escritorio, Descargas y Documentos se moverá a:`n`n$((Get-ProfileFolders).Backup)`n`nNo se borra nada, pero esas carpetas quedarán vacías. ¿Continuar?",
            'Respaldar y limpiar perfil', 'YesNo', 'Warning', 'No')
        if ($answer -eq 'Yes') { Start-Task 'Respaldar y limpiar perfil' 'Backup-UserProfile' }
    })

$ui.btnCopyLog.Add_Click({
        $range = New-Object Windows.Documents.TextRange -ArgumentList $ui.logBox.Document.ContentStart, $ui.logBox.Document.ContentEnd
        if ($range.Text.Trim()) {
            [Windows.Clipboard]::SetText($range.Text)
            if (-not $script:task) { $ui.statusText.Text = 'Consola copiada al portapapeles' }
        }
    })
$ui.btnClearLog.Add_Click({ $ui.logBox.Document.Blocks.Clear() })
$ui.btnToggleLog.Add_Click({ Set-ConsoleCollapsed (-not $script:consoleCollapsed) })

$window.Add_SizeChanged({
        # Tres columnas de tarjetas desde 880 DIPs de ancho; por debajo, dos.
        $columns = if ($window.ActualWidth -lt 880) { 2 } else { 3 }
        if ($ui.servicesGrid.Columns -ne $columns) {
            $ui.servicesGrid.Columns = $columns
            $ui.hwGrid.Columns = $columns
        }
    })

$window.Add_SourceInitialized({
        # Barra de título oscura (DWMWA_USE_IMMERSIVE_DARK_MODE = 20, Windows 10 20H1+).
        try {
            $hwnd = (New-Object Windows.Interop.WindowInteropHelper $window).Handle
            $on = 1
            [void][PanelNative]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4)
        } catch {}
    })

$window.Add_ContentRendered({ Start-Task 'Leer hardware' 'Get-HardwareInfo' })

$window.Add_Closing({
        param($sender, $e)
        if ($script:task) {
            $answer = [Windows.MessageBox]::Show($window,
                "«$($script:task.Title)» sigue en curso y quedaría a medias. ¿Cerrar igual?",
                'Tarea en curso', 'YesNo', 'Warning', 'No')
            if ($answer -ne 'Yes') { $e.Cancel = $true; return }
            [void]$script:task.PS.BeginStop($null, $null)
        }
        $timer.Stop()
    })

$timer.Start()
[void]$window.ShowDialog()
