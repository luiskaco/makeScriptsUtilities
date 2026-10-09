<#
.SYNOPSIS
    Asistencia Orange — Portal de Auto-Atención y Diagnóstico (WPF Nativo)
    Aplicación nativa de escritorio para auto-reparación rápida de Windows,
    soporte TI, optimización y telemetría de hardware en un solo clic.
#>

[CmdletBinding()]
param()

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

$targetScript = [System.IO.Path]::Combine($script:appDir, "AsistenciaOrange.ps1")

# Auto-elevación segura a Administrador (solo cuando corre directamente como script .ps1 fuera del .exe)
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
    } catch {
        # Si el usuario cancela la elevación, continuar en modo estándar
    }
}

# Cargar librerías necesarias de WPF y Windows Forms
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing, System.Windows.Forms

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Asistencia Orange — Auto-Reparación y Diagnóstico" 
        Height="860" Width="1060" 
        MinHeight="740" MinWidth="920"
        WindowStartupLocation="CenterScreen"
        Background="#0B0C15" 
        Foreground="#F1F5F9"
        FontFamily="Segoe UI, Segoe UI Variable, Microsoft YaHei, Arial">

    <Window.Resources>
        <!-- Estilo de Tarjetas de Síntomas con Micro-interacción y Elevación -->
        <Style x:Key="SymptomTileStyle" TargetType="Button">
            <Setter Property="Background" Value="#131522"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#22263B"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="12"
                                RenderTransformOrigin="0.5,0.5">
                            <Border.RenderTransform>
                                <ScaleTransform ScaleX="1.0" ScaleY="1.0"/>
                            </Border.RenderTransform>
                            <ContentPresenter Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1A1E31"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FF7A00"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="1.02" ScaleY="1.02"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#FF7A00" BlurRadius="14" Direction="270" ShadowDepth="1" Opacity="0.4"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#261C14"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FFA347"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.98" ScaleY="0.98"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo de Botón Hero Naranja con Resplandor Vibrante -->
        <Style x:Key="HeroButtonStyle" TargetType="Button">
            <Setter Property="Background">
                <Setter.Value>
                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                        <GradientStop Color="#FF8800" Offset="0"/>
                        <GradientStop Color="#FF6200" Offset="1"/>
                    </LinearGradientBrush>
                </Setter.Value>
            </Setter>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#FFA347"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="24,14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="10"
                                RenderTransformOrigin="0.5,0.5">
                            <Border.RenderTransform>
                                <ScaleTransform ScaleX="1.0" ScaleY="1.0"/>
                            </Border.RenderTransform>
                            <Border.Effect>
                                <DropShadowEffect Color="#FF7A00" BlurRadius="12" Direction="270" ShadowDepth="2" Opacity="0.45"/>
                            </Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background">
                                    <Setter.Value>
                                        <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                            <GradientStop Color="#FFA033" Offset="0"/>
                                            <GradientStop Color="#FF7500" Offset="1"/>
                                        </LinearGradientBrush>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FFD180"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="1.03" ScaleY="1.03"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#FF7A00" BlurRadius="20" Direction="270" ShadowDepth="2" Opacity="0.75"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#D95300"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.97" ScaleY="0.97"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#FF7A00" BlurRadius="6" Direction="270" ShadowDepth="1" Opacity="0.2"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo de Botón Píldora Secundario -->
        <Style x:Key="PillButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#1E2235"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="BorderBrush" Value="#2E344E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="14,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="20"
                                RenderTransformOrigin="0.5,0.5">
                            <Border.RenderTransform>
                                <ScaleTransform ScaleX="1.0" ScaleY="1.0"/>
                            </Border.RenderTransform>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#282E47"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#818CF8"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="1.04" ScaleY="1.04"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#6366F1" BlurRadius="10" Direction="270" ShadowDepth="1" Opacity="0.35"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#171A29"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.96" ScaleY="0.96"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo Botón Verde Sí con Tactilidad -->
        <Style x:Key="PillYesStyle" TargetType="Button">
            <Setter Property="Background" Value="#133824"/>
            <Setter Property="Foreground" Value="#4ADE80"/>
            <Setter Property="BorderBrush" Value="#22C55E"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="20"
                                RenderTransformOrigin="0.5,0.5">
                            <Border.RenderTransform>
                                <ScaleTransform ScaleX="1.0" ScaleY="1.0"/>
                            </Border.RenderTransform>
                            <Border.Effect>
                                <DropShadowEffect Color="#22C55E" BlurRadius="8" Direction="270" ShadowDepth="1" Opacity="0.25"/>
                            </Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1C5234"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#86EFAC"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="1.04" ScaleY="1.04"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#22C55E" BlurRadius="14" Direction="270" ShadowDepth="1" Opacity="0.6"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#0F2B1C"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.96" ScaleY="0.96"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo Botón Rojo No con Tactilidad -->
        <Style x:Key="PillNoStyle" TargetType="Button">
            <Setter Property="Background" Value="#38181A"/>
            <Setter Property="Foreground" Value="#F87171"/>
            <Setter Property="BorderBrush" Value="#EF4444"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" 
                                Background="{TemplateBinding Background}" 
                                BorderBrush="{TemplateBinding BorderBrush}" 
                                BorderThickness="{TemplateBinding BorderThickness}" 
                                CornerRadius="20"
                                RenderTransformOrigin="0.5,0.5">
                            <Border.RenderTransform>
                                <ScaleTransform ScaleX="1.0" ScaleY="1.0"/>
                            </Border.RenderTransform>
                            <Border.Effect>
                                <DropShadowEffect Color="#EF4444" BlurRadius="8" Direction="270" ShadowDepth="1" Opacity="0.25"/>
                            </Border.Effect>
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#522327"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FCA5A5"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="1.04" ScaleY="1.04"/>
                                    </Setter.Value>
                                </Setter>
                                <Setter TargetName="border" Property="Effect">
                                    <Setter.Value>
                                        <DropShadowEffect Color="#EF4444" BlurRadius="14" Direction="270" ShadowDepth="1" Opacity="0.6"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#291214"/>
                                <Setter TargetName="border" Property="RenderTransform">
                                    <Setter.Value>
                                        <ScaleTransform ScaleX="0.96" ScaleY="0.96"/>
                                    </Setter.Value>
                                </Setter>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo ProgressBar Naranja Pulido -->
        <Style x:Key="OrangeProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Height" Value="9"/>
            <Setter Property="Background" Value="#1A1C2C"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid x:Name="TemplateRoot">
                            <Border CornerRadius="4.5" Background="{TemplateBinding Background}"/>
                            <Border x:Name="PART_Track" CornerRadius="4.5"/>
                            <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="4.5">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                        <GradientStop Color="#FF6200" Offset="0"/>
                                        <GradientStop Color="#FF8C00" Offset="0.5"/>
                                        <GradientStop Color="#FFD180" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                                <Border.Effect>
                                    <DropShadowEffect Color="#FF7A00" BlurRadius="8" Direction="270" ShadowDepth="0" Opacity="0.5"/>
                                </Border.Effect>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="22">
        <Grid.RowDefinitions>
            <!-- Header -->
            <RowDefinition Height="Auto"/>
            <!-- Main Scrollable Area -->
            <RowDefinition Height="*"/>
            <!-- Status Bar Footer -->
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- 1. HEADER PRINCIPAL CON GLASS-EFFECT Y CONTROL DE VENTANA -->
        <Border x:Name="headerBorder" Grid.Row="0" Background="#121422" BorderBrush="#202438" BorderThickness="1" CornerRadius="14" Padding="18,12" Margin="0,0,0,16" Cursor="Arrow">
            <Border.Effect>
                <DropShadowEffect Color="#000000" BlurRadius="12" Direction="270" ShadowDepth="2" Opacity="0.35"/>
            </Border.Effect>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border CornerRadius="10" Width="42" Height="42" Margin="0,0,14,0">
                        <Border.Background>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                                <GradientStop Color="#FF8800" Offset="0"/>
                                <GradientStop Color="#FF5500" Offset="1"/>
                            </LinearGradientBrush>
                        </Border.Background>
                        <Border.Effect>
                            <DropShadowEffect Color="#FF7A00" BlurRadius="10" Direction="270" ShadowDepth="1" Opacity="0.5"/>
                        </Border.Effect>
                        <TextBlock Text="⚡" FontSize="22" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#FFFFFF"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Asistencia Orange" FontSize="19" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Portal de auto-reparación, diagnóstico y soporte TI rápido" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <!-- Acciones del Header: Estado y Botones de Ventana -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#102B1F" BorderBrush="#1C5B3D" BorderThickness="1" CornerRadius="20" Padding="12,6" Margin="0,0,12,0" ToolTip="La aplicación está ejecutándose con privilegios administrativos">
                        <StackPanel Orientation="Horizontal">
                            <Ellipse Width="8" Height="8" Fill="#22C55E" Margin="0,0,8,0" VerticalAlignment="Center"/>
                            <TextBlock Text="Administrador Activo" FontSize="12" FontWeight="SemiBold" Foreground="#4ADE80" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                    <Button x:Name="btnHeaderMin" Content="—" Style="{StaticResource PillButtonStyle}" Padding="10,4" FontSize="11" Margin="0,0,6,0" Cursor="Hand" ToolTip="Minimizar ventana"/>
                    <Button x:Name="btnHeaderMax" Content="□" Style="{StaticResource PillButtonStyle}" Padding="10,4" FontSize="11" Margin="0,0,6,0" Cursor="Hand" ToolTip="Maximizar / Restaurar"/>
                    <Button x:Name="btnHeaderClose" Content="✕ Salir" Style="{StaticResource PillNoStyle}" Padding="12,5" FontSize="11" FontWeight="Bold" Cursor="Hand" ToolTip="Cerrar Asistencia Orange (Tecla Esc)"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- 2. CONTENIDO PRINCIPAL CON SCROLL -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel Margin="0,0,6,0">

                <!-- 2.1 TELEMETRÍA RÁPIDA DEL EQUIPO CON CHIPS ESTILIZADOS -->
                <Grid Margin="0,0,0,14">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="8"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="8"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="8"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Chip 1: Host -->
                    <Border Grid.Column="0" Background="#0F111D" BorderBrush="#1C2032" BorderThickness="1" CornerRadius="8" Padding="12,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="💻 " FontSize="12" VerticalAlignment="Center"/>
                            <TextBlock Text="Equipo: " Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock x:Name="lblHostName" Text="Cargando..." FontWeight="SemiBold" Foreground="#E2E8F0" FontSize="11" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>

                    <!-- Chip 2: Usuario -->
                    <Border Grid.Column="2" Background="#0F111D" BorderBrush="#1C2032" BorderThickness="1" CornerRadius="8" Padding="12,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="👤 " FontSize="12" VerticalAlignment="Center"/>
                            <TextBlock Text="Usuario: " Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock x:Name="lblUserName" Text="Cargando..." FontWeight="SemiBold" Foreground="#E2E8F0" FontSize="11" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>

                    <!-- Chip 3: IP -->
                    <Border Grid.Column="4" Background="#0F111D" BorderBrush="#1C2032" BorderThickness="1" CornerRadius="8" Padding="12,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="🌐 " FontSize="12" VerticalAlignment="Center"/>
                            <TextBlock Text="IP: " Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock x:Name="lblIpAddress" Text="Detectando..." FontWeight="SemiBold" Foreground="#38BDF8" FontSize="11" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>

                    <!-- Chip 4: RAM -->
                    <Border Grid.Column="6" Background="#0F111D" BorderBrush="#1C2032" BorderThickness="1" CornerRadius="8" Padding="12,8">
                        <StackPanel Orientation="Horizontal">
                            <TextBlock Text="⚡ " FontSize="12" VerticalAlignment="Center"/>
                            <TextBlock Text="RAM: " Foreground="#64748B" FontSize="11" VerticalAlignment="Center"/>
                            <TextBlock x:Name="lblRamTotal" Text="Detectando..." FontWeight="SemiBold" Foreground="#A78BFA" FontSize="11" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>
                </Grid>

                <!-- 2.2 HERO CARD 1-CLICK -->
                <Border Background="#151726" BorderBrush="#FF7A00" BorderThickness="1.5" CornerRadius="14" Padding="22,18" Margin="0,0,0,14">
                    <Border.Effect>
                        <DropShadowEffect Color="#FF7A00" BlurRadius="12" Direction="270" ShadowDepth="1" Opacity="0.2"/>
                    </Border.Effect>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                            <TextBlock Text="¿Algo no funciona correctamente?" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock Text="Soluciona audio, fallas de internet/Teams, cola de impresión y ventanas congeladas en un solo clic." FontSize="13" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,4,0,0"/>
                        </StackPanel>

                        <Button x:Name="btnHeroRepairAll" Grid.Column="1" Style="{StaticResource HeroButtonStyle}" ToolTip="Ejecuta diagnósticos automáticos y restablece servicios clave de Windows en secuencia">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="⚡" FontSize="18" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Reparar Todo el Equipo" FontSize="14" FontWeight="Bold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Border>

                <!-- 2.3 BARRA DE PROGRESO Y SEGUIMIENTO EN TIEMPO REAL -->
                <Border x:Name="panelProgress" Visibility="Collapsed" Background="#181524" BorderBrush="#FF7A00" BorderThickness="1.5" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
                    <Border.Effect>
                        <DropShadowEffect Color="#FF7A00" BlurRadius="14" Direction="270" ShadowDepth="1" Opacity="0.3"/>
                    </Border.Effect>
                    <StackPanel>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Border Background="#3A1E0E" BorderBrush="#FF7A00" BorderThickness="1" CornerRadius="6" Padding="8,3" Margin="0,0,10,0">
                                    <TextBlock x:Name="txtStepBadge" Text="Paso 1 de 4" FontSize="11" FontWeight="Bold" Foreground="#FFA347"/>
                                </Border>
                                <TextBlock x:Name="txtActionTitle" Text="Ejecutando acción..." FontSize="14" FontWeight="Bold" Foreground="#FFFFFF" VerticalAlignment="Center"/>
                            </StackPanel>

                            <TextBlock x:Name="txtProgressPercent" Grid.Column="1" Text="25%" FontSize="16" FontWeight="Bold" Foreground="#FFA347" FontFamily="Consolas, monospace" VerticalAlignment="Center"/>
                        </Grid>

                        <TextBlock x:Name="txtStepDescription" Text="Aplicando ajustes en Windows..." FontSize="12" Foreground="#CBD5E1" Margin="0,0,0,8"/>
                        <ProgressBar x:Name="progressBarAction" Style="{StaticResource OrangeProgressBarStyle}" Value="25" Maximum="100"/>
                    </StackPanel>
                </Border>

                <!-- 2.4 BANNER DE RESULTADO Y FEEDBACK -->
                <Border x:Name="panelResult" Visibility="Collapsed" Background="#121D1D" BorderBrush="#22C55E" BorderThickness="1.5" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
                    <Border.Effect>
                        <DropShadowEffect Color="#22C55E" BlurRadius="12" Direction="270" ShadowDepth="1" Opacity="0.3"/>
                    </Border.Effect>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <TextBlock x:Name="txtResultIcon" Text="🎉" FontSize="26" VerticalAlignment="Center" Margin="0,0,14,0"/>

                        <StackPanel Grid.Column="1" VerticalAlignment="Center">
                            <TextBlock x:Name="txtResultTitle" Text="¡Reparación completada con éxito!" FontSize="15" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock x:Name="txtResultDesc" Text="¿Tu equipo ya funciona correctamente tras la reparación?" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                        </StackPanel>

                        <StackPanel x:Name="panelResultActions" Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                            <Button x:Name="btnFeedbackYes" Content="✓ Sí, quedó bien" Style="{StaticResource PillYesStyle}" Margin="0,0,8,0" ToolTip="Confirmar solución exitosa"/>
                            <Button x:Name="btnFeedbackNo" Content="✕ Necesito ayuda de TI" Style="{StaticResource PillNoStyle}" ToolTip="Abrir panel de asistencia con informe para Soporte TI"/>
                        </StackPanel>

                        <StackPanel x:Name="panelResultThanks" Grid.Column="2" Visibility="Collapsed" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="✨ ¡Excelente! Ya puedes continuar trabajando." Foreground="#4ADE80" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <Button x:Name="btnCloseResult" Content="✕" Style="{StaticResource PillButtonStyle}" Width="32" Height="32" Padding="0" ToolTip="Cerrar mensaje"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- 2.5 TARJETA DE SOPORTE TI (REPORTE AUTOMÁTICO) -->
                <Border x:Name="panelSupport" Visibility="Collapsed" Background="#161726" BorderBrush="#3B4261" BorderThickness="1.5" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
                    <Border.Effect>
                        <DropShadowEffect Color="#3B4261" BlurRadius="10" Direction="270" ShadowDepth="1" Opacity="0.4"/>
                    </Border.Effect>
                    <StackPanel>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock Text="🛡️" FontSize="20" Margin="0,0,10,0" VerticalAlignment="Center"/>
                                <StackPanel>
                                    <TextBlock Text="Contactar a Soporte TI" FontSize="15" FontWeight="Bold" Foreground="#FFFFFF"/>
                                    <TextBlock Text="Hemos preparado un informe automático con el diagnóstico exacto de tu equipo." FontSize="12" Foreground="#94A3B8"/>
                                </StackPanel>
                            </StackPanel>

                            <Button x:Name="btnCopyReport" Grid.Column="1" Content="📋 Copiar Reporte" Style="{StaticResource PillButtonStyle}" ToolTip="Copiar texto de diagnóstico al portapapeles"/>
                        </Grid>

                        <TextBox x:Name="txtSupportReport" 
                                 Background="#0A0B12" 
                                 Foreground="#CBD5E1" 
                                 FontFamily="Consolas, monospace" 
                                 FontSize="11" 
                                 IsReadOnly="True" 
                                 TextWrapping="Wrap" 
                                 Height="100" 
                                 BorderBrush="#25283D" 
                                 Padding="10" 
                                 Margin="0,0,0,12" 
                                 VerticalScrollBarVisibility="Auto"/>

                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="10"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <Button x:Name="btnMailSupport" Grid.Column="0" Style="{StaticResource PillButtonStyle}" ToolTip="Abre tu cliente de correo con el asunto y reporte prellenados">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📧" Margin="0,0,8,0"/>
                                    <TextBlock Text="Enviar por Correo a Soporte"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="btnTeamsSupport" Grid.Column="2" Style="{StaticResource PillButtonStyle}" ToolTip="Copia el reporte al portapapeles y abre Microsoft Teams">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="💬" Margin="0,0,8,0"/>
                                    <TextBlock Text="Pegar en Microsoft Teams"/>
                                </StackPanel>
                            </Button>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- 2.5.5 PANEL DE CONFIGURACIÓN DE IMPRESORA DE RED TCP/IP -->
                <Border x:Name="panelPrinterConfig" Visibility="Collapsed" Background="#111320" BorderBrush="#FF7A00" BorderThickness="1.5" CornerRadius="12" Padding="20" Margin="0,0,0,16">
                    <Border.Effect>
                        <DropShadowEffect Color="#FF7A00" BlurRadius="14" Direction="270" ShadowDepth="1" Opacity="0.35"/>
                    </Border.Effect>
                    <StackPanel>
                        <Grid Margin="0,0,0,14">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Border Background="#382E14" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                    <TextBlock Text="🖨️" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <StackPanel VerticalAlignment="Center">
                                    <TextBlock Text="Configuración de Impresora de Red (TCP/IP Puerto 9100)" FontWeight="Bold" FontSize="15" Foreground="#FFFFFF"/>
                                    <TextBlock Text="Conecta e instala una impresora de red mediante su dirección IP y nombre personalizado" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                                </StackPanel>
                            </StackPanel>
                            <Button x:Name="btnClosePrinterConfig" Grid.Column="1" Content="✕" Style="{StaticResource PillButtonStyle}" Padding="10,4" FontSize="12" Cursor="Hand" ToolTip="Cerrar panel"/>
                        </Grid>

                        <!-- Formulario de Configuración -->
                        <Grid Margin="0,0,0,12">
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="Auto"/>
                            </Grid.RowDefinitions>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="16"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>

                            <!-- Campo 1: Nombre Personalizado -->
                            <StackPanel Grid.Row="0" Grid.Column="0" Margin="0,0,0,12">
                                <TextBlock Text="Nombre de la Impresora (Personalizado):" FontSize="12" FontWeight="SemiBold" Foreground="#E2E8F0" Margin="0,0,0,6"/>
                                <TextBox x:Name="txtPrinterName" Text="Impresora Oficina - Orange" Background="#0A0B14" Foreground="#FFFFFF" BorderBrush="#2A2E45" Padding="10,8" FontSize="13"/>
                            </StackPanel>

                            <!-- Campo 2: Dirección IP -->
                            <StackPanel Grid.Row="0" Grid.Column="2" Margin="0,0,0,12">
                                <TextBlock Text="Dirección IP de la Impresora (Puerto 9100):" FontSize="12" FontWeight="SemiBold" Foreground="#E2E8F0" Margin="0,0,0,6"/>
                                <Grid>
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="txtPrinterIp" Text="192.168.1.100" Background="#0A0B14" Foreground="#FFD180" BorderBrush="#2A2E45" Padding="10,8" FontSize="13" FontFamily="Consolas"/>
                                    <Button x:Name="btnTestPrinterSocket" Grid.Column="1" Content="📡 Probar IP" Style="{StaticResource PillButtonStyle}" Margin="8,0,0,0" Padding="12,6" FontSize="11" Cursor="Hand" ToolTip="Verificar conectividad al socket TCP IP:9100"/>
                                </Grid>
                            </StackPanel>

                            <!-- Campo 3: Controlador / Driver -->
                            <StackPanel Grid.Row="1" Grid.Column="0" Grid.ColumnSpan="3" Margin="0,0,0,12">
                                <TextBlock Text="Controlador / Driver de Impresión:" FontSize="12" FontWeight="SemiBold" Foreground="#E2E8F0" Margin="0,0,0,6"/>
                                <ComboBox x:Name="cmbPrinterDriver" Background="#0A0B14" Foreground="#0D0E17" BorderBrush="#2A2E45" Padding="10,6" FontSize="13"/>
                            </StackPanel>

                            <!-- Opciones (Checkboxes) -->
                            <StackPanel Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="3" Orientation="Horizontal" Margin="0,4,0,4">
                                <CheckBox x:Name="chkPrinterDefault" Content="Establecer como impresora predeterminada" IsChecked="True" Foreground="#CBD5E1" FontSize="12" Margin="0,0,24,0"/>
                                <CheckBox x:Name="chkPrinterTestPage" Content="Imprimir página de prueba tras instalar" IsChecked="True" Foreground="#CBD5E1" FontSize="12"/>
                            </StackPanel>
                        </Grid>

                        <!-- Barra de Estado y Botones -->
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock x:Name="txtPrinterTestResult" Text="Listo para configurar. Ingresa los datos y haz clic en Instalar." FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="btnCancelPrinter" Content="Cancelar" Style="{StaticResource PillButtonStyle}" Margin="0,0,8,0" Padding="12,8" FontSize="12" Cursor="Hand"/>
                                <Button x:Name="btnRestartSpoolerQuick" Content="⚡ Desatascar Cola" Style="{StaticResource PillButtonStyle}" Margin="0,0,8,0" Padding="14,8" FontSize="12" Cursor="Hand" ToolTip="Reinicia el servicio Spooler de Windows"/>
                                <Button x:Name="btnInstallPrinter" Content="🖨️ Instalar y Configurar Impresora" Style="{StaticResource HeroButtonStyle}" Padding="18,8" FontSize="12" Cursor="Hand"/>
                            </StackPanel>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- 2.6 CATÁLOGO DE ACCIONES POR SÍNTOMA -->
                <TextBlock Text="O ELIGE QUÉ DESEAS SOLUCIONAR:" FontSize="11" FontWeight="Bold" Foreground="#64748B" Margin="2,4,0,10"/>

                <Grid Margin="0,0,0,14">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="12"/>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="12"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Tile 1: Audio -->
                    <Button x:Name="btnTileAudio" Grid.Row="0" Grid.Column="0" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12" ToolTip="Reinicia los controladores de audio de Windows (Audiosrv, AudioEndpointBuilder)">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#281A38" BorderBrush="#4A266A" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🎧" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Audio y Micrófono" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Sin sonido o micro en Teams" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 2: Internet -->
                    <Button x:Name="btnTileWifi" Grid.Row="0" Grid.Column="2" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12" ToolTip="Limpia caché DNS (flushdns), renueva IP y reinicia interfaces de red">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#102A36" BorderBrush="#1C556D" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🌐" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Internet y Red" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Sin conexión o DNS caído" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 3: Impresora -->
                    <Button x:Name="btnTileSpooler" Grid.Row="0" Grid.Column="4" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12" ToolTip="Desatasca la cola de impresión o abre el instalador de impresoras de red IP:9100">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#382E14" BorderBrush="#6B531C" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🖨️" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Impresoras" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Cola atascada o instalar red" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 4: Pantalla -->
                    <Button x:Name="btnTileExplorer" Grid.Row="1" Grid.Column="0" Style="{StaticResource SymptomTileStyle}" ToolTip="Reinicia el proceso explorer.exe para desbloquear barra de tareas y ventanas">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#142038" BorderBrush="#223E6B" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🖥️" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Pantalla y Barra" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Ventanas trabadas o congeladas" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 5: Actualizar Apps -->
                    <Button x:Name="btnTileUpgrade" Grid.Row="1" Grid.Column="2" Style="{StaticResource SymptomTileStyle}" ToolTip="Escanea con Winget y descarga actualizaciones automáticas de software">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#12341F" BorderBrush="#1C5E37" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🔄" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Actualizar Programas" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Buscar y descargar parches" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 6: Limpieza Perfil -->
                    <Button x:Name="btnTileCleanProfile" Grid.Row="1" Grid.Column="4" Style="{StaticResource SymptomTileStyle}" ToolTip="Respalda datos del perfil y repara configuraciones dañadas de usuario">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#382214" BorderBrush="#6B3A1C" BorderThickness="1" CornerRadius="8" Width="38" Height="38" Margin="0,0,12,0">
                                <TextBlock Text="🧹" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Limpieza de Perfil" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Respaldo y restauración segura" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="20" FontWeight="Bold" Foreground="#475569" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>
                </Grid>

                <!-- 2.7 TOGGLE DE CONSOLA AVANZADA -->
                <Button x:Name="btnToggleConsole" Content="⚙️ Opciones avanzadas y consola técnica ▾" Background="Transparent" Foreground="#64748B" BorderThickness="0" FontSize="12" Cursor="Hand" Margin="0,6,0,10" HorizontalAlignment="Center"/>

                <!-- 2.8 PANEL DE CONSOLA TÉCNICA (COLLAPSIBLE) -->
                <Border x:Name="panelConsole" Visibility="Collapsed" Background="#080910" BorderBrush="#1C2033" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="140"/>
                        </Grid.RowDefinitions>

                        <Grid Grid.Row="0" Margin="0,0,0,8">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Text="📟 REGISTRO DE EJECUCIÓN EN TIEMPO REAL" FontSize="11" FontWeight="Bold" Foreground="#94A3B8" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="btnCopyLog" Content="Copiar" Style="{StaticResource PillButtonStyle}" Padding="10,4" FontSize="11" Margin="0,0,6,0"/>
                                <Button x:Name="btnClearLog" Content="Limpiar" Style="{StaticResource PillButtonStyle}" Padding="10,4" FontSize="11"/>
                            </StackPanel>
                        </Grid>

                        <TextBox x:Name="txtLogs" Grid.Row="1"
                                 Background="#040508" 
                                 Foreground="#86EFAC" 
                                 CaretBrush="#FF7A00"
                                 FontFamily="Consolas, 'Cascadia Code', 'Lucida Console', Courier New"
                                 FontSize="11"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 BorderBrush="#151724"
                                 Padding="8"/>
                    </Grid>
                </Border>

            </StackPanel>
        </ScrollViewer>

        <!-- 3. FOOTER / STATUS BAR -->
        <Border Grid.Row="2" Background="#0F101C" BorderBrush="#1B1E30" BorderThickness="1" CornerRadius="8" Padding="14,8" Margin="0,10,0,0">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock x:Name="txtStatusDot" Text="●" Foreground="#22C55E" FontSize="12" Margin="0,0,8,0" VerticalAlignment="Center"/>
                    <TextBlock x:Name="txtStatusMessage" Text="Sistema listo para operar. Selecciona una acción para comenzar." FontSize="12" Foreground="#94A3B8" VerticalAlignment="Center"/>
                </StackPanel>

                <TextBlock Grid.Column="1" Text="v1.2.0 • Orange Latam" FontSize="11" Foreground="#475569" VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Leer y cargar XAML
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Mapeo de Elementos de la Interfaz
$lblHostName        = $window.FindName("lblHostName")
$lblUserName        = $window.FindName("lblUserName")
$lblIpAddress       = $window.FindName("lblIpAddress")
$lblRamTotal        = $window.FindName("lblRamTotal")
$headerBorder       = $window.FindName("headerBorder")
$btnHeaderMin       = $window.FindName("btnHeaderMin")
$btnHeaderMax       = $window.FindName("btnHeaderMax")
$btnHeaderClose     = $window.FindName("btnHeaderClose")

