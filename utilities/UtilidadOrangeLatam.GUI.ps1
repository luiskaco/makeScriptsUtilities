<#
.SYNOPSIS
    Utilidad Orange Latam - Interfaz Gráfica (WPF / PowerShell)
    Herramienta para reinicio rápido de servicios y subsistemas de Windows.
#>

# Resolver ruta base y script de forma segura en .exe o .ps1
$script:appDir = if ($PSScriptRoot) { 
    $PSScriptRoot 
} elseif ($PSCommandPath) { 
    [System.IO.Path]::GetDirectoryName($PSCommandPath) 
} elseif ($MyInvocation.MyCommand.Path) { 
    [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path) 
} else { 
    [System.AppDomain]::CurrentDomain.BaseDirectory.TrimEnd('\')
}

$targetScript = [System.IO.Path]::Combine($script:appDir, "UtilidadOrangeLatam.GUI.ps1")

# Auto-elevación a permisos de Administrador (solo cuando corre directamente como script .ps1 fuera del .exe)
$isExe = [System.AppDomain]::CurrentDomain.FriendlyName -match '\.exe$' -and [System.AppDomain]::CurrentDomain.FriendlyName -notmatch 'powershell'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isExe -and -not $isAdmin -and [System.IO.File]::Exists($targetScript)) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File `"$targetScript`""
        $psi.Verb = "runas"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    } catch {}
}

