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
        try { $proc.Kill() } catch {}
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
    'Find-PendingUpgrades', 'Get-HardwareInfo', 'Restart-ExplorerShell', 'Reset-Network',
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
    New-ActionCardXaml 'btnExplorer' '&#xE8B7;' '3498DB' 'Explorador de Windows' 'Reinicia el shell para refrescar la barra de tareas, el escritorio y el explorador de archivos.' 'Reiniciar'
    New-ActionCardXaml 'btnNetwork' '&#xE701;' '1ABC9C' 'Red y Wi-Fi' 'Reinicia los adaptadores conectados, vacía la caché DNS y pide una IP nueva por DHCP.' 'Restablecer'
    New-ActionCardXaml 'btnSpooler' '&#xE749;' 'F39C12' 'Cola de impresión' 'Reinicia el servicio Spooler para desbloquear trabajos de impresión atascados.' 'Reiniciar'
    New-ActionCardXaml 'btnAudio' '&#xE767;' '9B59B6' 'Servicios de audio' 'Reinicia Audiosrv y AudioEndpointBuilder si el sonido se corta o no aparecen salidas.' 'Reiniciar'
    New-ActionCardXaml 'btnUpdate' '&#xE895;' '2ECC71' 'Windows Update' 'Reinicia el servicio de actualizaciones cuando una descarga o un análisis se queda colgado.' 'Reiniciar'
    New-ActionCardXaml 'btnAll' '&#xE90F;' 'FF7A00' 'Mantenimiento completo' 'Ejecuta todo lo anterior en secuencia. Si un paso falla, sigue con el siguiente.' 'Ejecutar todo' 'AccentButton'
) -join "`n"