$btnHeroRepairAll   = $window.FindName("btnHeroRepairAll")
$btnTileAudio       = $window.FindName("btnTileAudio")
$btnTileWifi        = $window.FindName("btnTileWifi")
$btnTileSpooler     = $window.FindName("btnTileSpooler")
$btnTileExplorer    = $window.FindName("btnTileExplorer")
$btnTileUpgrade     = $window.FindName("btnTileUpgrade")
$btnTileCleanProfile= $window.FindName("btnTileCleanProfile")

$panelProgress      = $window.FindName("panelProgress")
$txtStepBadge       = $window.FindName("txtStepBadge")
$txtActionTitle     = $window.FindName("txtActionTitle")
$txtStepDescription = $window.FindName("txtStepDescription")
$txtProgressPercent = $window.FindName("txtProgressPercent")
$progressBarAction  = $window.FindName("progressBarAction")

$panelResult        = $window.FindName("panelResult")
$txtResultIcon      = $window.FindName("txtResultIcon")
$txtResultTitle     = $window.FindName("txtResultTitle")
$txtResultDesc      = $window.FindName("txtResultDesc")
$panelResultActions = $window.FindName("panelResultActions")
$panelResultThanks  = $window.FindName("panelResultThanks")
$btnFeedbackYes     = $window.FindName("btnFeedbackYes")
$btnFeedbackNo      = $window.FindName("btnFeedbackNo")
$btnCloseResult     = $window.FindName("btnCloseResult")
$panelPrinterConfig     = $window.FindName("panelPrinterConfig")
$btnClosePrinterConfig  = $window.FindName("btnClosePrinterConfig")
$txtPrinterName         = $window.FindName("txtPrinterName")
$txtPrinterIp           = $window.FindName("txtPrinterIp")
$btnTestPrinterSocket   = $window.FindName("btnTestPrinterSocket")
$cmbPrinterDriver       = $window.FindName("cmbPrinterDriver")
$chkPrinterDefault      = $window.FindName("chkPrinterDefault")
$chkPrinterTestPage     = $window.FindName("chkPrinterTestPage")
$txtPrinterTestResult   = $window.FindName("txtPrinterTestResult")
$btnRestartSpoolerQuick = $window.FindName("btnRestartSpoolerQuick")
$btnCancelPrinter       = $window.FindName("btnCancelPrinter")
$btnInstallPrinter      = $window.FindName("btnInstallPrinter")