# Cargar librerías necesarias de WPF
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Orange Latam - Utilidad de Servicios" 
        Height="720" Width="920" 
        MinHeight="620" MinWidth="800"
        WindowStartupLocation="CenterScreen"
        Background="#13141F" 
        Foreground="#CDD6F4"
        FontFamily="Segoe UI">

    <Window.Resources>
        <!-- Estilo de Botón de Acción Principal -->
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#1E1E2E"/>
            <Setter Property="Foreground" Value="#F5F5F7"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="BorderBrush" Value="#2E3048"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,10"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#292A3E"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FF7A00"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#FF7A00"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo de Botón Naranja Destacado -->
        <Style x:Key="AccentButtonStyle" TargetType="Button" BasedOn="{StaticResource ActionButtonStyle}">
            <Setter Property="Background" Value="#CC6200"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#FF7A00"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="8">
                            <ContentPresenter HorizontalAlignment="Left" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#FF7A00"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FFA447"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#E05B00"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Botón Pequeño para Terminal -->
        <Style x:Key="SmallToolButton" TargetType="Button">
            <Setter Property="Background" Value="#1E1E2E"/>
            <Setter Property="Foreground" Value="#A6ADC8"/>
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="BorderBrush" Value="#313244"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,4"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="5">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#313244"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="18">
        <Grid.RowDefinitions>
            <!-- Header -->
            <RowDefinition Height="Auto"/>
            <!-- Content: Actions & Terminal -->
            <RowDefinition Height="*"/>
            <!-- Status Bar -->
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <Border Grid.Row="0" Background="#1A1B28" BorderBrush="#2A2B3D" BorderThickness="1" CornerRadius="10" Padding="18,14" Margin="0,0,0,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#FF7A00" CornerRadius="8" Width="42" Height="42" Margin="0,0,14,0">
                        <TextBlock Text="⚡" FontSize="22" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#FFFFFF"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="ORANGE LATAM • CENTRO DE SERVICIOS" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Herramienta de diagnóstico y reinicio de subsistemas de Windows" FontSize="12" Foreground="#9399B2" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <!-- Admin Status Badge -->
                <Border Grid.Column="1" Background="#142B20" BorderBrush="#27563E" BorderThickness="1" CornerRadius="6" Padding="12,6" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <Ellipse Width="8" Height="8" Fill="#2ECC71" Margin="0,0,8,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Administrador Activo" FontSize="12" FontWeight="SemiBold" Foreground="#2ECC71" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- MAIN CONTENT AREA (Split: Left Actions, Right Console) -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="380" MinWidth="320"/>
                <ColumnDefinition Width="14"/>
                <ColumnDefinition Width="*" MinWidth="340"/>
            </Grid.ColumnDefinitions>

            <!-- ACCIONES / BOTONES -->
            <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <StackPanel Margin="0,0,4,0">
                    <TextBlock Text="ACCIONES RÁPIDAS" FontSize="11" FontWeight="Bold" Foreground="#7F849C" Margin="2,0,0,8"/>

                    <!-- 1. Explorador de Windows -->
                    <Button x:Name="btnExplorer" Style="{StaticResource ActionButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="📁" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Reiniciar Explorador de Windows" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Recarga explorer.exe, barra de tareas y escritorio" FontSize="11" Foreground="#9399B2" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>

                    <!-- 2. Red y Wi-Fi -->
                    <Button x:Name="btnNetwork" Style="{StaticResource ActionButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="📶" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Reiniciar Wi-Fi y Red" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Reinicia adaptador, vacía DNS (flush) y renueva IP" FontSize="11" Foreground="#9399B2" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>

                    <!-- 3. Cola de Impresión -->
                    <Button x:Name="btnSpooler" Style="{StaticResource ActionButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="🖨️" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Reiniciar Cola de Impresión" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Reinicia el servicio Spooler para destrabar impresoras" FontSize="11" Foreground="#9399B2" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>

                    <!-- 4. Servicio de Audio -->
                    <Button x:Name="btnAudio" Style="{StaticResource ActionButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="🔊" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Reiniciar Servicio de Audio" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Reinicia Audiosrv y AudioEndpointBuilder" FontSize="11" Foreground="#9399B2" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>

                    <!-- 5. Windows Update -->
                    <Button x:Name="btnUpdate" Style="{StaticResource ActionButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="🔄" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Reiniciar Windows Update" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Reinicia el servicio wuauserv de actualizaciones" FontSize="11" Foreground="#9399B2" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>

                    <Separator Background="#2A2B3D" Margin="0,4,0,12"/>

                    <!-- 6. Ejecutar Mantenimiento Completo -->
                    <Button x:Name="btnAll" Style="{StaticResource AccentButtonStyle}" Margin="0,0,0,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="🚀" FontSize="20" Margin="0,0,12,0" VerticalAlignment="Center"/>
                            <StackPanel>
                                <TextBlock Text="Ejecutar Mantenimiento General" FontWeight="Bold" FontSize="13"/>
                                <TextBlock Text="Aplica todos los reinicios de servicios secuencialmente" FontSize="11" Foreground="#FFE1C6" Margin="0,2,0,0"/>
                            </StackPanel>
                        </StackPanel>
                    </Button>
                </StackPanel>
            </ScrollViewer>

            <!-- SPLITTER VISUAL -->
            <GridSplitter Grid.Column="1" HorizontalAlignment="Stretch" Background="Transparent"/>

            <!-- CONSOLA / LOGS TERMINAL -->
            <Border Grid.Column="2" Background="#0C0D14" BorderBrush="#252636" BorderThickness="1" CornerRadius="10" Padding="14">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>

                    <!-- Header de Consola -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="📟" FontSize="14" Margin="0,0,6,0" VerticalAlignment="Center"/>
                            <TextBlock Text="REGISTRO DE EJECUCIÓN" FontSize="12" FontWeight="Bold" Foreground="#A6ADC8" VerticalAlignment="Center"/>
                        </StackPanel>

                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="btnCopyLog" Content="Copiar" Style="{StaticResource SmallToolButton}" Margin="0,0,6,0"/>
                            <Button x:Name="btnClearLog" Content="Limpiar" Style="{StaticResource SmallToolButton}"/>
                        </StackPanel>
                    </Grid>

                    <!-- Text Area de la Consola -->
                    <TextBox x:Name="txtLogs" Grid.Row="1"
                             Background="#08080D" 
                             Foreground="#A6E3A1" 
                             CaretBrush="#FF7A00"
                             FontFamily="Consolas, 'Cascadia Code', 'Lucida Console', Courier New"
                             FontSize="12"
                             FontWeight="Regular"
                             IsReadOnly="True"
                             TextWrapping="Wrap"
                             VerticalScrollBarVisibility="Auto"
                             HorizontalScrollBarVisibility="Auto"
                             BorderBrush="#1B1C28"
                             BorderThickness="1"
                             Padding="10"/>
                </Grid>
            </Border>
        </Grid>

        <!-- STATUS BAR (BOTTOM) -->
        <Border Grid.Row="2" Background="#161724" BorderBrush="#232435" BorderThickness="1" CornerRadius="6" Padding="12,8" Margin="0,12,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatusIcon" Text="●" Foreground="#2ECC71" FontSize="12" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="txtStatusMessage" Text="Sistema listo para operar." FontSize="12" Foreground="#A6ADC8" VerticalAlignment="Center"/>
                </StackPanel>

                <TextBlock Grid.Column="1" Text="v1.0.0 • Orange Latam" FontSize="11" Foreground="#585B70" VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Leer y cargar XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Mapear controles del XAML