$infoCards = @(
    New-InfoCardXaml 'Cpu' 'PROCESADOR'
    New-InfoCardXaml 'Gpu' 'TARJETA GRÁFICA'
    New-InfoCardXaml 'Ram' 'MEMORIA RAM'
    New-InfoCardXaml 'Disk' 'DISCO DEL SISTEMA'
    New-InfoCardXaml 'Os' 'SISTEMA OPERATIVO'
    New-InfoCardXaml 'Pc' 'EQUIPO'
) -join "`n"

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
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#FF9433"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource BaseButton}"/>
    <Style x:Key="AccentButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
      <Setter Property="Background" Value="#FF7A00"/>
      <Setter Property="BorderBrush" Value="#FF7A00"/>
      <Setter Property="Foreground" Value="#14100A"/>
    </Style>
    <Style x:Key="DangerButton" TargetType="Button" BasedOn="{StaticResource BaseButton}">
      <Setter Property="Background" Value="#C0392B"/>
      <Setter Property="BorderBrush" Value="#C0392B"/>
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
      <Setter Property="Foreground" Value="#FF9433"/>
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
              <Border x:Name="line" Height="2" VerticalAlignment="Bottom" Background="#FF7A00" CornerRadius="1" Visibility="Hidden"/>
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
      <RowDefinition x:Name="consoleRow" Height="170" MinHeight="90"/>
    </Grid.RowDefinitions>

    <DockPanel Grid.Row="0" Margin="24,12,24,8">
      <Border DockPanel.Dock="Right" x:Name="adminBadge" CornerRadius="12" Padding="12,5" VerticalAlignment="Center" Background="#262ECC71">
        <TextBlock x:Name="adminText" FontSize="12" FontWeight="SemiBold" Foreground="#2ECC71"/>
      </Border>
      <StackPanel Orientation="Horizontal">
        <Border Width="34" Height="34" CornerRadius="9" Background="#FF7A00">
          <TextBlock Text="OL" FontSize="14" FontWeight="Bold" Foreground="#14100A" HorizontalAlignment="Center" VerticalAlignment="Center"/>
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
              <Button x:Name="btnRefreshHw" DockPanel.Dock="Right" Content="Volver a leer" Style="{StaticResource SecondaryButton}" VerticalAlignment="Center"/>
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
              <Button x:Name="btnRunUpdater" Content="Actualizar todo" Style="{StaticResource AccentButton}"/>
            </StackPanel>
            <StackPanel>
              <TextBlock Text="Actualizaciones de software" Style="{StaticResource SectionTitle}"/>
              <TextBlock Text="«Actualizar todo» abre ActualizarApps en su propia ventana, con log, límite de tiempo por app y revisión de navegadores y driver NVIDIA." Style="{StaticResource SectionText}"/>
            </StackPanel>
          </DockPanel>
          <TextBlock x:Name="upgSummary" DockPanel.Dock="Top" Margin="0,0,0,10" Text="Usa «Buscar actualizaciones» para ver qué aplicaciones tienen versión nueva."/>
          <DataGrid x:Name="upgGrid" AutoGenerateColumns="False" IsReadOnly="True" HeadersVisibility="Column"
                    GridLinesVisibility="Horizontal" HorizontalGridLinesBrush="#22253A" CanUserAddRows="False"
                    SelectionMode="Single" RowHeight="30" Background="#171824" RowBackground="#171824"
                    AlternatingRowBackground="#1A1B28" Foreground="#C5C9DB" BorderBrush="#22253A" BorderThickness="1">
            <DataGrid.ColumnHeaderStyle>
              <Style TargetType="DataGridColumnHeader">
                <Setter Property="Background" Value="#11121A"/>
                <Setter Property="Foreground" Value="#7E849E"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
                <Setter Property="Padding" Value="10,8"/>
                <Setter Property="BorderBrush" Value="#22253A"/>
                <Setter Property="BorderThickness" Value="0,0,0,1"/>
              </Style>
            </DataGrid.ColumnHeaderStyle>
            <DataGrid.CellStyle>
              <Style TargetType="DataGridCell">
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
                    <Setter Property="Background" Value="#33FF7A00"/>
                    <Setter Property="Foreground" Value="#FFFFFF"/>
                  </Trigger>
                </Style.Triggers>
              </Style>
            </DataGrid.CellStyle>
            <DataGrid.Columns>
              <DataGridTextColumn Header="Aplicación" Binding="{Binding Name}" Width="2*"/>
              <DataGridTextColumn Header="Id" Binding="{Binding Id}" Width="2*"/>
              <DataGridTextColumn Header="Instalada" Binding="{Binding Version}" Width="*"/>
              <DataGridTextColumn Header="Disponible" Binding="{Binding Available}" Width="*"/>
              <DataGridTextColumn Header="Origen" Binding="{Binding Source}" Width="0.7*"/>
            </DataGrid.Columns>
          </DataGrid>
        </DockPanel>
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
                     Visibility="Hidden" Foreground="#FF7A00" Background="Transparent" BorderThickness="0"/>
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
        'btnScan', 'btnRunUpdater', 'upgSummary', 'upgGrid', 'btnClean', 'cleanTarget')) {
    $ui[$name] = $window.FindName($name)
}
$hwKeys = @('Cpu', 'Gpu', 'Ram', 'Disk', 'Os', 'Pc')
foreach ($k in $hwKeys) {
    $ui["hw${k}Main"] = $window.FindName("hw${k}Main")
    $ui["hw${k}Detail"] = $window.FindName("hw${k}Detail")
}
$actionButtons = @('btnExplorer', 'btnNetwork', 'btnSpooler', 'btnAudio', 'btnUpdate', 'btnAll',
    'btnRefreshHw', 'btnScan', 'btnRunUpdater', 'btnClean') | ForEach-Object { $ui[$_] }

$brushConverter = New-Object Windows.Media.BrushConverter
$logBrushes = @{}
foreach ($pair in @(@('INFO', '#C5C9DB'), @('OK', '#2ECC71'), @('WARN', '#F39C12'), @('ERROR', '#E74C3C'), @('STEP', '#FF9433'), @('TIME', '#4E5369'))) {
    $logBrushes[$pair[0]] = $brushConverter.ConvertFromString($pair[1])
}

if ($isAdmin) {
    $ui.adminText.Text = 'Administrador'
} else {
    $ui.adminText.Text = 'Sin permisos de administrador'
    $ui.adminText.Foreground = $logBrushes.WARN
    $ui.adminBadge.Background = $brushConverter.ConvertFromString('#26F39C12')
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
            $apps = @($Item.Value)
            $ui.upgGrid.ItemsSource = $apps
            $ui.upgSummary.Text = if ($apps.Count) { "$($apps.Count) aplicación(es) con versión nueva. «Actualizar todo» las instala." } else { 'Todo al día: winget no encontró actualizaciones.' }
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
    param([string]$Title, [string]$Command)
    if ($script:task) { return }
    $ps = [powershell]::Create($iss)
    [void]$ps.AddCommand($Command)
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