$panelSupport       = $window.FindName("panelSupport")
$txtSupportReport   = $window.FindName("txtSupportReport")
$btnCopyReport      = $window.FindName("btnCopyReport")
$btnMailSupport     = $window.FindName("btnMailSupport")
$btnTeamsSupport    = $window.FindName("btnTeamsSupport")

$btnToggleConsole   = $window.FindName("btnToggleConsole")
$panelConsole       = $window.FindName("panelConsole")
$txtLogs            = $window.FindName("txtLogs")
$btnCopyLog         = $window.FindName("btnCopyLog")
$btnClearLog        = $window.FindName("btnClearLog")

$txtStatusDot       = $window.FindName("txtStatusDot")
$txtStatusMessage   = $window.FindName("txtStatusMessage")

# Variables de Estado
$script:isBusy = $false
$script:lastActionName = ""
$script:hardwareInfo = @{}

# Función para Forzar Refresco del UI en Tiempo Real (DoEvents / Message Pump)
function Update-Gui {
    try {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [Action]{},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    } catch {}
}

# Función de Registro en Consola WPF
function Write-GuiLog {
    param(
        [string]$Message,
        [string]$Type = "INFO" # INFO, OK, WARN, ERROR, STEP
    )

    $time = (Get-Date -Format "HH:mm:ss")
    $prefix = switch ($Type) {
        "OK"    { "[✓ OK]" }
        "ERROR" { "[✕ ERROR]" }
        "WARN"  { "[! AVISO]" }
        "STEP"  { "[▸ PASO]" }
        default { "[i INFO]" }
    }

    $txtLogs.AppendText("[$time] $prefix $Message`r`n")
    $txtLogs.ScrollToEnd()
    Update-Gui
}