$btnExplorer     = $window.FindName("btnExplorer")
$btnNetwork      = $window.FindName("btnNetwork")
$btnSpooler      = $window.FindName("btnSpooler")
$btnAudio        = $window.FindName("btnAudio")
$btnUpdate       = $window.FindName("btnUpdate")
$btnAll          = $window.FindName("btnAll")
$btnClearLog     = $window.FindName("btnClearLog")
$btnCopyLog      = $window.FindName("btnCopyLog")
$txtLogs         = $window.FindName("txtLogs")
$txtStatusIcon   = $window.FindName("txtStatusIcon")
$txtStatusMessage= $window.FindName("txtStatusMessage")

# Función para forzar refresco del UI en tiempo real
function Update-Gui {
    try {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [Action]{},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    } catch {}
}

# Función para escribir mensajes en la consola WPF
function Write-GuiLog {
    param(
        [string]$Message,
        [string]$Type = "INFO" # INFO, SUCCESS, WARN, ERROR
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $prefix = switch ($Type) {
        "SUCCESS" { "[✓ OK]" }
        "WARN"    { "[! ADVERTENCIA]" }
        "ERROR"   { "[✕ ERROR]" }
        default   { "[i INFO]" }
    }

    $formattedLine = "[$timestamp] $prefix $Message"

    $txtLogs.AppendText("$formattedLine`r`n")
    $txtLogs.ScrollToEnd()
    Update-Gui
}

# Función para actualizar la barra de estado
function Set-GuiStatus {
    param(
        [string]$Message,
        [string]$State = "READY" # READY, BUSY, ERROR, DONE
    )

    switch ($State) {
        "BUSY" {
            $txtStatusIcon.Foreground = [System.Windows.Media.Brushes]::Orange
            $txtStatusIcon.Text = "◌"
        }
        "ERROR" {
            $txtStatusIcon.Foreground = [System.Windows.Media.Brushes]::Crimson
            $txtStatusIcon.Text = "●"
        }
        "DONE" {
            $txtStatusIcon.Foreground = [System.Windows.Media.Brushes]::MediumSeaGreen
            $txtStatusIcon.Text = "✓"
        }
        default {
            $txtStatusIcon.Foreground = [System.Windows.Media.Brushes]::LimeGreen
            $txtStatusIcon.Text = "●"
        }
    }
    $txtStatusMessage.Text = $Message
    Update-Gui
}

# Función para bloquear/desbloquear botones durante tareas
function Set-ControlsEnabled {
    param([bool]$Enabled)
    $btnExplorer.IsEnabled = $Enabled
    $btnNetwork.IsEnabled  = $Enabled
    $btnSpooler.IsEnabled  = $Enabled
    $btnAudio.IsEnabled    = $Enabled
    $btnUpdate.IsEnabled   = $Enabled
    $btnAll.IsEnabled      = $Enabled
    Update-Gui
}

# Ejecutor de tareas en tiempo real
function Invoke-ServiceTask {
    param(
        [string]$TaskName,
        [scriptblock]$ActionBlock
    )

    Set-ControlsEnabled $false
    Set-GuiStatus "Ejecutando: $TaskName..." "BUSY"
    Write-GuiLog "Iniciando tarea: $TaskName" "INFO"

    try {
        & $ActionBlock
        Write-GuiLog "Tarea '$TaskName' completada correctamente." "SUCCESS"
        Set-GuiStatus "Listo - Última acción: $TaskName exitosa." "DONE"
    }
    catch {
        Write-GuiLog "Error en '$TaskName': $_" "ERROR"
        Set-GuiStatus "Error al ejecutar $TaskName." "ERROR"
    }
    finally {
        Set-ControlsEnabled $true
        Update-Gui
    }
}

# --- ACCIONES DE REINICIO ---

# 1. Explorador de Windows
$btnExplorer.Add_Click({
    Invoke-ServiceTask "Reinicio de Explorador" {
        Write-GuiLog "Cerrando proceso explorer.exe..." "INFO"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        Write-GuiLog "Iniciando nuevo proceso explorer.exe..." "INFO"
        Start-Process "explorer.exe"
    }
})

# 2. Red y Wi-Fi
$btnNetwork.Add_Click({
    Invoke-ServiceTask "Reinicio de Red y Wi-Fi" {
        Write-GuiLog "Deshabilitando interfaz Wi-Fi..." "INFO"
        & netsh interface set interface name="Wi-Fi" admin=disable | Out-Null
        Start-Sleep -Seconds 2
        
        Write-GuiLog "Habilitando interfaz Wi-Fi..." "INFO"
        & netsh interface set interface name="Wi-Fi" admin=enable | Out-Null
        
        Write-GuiLog "Vaciando caché de resolución DNS (FlushDNS)..." "INFO"
        & ipconfig /flushdns | Out-Null
        
        Write-GuiLog "Esperando reconexión a la red..." "INFO"
        Start-Sleep -Seconds 3
        
        Write-GuiLog "Renovando configuración IP (DHCP)..." "INFO"
        & ipconfig /renew | Out-Null
    }
})

# 3. Cola de Impresión
$btnSpooler.Add_Click({
    Invoke-ServiceTask "Reinicio de Cola de Impresión" {
        Write-GuiLog "Deteniendo servicio Spooler..." "INFO"
        & net stop Spooler 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
        Write-GuiLog "Iniciando servicio Spooler..." "INFO"
        & net start Spooler 2>&1 | Out-Null
    }
})

# 4. Servicios de Audio
$btnAudio.Add_Click({
    Invoke-ServiceTask "Reinicio de Servicios de Audio" {
        Write-GuiLog "Deteniendo servicio Audiosrv..." "INFO"
        & net stop Audiosrv /y 2>&1 | Out-Null
        
        Write-GuiLog "Deteniendo servicio AudioEndpointBuilder..." "INFO"
        & net stop AudioEndpointBuilder /y 2>&1 | Out-Null
        
        Start-Sleep -Milliseconds 500
        
        Write-GuiLog "Iniciando AudioEndpointBuilder..." "INFO"
        & net start AudioEndpointBuilder 2>&1 | Out-Null
        
        Write-GuiLog "Iniciando Audiosrv..." "INFO"
        & net start Audiosrv 2>&1 | Out-Null
    }
})

# 5. Windows Update
$btnUpdate.Add_Click({
    Invoke-ServiceTask "Reinicio de Windows Update" {
        Write-GuiLog "Deteniendo servicio wuauserv..." "INFO"
        & net stop wuauserv 2>&1 | Out-Null
        Start-Sleep -Milliseconds 500
        Write-GuiLog "Iniciando servicio wuauserv..." "INFO"
        & net start wuauserv 2>&1 | Out-Null
    }
})

# 6. Mantenimiento Completo
$btnAll.Add_Click({
    Invoke-ServiceTask "Mantenimiento General de Servicios" {
        Write-GuiLog "=== INICIANDO SECUENCIA COMPLETA DE REINICIO ===" "INFO"

        # 1. Cola de impresión
        Write-GuiLog "[1/5] Reiniciando Cola de Impresión..." "INFO"
        & net stop Spooler 2>&1 | Out-Null
        & net start Spooler 2>&1 | Out-Null

        # 2. Audio
        Write-GuiLog "[2/5] Reiniciando Servicios de Audio..." "INFO"
        & net stop Audiosrv /y 2>&1 | Out-Null
        & net stop AudioEndpointBuilder /y 2>&1 | Out-Null
        & net start AudioEndpointBuilder 2>&1 | Out-Null
        & net start Audiosrv 2>&1 | Out-Null

        # 3. Windows Update
        Write-GuiLog "[3/5] Reiniciando Windows Update..." "INFO"
        & net stop wuauserv 2>&1 | Out-Null
        & net start wuauserv 2>&1 | Out-Null

        # 4. Red
        Write-GuiLog "[4/5] Vaciando caché DNS y renovando IP..." "INFO"
        & netsh interface set interface name="Wi-Fi" admin=disable 2>&1 | Out-Null
        Start-Sleep -Seconds 2
        & netsh interface set interface name="Wi-Fi" admin=enable 2>&1 | Out-Null
        & ipconfig /flushdns | Out-Null
        Start-Sleep -Seconds 2
        & ipconfig /renew | Out-Null

        # 5. Explorer
        Write-GuiLog "[5/5] Reiniciando Explorador de Windows..." "INFO"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        Start-Process "explorer.exe"

        Write-GuiLog "=== MANTENIMIENTO COMPLETO FINALIZADO CON ÉXITO ===" "SUCCESS"
    }
})

# Botones de la Consola
$btnClearLog.Add_Click({
    $txtLogs.Clear()
    Write-GuiLog "Consola limpiada." "INFO"
})

$btnCopyLog.Add_Click({
    if (-not [string]::IsNullOrWhiteSpace($txtLogs.Text)) {
        [System.Windows.Clipboard]::SetText($txtLogs.Text)
        Write-GuiLog "Contenido de la consola copiado al portapapeles." "SUCCESS"
    }
})

# Inicialización al mostrar la ventana
$window.Add_Loaded({
    Write-GuiLog "Utilidad Orange Latam iniciada con éxito." "SUCCESS"
    Write-GuiLog "Permisos de Administrador verificados." "INFO"
})

# Salida limpia al cerrar
$window.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
        $window.Close()
    }
})

$window.Add_Closed({
    [System.Environment]::Exit(0)
})

# Mostrar ventana WPF
$window.ShowDialog() | Out-Null
[System.Environment]::Exit(0)