# Función para Actualizar el Progreso en Tiempo Real
function Set-GuiProgress {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Label,
        [int]$Percent
    )

    $txtStepBadge.Text = "Paso $Step de $Total"
    $txtStepDescription.Text = $Label
    $txtProgressPercent.Text = "$Percent%"
    $progressBarAction.Value = $Percent
    $txtStatusMessage.Text = "Paso $Step de $($Total): $Label"
    Update-Gui
    Write-GuiLog ("[Paso {0}/{1}] ({2}%) {3}" -f $Step, $Total, $Percent, $Label) "STEP"
}

# Función para Habilitar / Deshabilitar Botones
function Set-UiEnabled {
    param([bool]$Enabled)

    $btnHeroRepairAll.IsEnabled    = $Enabled
    $btnTileAudio.IsEnabled        = $Enabled
    $btnTileWifi.IsEnabled         = $Enabled
    $btnTileSpooler.IsEnabled      = $Enabled
    $btnTileExplorer.IsEnabled     = $Enabled
    $btnTileUpgrade.IsEnabled      = $Enabled
    $btnTileCleanProfile.IsEnabled = $Enabled

    if (-not $Enabled) {
        $txtStatusDot.Foreground = [System.Windows.Media.Brushes]::Orange
        $txtStatusDot.Text = "◌"
    } else {
        $txtStatusDot.Foreground = [System.Windows.Media.Brushes]::MediumSeaGreen
        $txtStatusDot.Text = "●"
    }
    Update-Gui
}

# Función para Mostrar Banner de Resultado
function Show-ResultBanner {
    param(
        [bool]$Success,
        [string]$Title,
        [string]$ErrorMessage = $null
    )

    $panelProgress.Visibility = [System.Windows.Visibility]::Collapsed
    $panelResult.Visibility = [System.Windows.Visibility]::Visible
    $panelResultActions.Visibility = [System.Windows.Visibility]::Visible
    $panelResultThanks.Visibility = [System.Windows.Visibility]::Collapsed

    if ($Success) {
        $txtResultIcon.Text = "🎉"
        $txtResultTitle.Text = "¡Listo! Tarea completada con éxito."
        $txtResultDesc.Text = "¿Tu equipo ya funciona correctamente tras $Title?"
        $txtStatusMessage.Text = "Completado: $Title exitoso."
    } else {
        $txtResultIcon.Text = "⚠️"
        $txtResultTitle.Text = "Requirió atención adicional."
        $txtResultDesc.Text = if ($ErrorMessage) { "Detalle: $ErrorMessage" } else { "Es posible que se requiera asistencia de TI." }
        $txtStatusMessage.Text = "Error en $Title."
        Open-SupportCard
    }
    Update-Gui
}

# Función para Abrir Tarjeta de Soporte TI
function Open-SupportCard {
    $panelSupport.Visibility = [System.Windows.Visibility]::Visible

    $pc = $lblHostName.Text
    $user = $lblUserName.Text
    $ip = $lblIpAddress.Text
    $ram = $lblRamTotal.Text
    $action = $script:lastActionName
    $timeStr = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    $reportText = @"
=========================================
  REPORTE ASISTENCIA TI - ORANGE LATAM
=========================================
Fecha:     $timeStr
Equipo:    $pc
Usuario:   $user
Windows:   $($script:hardwareInfo.osCaption)
IP:        $ip
RAM:       $ram
Problema:  $action
=========================================
"@
    $txtSupportReport.Text = $reportText
    Update-Gui
}

# Ejecutor de Acciones en Tiempo Real
function Run-AsyncAction {
    param(
        [string]$ActionName,
        [scriptblock]$TaskBlock
    )

    if ($script:isBusy) { return }
    $script:isBusy = $true
    $script:lastActionName = $ActionName

    $panelResult.Visibility = [System.Windows.Visibility]::Collapsed
    $panelSupport.Visibility = [System.Windows.Visibility]::Collapsed
    $panelProgress.Visibility = [System.Windows.Visibility]::Visible
    $panelConsole.Visibility = [System.Windows.Visibility]::Visible
    $btnToggleConsole.Content = "⚙️ Ocultar consola técnica ▴"
    $txtActionTitle.Text = $ActionName
    $txtStepBadge.Text = "Iniciando..."
    $txtStepDescription.Text = "Preparando ejecución de Windows..."
    $txtProgressPercent.Text = "5%"
    $progressBarAction.Value = 5
    Update-Gui

    Set-UiEnabled $false
    Write-GuiLog "============================================================" "INFO"
    Write-GuiLog "INICIANDO: $ActionName" "INFO"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $actionSuccess = $true
    $errorDetail = $null

    try {
        & $TaskBlock
        Write-GuiLog "Acción '$ActionName' finalizada con éxito." "OK"
    }
    catch {
        $actionSuccess = $false
        $errorDetail = $_.Exception.Message
        Write-GuiLog "Error durante '$ActionName': $errorDetail" "ERROR"
    }
    finally {
        $stopwatch.Stop()
        $elapsedSec = "{0:N1}s" -f ($stopwatch.ElapsedMilliseconds / 1000)
        Write-GuiLog "Tiempo total de ejecución: $elapsedSec" "INFO"
        Write-GuiLog "============================================================" "INFO"

        $progressBarAction.Value = 100
        $txtProgressPercent.Text = "100%"
        $txtStepDescription.Text = "¡Completado!"
        Update-Gui

        Start-Sleep -Milliseconds 300
        Show-ResultBanner -Success $actionSuccess -Title $ActionName -ErrorMessage $errorDetail
        Set-UiEnabled $true
        $script:isBusy = $false
        Update-Gui
    }
}

# Carga de Telemetría Inicial
function Load-HardwareTelemetry {
    try {
        $hostName = $env:COMPUTERNAME
        $userName = $env:USERNAME

        $lblHostName.Text = $hostName
        $lblUserName.Text = $userName

        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        $ramTotal = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        if (-not $ip) { $ip = "Desconectado" }

        $ramStr = if ($ramTotal) { "{0:N1} GB" -f ($ramTotal / 1GB) } else { "N/D" }
        $script:hardwareInfo.osCaption = if ($os) { "$($os.Caption) (Build $($os.BuildNumber))" } else { "Windows 10/11" }

        $lblIpAddress.Text = $ip
        $lblRamTotal.Text = $ramStr
        Update-Gui
        Write-GuiLog "Telemetría cargada: $hostName ($ip) | RAM: $ramStr" "OK"
    } catch {
        Write-GuiLog "Aviso leyendo telemetría: $_" "WARN"
    }
}

# ==========================================================================
# DEFINICIÓN DE EVENTOS DE BOTONES
# ==========================================================================

# 1. Hero 1-Click: Reparar Todo el Equipo
$btnHeroRepairAll.Add_Click({
    Run-AsyncAction "Reparación Completa del Equipo" {
        Set-GuiProgress 1 4 "Desbloqueando servicios de audio y micrófono..." 25
        Write-GuiLog "Reiniciando servicios Audiosrv y AudioEndpointBuilder..." "INFO"
        Stop-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400
        Start-Service -Name AudioEndpointBuilder -ErrorAction SilentlyContinue
        Start-Service -Name Audiosrv -ErrorAction SilentlyContinue
        Write-GuiLog "Audio y micrófono restablecidos." "OK"

        Set-GuiProgress 2 4 "Desbloqueando cola de impresión (Spooler)..." 50
        Write-GuiLog "Reiniciando servicio de impresión..." "INFO"
        Restart-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        Write-GuiLog "Cola de impresión liberada." "OK"

        Set-GuiProgress 3 4 "Restableciendo conexión de red y limpiando caché DNS..." 75
        Write-GuiLog "Vaciando DNS y renovando concesión DHCP..." "INFO"
        ipconfig /flushdns | Out-Null
        ipconfig /renew | Out-Null
        Write-GuiLog "Conectividad de red restablecida." "OK"

        Set-GuiProgress 4 4 "Refrescando explorador y barra de tareas..." 95
        Write-GuiLog "Recargando explorer.exe..." "INFO"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
        Start-Process explorer.exe
        Write-GuiLog "Entorno visual recargado." "OK"
    }
})

# 2. Audio y Micrófono
$btnTileAudio.Add_Click({
    Run-AsyncAction "Reparación de Audio y Micrófono" {
        Set-GuiProgress 1 2 "Deteniendo servicios de sonido..." 40
        Write-GuiLog "Deteniendo Audiosrv..." "INFO"
        Stop-Service -Name Audiosrv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name AudioEndpointBuilder -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        Set-GuiProgress 2 2 "Reactivando servicios y controladores..." 85
        Write-GuiLog "Iniciando AudioEndpointBuilder y Audiosrv..." "INFO"
        Start-Service -Name AudioEndpointBuilder -ErrorAction SilentlyContinue
        Start-Service -Name Audiosrv -ErrorAction SilentlyContinue
        Write-GuiLog "Servicios de sonido listos." "OK"
    }
})

# 3. Internet y Wi-Fi
$btnTileWifi.Add_Click({
    Run-AsyncAction "Reconexión de Internet y Red" {
        Set-GuiProgress 1 3 "Vaciando memoria caché DNS..." 30
        Write-GuiLog "Ejecutando ipconfig /flushdns..." "INFO"
        ipconfig /flushdns | Out-Null

        Set-GuiProgress 2 3 "Registrando configuración DNS..." 60
        Write-GuiLog "Ejecutando ipconfig /registerdns..." "INFO"
        ipconfig /registerdns | Out-Null
        Start-Sleep -Milliseconds 500

        Set-GuiProgress 3 3 "Renovando dirección IP (DHCP)..." 90
        Write-GuiLog "Solicitando nueva IP (ipconfig /renew)..." "INFO"
        ipconfig /renew | Out-Null
        Write-GuiLog "Red restablecida con éxito." "OK"
    }
})

# Funciones Auxiliares para Impresoras
function Load-InstalledPrinterDrivers {
    try {
        $cmbPrinterDriver.Items.Clear()
        $drivers = Get-PrinterDriver -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name | Sort-Object -Unique
        if ($drivers) {
            foreach ($d in $drivers) {
                [void]$cmbPrinterDriver.Items.Add($d)
            }
        }
        if ($cmbPrinterDriver.Items.Count -eq 0) {
            [void]$cmbPrinterDriver.Items.Add("Microsoft IPP Class Driver")
            [void]$cmbPrinterDriver.Items.Add("Generic / Text Only")
            [void]$cmbPrinterDriver.Items.Add("Microsoft PCL6 Class Driver")
        }
        $cmbPrinterDriver.SelectedIndex = 0
    } catch {}
}

function Test-PrinterPort9100 {
    param([string]$IpAddress, [int]$TimeoutMs = 1500)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $iar = $tcp.BeginConnect($IpAddress, 9100, $null, $null)
        $wait = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($iar)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    } catch {
        return $false
    }
}

# 4. Impresora (Abre Panel de Configuración y Mantenimiento)
$btnTileSpooler.Add_Click({
    if ($panelPrinterConfig.Visibility -eq [System.Windows.Visibility]::Visible) {
        $panelPrinterConfig.Visibility = [System.Windows.Visibility]::Collapsed
    } else {
        $panelPrinterConfig.Visibility = [System.Windows.Visibility]::Visible
        $panelProgress.Visibility = [System.Windows.Visibility]::Collapsed
        $panelResult.Visibility = [System.Windows.Visibility]::Collapsed
        $panelSupport.Visibility = [System.Windows.Visibility]::Collapsed
        Load-InstalledPrinterDrivers
        $txtPrinterTestResult.Text = "Panel listo. Ingresa la IP, Nombre personalizado y Controlador."
        $txtPrinterTestResult.Foreground = [System.Windows.Media.Brushes]::LightSlateGray
        Write-GuiLog "Panel de configuración de impresora de red (TCP/IP) desplegado." "INFO"
    }
})

$btnClosePrinterConfig.Add_Click({
    $panelPrinterConfig.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnCancelPrinter.Add_Click({
    $panelPrinterConfig.Visibility = [System.Windows.Visibility]::Collapsed
})

# Desatascar Cola de Impresión Rápido
$btnRestartSpoolerQuick.Add_Click({
    Run-AsyncAction "Desbloqueo de Impresora y Cola Spooler" {
        Set-GuiProgress 1 2 "Deteniendo cola de impresión (Spooler)..." 40
        Write-GuiLog "Deteniendo servicio Spooler de Windows..." "INFO"
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        Set-GuiProgress 2 2 "Iniciando servicio de impresión..." 85
        Write-GuiLog "Reactivando servicio Spooler..." "INFO"
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        Write-GuiLog "Cola de impresión liberada y lista." "OK"
    }
})

# Probar Conectividad IP (Puerto 9100)
$btnTestPrinterSocket.Add_Click({
    $ip = $txtPrinterIp.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($ip)) {
        $txtPrinterTestResult.Text = "Debes ingresar una dirección IP válida."
        $txtPrinterTestResult.Foreground = [System.Windows.Media.Brushes]::Crimson
        return
    }

    $txtPrinterTestResult.Text = "Probando conexión con $ip en el puerto 9100..."
    $txtPrinterTestResult.Foreground = [System.Windows.Media.Brushes]::Orange
    Update-Gui
    Write-GuiLog "Comprobando conexión TCP a $ip`:9100..." "INFO"

    $online = Test-PrinterPort9100 -IpAddress $ip -TimeoutMs 2000
    if ($online) {
        $txtPrinterTestResult.Text = "✓ Impresora conectada y accesible en el puerto 9100."
        $txtPrinterTestResult.Foreground = [System.Windows.Media.Brushes]::MediumSeaGreen
        Write-GuiLog "✓ Impresora detectada en línea en $ip`:9100." "OK"
    } else {
        $txtPrinterTestResult.Text = "✕ No se detectó respuesta en $ip`:9100 (Revisa si está encendida o en la misma red)."
        $txtPrinterTestResult.Foreground = [System.Windows.Media.Brushes]::OrangeRed
        Write-GuiLog "! No se pudo establecer conexión con $ip en el puerto 9100." "WARN"
    }
})

# Instalar y Configurar Impresora de Red
$btnInstallPrinter.Add_Click({
    $pName = $txtPrinterName.Text.Trim()
    $pIp = $txtPrinterIp.Text.Trim()
    $pDriver = if ($cmbPrinterDriver.SelectedItem) { $cmbPrinterDriver.SelectedItem.ToString() } else { "Generic / Text Only" }
    $setDefault = [bool]$chkPrinterDefault.IsChecked
    $testPage = [bool]$chkPrinterTestPage.IsChecked

    if ([string]::IsNullOrWhiteSpace($pName)) {
        [System.Windows.MessageBox]::Show("Por favor ingresa un nombre personalizado para la impresora.", "Falta Nombre de Impresora", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    if ([string]::IsNullOrWhiteSpace($pIp)) {
        [System.Windows.MessageBox]::Show("Por favor ingresa la dirección IP de la impresora.", "Falta Dirección IP", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        return
    }

    $panelPrinterConfig.Visibility = [System.Windows.Visibility]::Collapsed

    Run-AsyncAction "Instalación de Impresora: $pName" {
        # Paso 1: Test de Conectividad
        Set-GuiProgress 1 4 "Comprobando conectividad con $pIp:9100..." 25
        Write-GuiLog "Verificando socket de red en $pIp`:9100..." "INFO"
        $isReachable = Test-PrinterPort9100 -IpAddress $pIp -TimeoutMs 2000
        if ($isReachable) {
            Write-GuiLog "✓ Puerto 9100 responde correctamente." "OK"
        } else {
            Write-GuiLog "! La impresora no respondió en el puerto 9100. Se procederá a crear el puerto y configurar en Windows..." "WARN"
        }

        # Paso 2: Crear / Verificar Puerto TCP/IP
        Set-GuiProgress 2 4 "Configurando puerto estándar TCP/IP (IP_$pIp)..." 50
        $portName = "IP_$pIp"
        Write-GuiLog "Registrando puerto de impresora $portName..." "INFO"
        
        $existingPort = Get-PrinterPort -Name $portName -ErrorAction SilentlyContinue
        if (-not $existingPort) {
            Add-PrinterPort -Name $portName -PrinterHostAddress $pIp -PortNumber 9100 -ErrorAction Stop
            Write-GuiLog "✓ Puerto TCP/IP $portName registrado con éxito." "OK"
        } else {
            Write-GuiLog "i El puerto TCP/IP $portName ya se encuentra disponible." "INFO"
        }

        # Paso 3: Agregar Dispositivo de Impresión
        Set-GuiProgress 3 4 "Vinculando impresora '$pName' con driver '$pDriver'..." 75
        Write-GuiLog "Instalando dispositivo de impresión '$pName' en Windows..." "INFO"

        $existingPrinter = Get-Printer -Name $pName -ErrorAction SilentlyContinue
        if ($existingPrinter) {
            Write-GuiLog "! La impresora '$pName' ya existía en el sistema. Actualizando puerto y controlador..." "WARN"
            Set-Printer -Name $pName -PortName $portName -DriverName $pDriver -ErrorAction SilentlyContinue
        } else {
            Add-Printer -Name $pName -PortName $portName -DriverName $pDriver -ErrorAction Stop
        }
        Write-GuiLog "✓ Impresora '$pName' registrada exitosamente." "OK"

        # Paso 4: Establecer como predeterminada y enviar página de prueba
        Set-GuiProgress 4 4 "Aplicando preferencias del usuario..." 95
        if ($setDefault) {
            Write-GuiLog "Configurando '$pName' como impresora predeterminada de Windows..." "INFO"
            try {
                (New-Object -ComObject WScript.Network).SetDefaultPrinter($pName)
                Write-GuiLog "✓ Impresora '$pName' establecida como predeterminada." "OK"
            } catch {
                Write-GuiLog "Aviso al definir predeterminada: $_" "WARN"
            }
        }

        if ($testPage) {
            Write-GuiLog "Enviando página de prueba a '$pName'..." "INFO"
            try {
                $wmiPrinters = Get-CimInstance -ClassName Win32_Printer -Filter "Name = '$pName'" -ErrorAction SilentlyContinue
                if ($wmiPrinters) {
                    Invoke-CimMethod -InputObject $wmiPrinters -MethodName PrintTestPage | Out-Null
                    Write-GuiLog "✓ Página de prueba enviada exitosamente a la cola de impresión." "OK"
                }
            } catch {
                Write-GuiLog "Aviso enviando página de prueba: $_" "WARN"
            }
        }

        Write-GuiLog "Configuración de impresora de red completada con éxito." "OK"
    }
})

# 5. Explorador / Pantalla Congelada
$btnTileExplorer.Add_Click({
    Run-AsyncAction "Refresco de Pantalla y Barra de Tareas" {
        Set-GuiProgress 1 2 "Cerrando proceso explorer.exe..." 40
        Write-GuiLog "Cerrando proceso explorer.exe..." "INFO"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600

        Set-GuiProgress 2 2 "Iniciando nuevo proceso explorer.exe..." 85
        Write-GuiLog "Lanzando explorer.exe..." "INFO"
        Start-Process explorer.exe
        Write-GuiLog "Barra de tareas y ventanas refrescadas." "OK"
    }
})

# 6. Actualizar Programas con Feedback en Vivo
$btnTileUpgrade.Add_Click({
    Run-AsyncAction "Actualización de Programas Instalados" {
        Set-GuiProgress 1 3 "Escaneando aplicaciones instaladas con winget..." 20
        Write-GuiLog "Buscando aplicaciones con actualizaciones pendientes..." "INFO"
        
        $raw = winget upgrade | Out-String
        $lines = $raw -split "`r?`n"
        
        # Parsear tabla de aplicaciones
        $headerIndex = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^Name\s+Id\s+Version') {
                $headerIndex = $i
                break
            }
        }

        $apps = @()
        if ($headerIndex -ge 0) {
            $header = $lines[$headerIndex]
            $idStart = $header.IndexOf("Id")
            $versionStart = $header.IndexOf("Version")
            $availableStart = $header.IndexOf("Available")

            for ($i = $headerIndex + 2; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                if ([string]::IsNullOrWhiteSpace($line)) { break }
                if ($line -match '^\d+ upgrades? available' -or $line -match 'upgrade available') { break }
                if ($line.Length -lt $idStart) { continue }

                $name = $line.Substring(0, $idStart).Trim()
                $id = if ($availableStart -gt $idStart) { $line.Substring($idStart, [Math]::Min($versionStart, $line.Length) - $idStart).Trim() } else { "" }
                $version = if ($line.Length -gt $versionStart) { $line.Substring($versionStart, [Math]::Min($availableStart, $line.Length) - $versionStart).Trim() } else { "" }
                $available = if ($line.Length -gt $availableStart) { $line.Substring($availableStart).Trim() } else { "" }

                if ($name -and $id) {
                    $apps += [PSCustomObject]@{ Name = $name; Id = $id; Version = $version; Available = $available }
                }
            }
        }

        if ($apps.Count -eq 0) {
            Set-GuiProgress 3 3 "Tu equipo está completamente al día" 100
            Write-GuiLog "¡Excelente! No se encontraron actualizaciones pendientes. Todas las apps están al día." "OK"
            Start-Sleep -Seconds 1
        } else {
            Write-GuiLog "Se encontraron $($apps.Count) aplicaciones pendientes por actualizar:" "INFO"
            foreach ($a in $apps) {
                Write-GuiLog "  • $($a.Name) (Versión actual: $($a.Version) -> Disponible: $($a.Available))" "INFO"
            }

            $current = 0
            $total = $apps.Count
            foreach ($a in $apps) {
                $current++
                $pct = [Math]::Round(25 + (($current / $total) * 70))
                Set-GuiProgress 2 3 "[$current/$total] Actualizando: $($a.Name)..." $pct
                Write-GuiLog "============================================================" "INFO"
                Write-GuiLog "[$current/$total] Descargando e instalando parche para: $($a.Name) ($($a.Id))..." "INFO"

                $proc = Start-Process -FilePath "winget" -ArgumentList "upgrade --id `"$($a.Id)`" --silent --include-unknown --accept-package-agreements --accept-source-agreements" -Wait -PassThru -NoNewWindow
                
                if ($proc.ExitCode -eq 0) {
                    Write-GuiLog "✓ $($a.Name) actualizado exitosamente." "OK"
                } else {
                    Write-GuiLog "! $($a.Name) finalizó con código ($($proc.ExitCode))." "WARN"
                }
            }

            Set-GuiProgress 3 3 "Verificación y actualización finalizada" 100
            Write-GuiLog "Todas las aplicaciones seleccionadas fueron procesadas." "OK"
        }
    }
})

# 7. Limpieza y Respaldo de Perfil
$btnTileCleanProfile.Add_Click({
    $confirm = [System.Windows.MessageBox]::Show(
        "Tus archivos de Escritorio, Descargas y Documentos se guardarán de forma segura en la carpeta 'Respaldo_Usuario' en tu Escritorio y se restaurará el fondo oficial.`n`n¿Deseas continuar?",
        "Confirmación de Respaldo de Perfil",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
        Run-AsyncAction "Limpieza y Respaldo de Perfil" {
            Set-GuiProgress 1 2 "Iniciando respaldo seguro con Robocopy..." 40
            $scriptPath = [System.IO.Path]::Combine($script:appDir, "Limpiar-Perfil.bat")

            if ([System.IO.File]::Exists($scriptPath)) {
                Write-GuiLog "Ejecutando $scriptPath..." "INFO"
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -Wait -NoNewWindow -PassThru
                
                Set-GuiProgress 2 2 "Restableciendo configuración de usuario..." 85
                Write-GuiLog "Respaldo completado en tu Escritorio: Respaldo_Usuario" "OK"
                Write-GuiLog "Fondo de pantalla oficial restablecido." "OK"
            } else {
                throw "No se encontró el archivo Limpiar-Perfil.bat en $($script:appDir)"
            }
        }
    }
})

# Feedback y Soporte
$btnFeedbackYes.Add_Click({
    $panelResultActions.Visibility = [System.Windows.Visibility]::Collapsed
    $panelResultThanks.Visibility = [System.Windows.Visibility]::Visible
    $panelSupport.Visibility = [System.Windows.Visibility]::Collapsed
})

$btnFeedbackNo.Add_Click({
    $panelResultActions.Visibility = [System.Windows.Visibility]::Collapsed
    Open-SupportCard
})

$btnCloseResult.Add_Click({
    $panelResult.Visibility = [System.Windows.Visibility]::Collapsed
})

# Copiar Reporte
$btnCopyReport.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText($txtSupportReport.Text)
        $btnCopyReport.Content = "✓ ¡Copiado!"
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(2.5)
        $timer.Add_Tick({
            $btnCopyReport.Content = "📋 Copiar Reporte"
            $timer.Stop()
        })
        $timer.Start()
    } catch {}
})

# Teams
$btnTeamsSupport.Add_Click({
    $btnCopyReport.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Button]::ClickEvent)))
    [System.Windows.MessageBox]::Show(
        "El informe técnico fue copiado al portapapeles. Pégalo directamente (Ctrl + V) en tu chat con Soporte en Microsoft Teams.",
        "Reporte Copiado para Teams",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    )
})

# Correo
$btnMailSupport.Add_Click({
    $subject = [Uri]::EscapeDataString("Soporte TI - $($lblHostName.Text) - $($script:lastActionName)")
    $body = [Uri]::EscapeDataString("Hola Soporte TI,`n`nRequiero asistencia técnica:`n`n$($txtSupportReport.Text)")
    $mailto = "mailto:soporte@orangelatam.com?subject=$subject&body=$body"
    Start-Process $mailto
})

# Toggle Consola Técnica
$btnToggleConsole.Add_Click({
    if ($panelConsole.Visibility -eq [System.Windows.Visibility]::Visible) {
        $panelConsole.Visibility = [System.Windows.Visibility]::Collapsed
        $btnToggleConsole.Content = "⚙️ Opciones avanzadas y consola técnica ▾"
    } else {
        $panelConsole.Visibility = [System.Windows.Visibility]::Visible
        $btnToggleConsole.Content = "⚙️ Ocultar consola técnica ▴"
    }
})

$btnClearLog.Add_Click({
    $txtLogs.Text = "[$(Get-Date -Format 'HH:mm:ss')] [i INFO] Consola limpiada.`r`n"
})

$btnCopyLog.Add_Click({
    try {
        [System.Windows.Clipboard]::SetText($txtLogs.Text)
        $btnCopyLog.Content = "✓ ¡Copiado!"
        $timer = New-Object System.Windows.Threading.DispatcherTimer
        $timer.Interval = [TimeSpan]::FromSeconds(2)
        $timer.Add_Tick({
            $btnCopyLog.Content = "Copiar"
            $timer.Stop()
        })
        $timer.Start()
    } catch {}
})

# Control de Ventana (Arrastrar, Minimizar, Maximizar y Salir)
$headerBorder.Add_MouseLeftButtonDown({
    if ($_.ClickCount -eq 2) {
        if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
            $window.WindowState = [System.Windows.WindowState]::Normal
        } else {
            $window.WindowState = [System.Windows.WindowState]::Maximized
        }
    } elseif ($_.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
        try { $window.DragMove() } catch {}
    }
})

$btnHeaderMin.Add_Click({
    $window.WindowState = [System.Windows.WindowState]::Minimized
})

$btnHeaderMax.Add_Click({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    } else {
        $window.WindowState = [System.Windows.WindowState]::Maximized
    }
})

$btnHeaderClose.Add_Click({
    $window.Close()
})

$window.Add_KeyDown({
    if ($_.Key -eq [System.Windows.Input.Key]::Escape) {
        $window.Close()
    }
})

$window.Add_Closed({
    [System.Environment]::Exit(0)
})

# Inicialización al arrancar
try {
    Write-GuiLog "Asistencia Orange (WPF Nativo) iniciada correctamente." "OK"
    Load-HardwareTelemetry

    # Mostrar Ventana Principal
    $window.ShowDialog() | Out-Null
    [System.Environment]::Exit(0)
} catch {
    [System.Windows.MessageBox]::Show(
        "Error en la ejecución de Asistencia Orange:`n`n$($_.Exception.Message)`n`nDetalle técnico:`n$($_.ScriptStackTrace)",
        "Asistencia Orange - Diagnóstico",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    )
    [System.Environment]::Exit(1)
}
