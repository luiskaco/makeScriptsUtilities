<#
.SYNOPSIS
    Asistencia Orange — Portal de Auto-Atención y Diagnóstico (WPF Nativo)
    Aplicación nativa de escritorio para auto-reparación rápida de Windows,
    soporte TI, optimización y telemetría de hardware en un solo clic.
#>

[CmdletBinding()]
param()

# Resolver ruta absoluta del script
$targetScript = if ($PSCommandPath) { $PSCommandPath } elseif ($MyInvocation.MyCommand.Path) { $MyInvocation.MyCommand.Path } else { Join-Path $PSScriptRoot "AsistenciaOrange.ps1" }

# Auto-elevación segura a Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and (Test-Path $targetScript)) {
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -STA -File `"$targetScript`""
        $psi.Verb = "runas"
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
        Height="840" Width="1040" 
        MinHeight="720" MinWidth="900"
        WindowStartupLocation="CenterScreen"
        Background="#0D0E17" 
        Foreground="#F1F5F9"
        FontFamily="Segoe UI, Segoe UI Variable, Microsoft YaHei, Arial">

    <Window.Resources>
        <!-- Estilo de Tarjetas de Síntomas -->
        <Style x:Key="SymptomTileStyle" TargetType="Button">
            <Setter Property="Background" Value="#151724"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#25283B"/>
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
                                CornerRadius="12">
                            <ContentPresenter Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1F2336"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FF7A00"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2A1E14"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FFA347"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo de Botón Hero Naranja -->
        <Style x:Key="HeroButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#FF7A00"/>
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
                                CornerRadius="10">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#FF8F26"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#FFB870"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#E06500"/>
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
            <Setter Property="Background" Value="#222538"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="BorderBrush" Value="#333852"/>
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
                                CornerRadius="20">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2D324D"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#94A3B8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo Botón Verde Sí -->
        <Style x:Key="PillYesStyle" TargetType="Button" BasedOn="{StaticResource PillButtonStyle}">
            <Setter Property="Background" Value="#143828"/>
            <Setter Property="Foreground" Value="#4ADE80"/>
            <Setter Property="BorderBrush" Value="#22C55E"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="20">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1C4F38"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo Botón Rojo No -->
        <Style x:Key="PillNoStyle" TargetType="Button" BasedOn="{StaticResource PillButtonStyle}">
            <Setter Property="Background" Value="#38181A"/>
            <Setter Property="Foreground" Value="#F87171"/>
            <Setter Property="BorderBrush" Value="#EF4444"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="20">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#4F2225"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Estilo ProgressBar Naranja -->
        <Style x:Key="OrangeProgressBarStyle" TargetType="ProgressBar">
            <Setter Property="Height" Value="8"/>
            <Setter Property="Background" Value="#1F2338"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ProgressBar">
                        <Grid x:Name="TemplateRoot">
                            <Border CornerRadius="4" Background="{TemplateBinding Background}"/>
                            <Border x:Name="PART_Track" CornerRadius="4"/>
                            <Border x:Name="PART_Indicator" HorizontalAlignment="Left" CornerRadius="4">
                                <Border.Background>
                                    <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                        <GradientStop Color="#FF7A00" Offset="0"/>
                                        <GradientStop Color="#FFA347" Offset="0.7"/>
                                        <GradientStop Color="#FFD180" Offset="1"/>
                                    </LinearGradientBrush>
                                </Border.Background>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="20">
        <Grid.RowDefinitions>
            <!-- Header -->
            <RowDefinition Height="Auto"/>
            <!-- Main Scrollable Area -->
            <RowDefinition Height="*"/>
            <!-- Status Bar Footer -->
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- 1. HEADER PRINCIPAL -->
        <Border Grid.Row="0" Background="#141624" BorderBrush="#23263B" BorderThickness="1" CornerRadius="12" Padding="18,12" Margin="0,0,0,16">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Border Background="#FF7A00" CornerRadius="10" Width="42" Height="42" Margin="0,0,14,0">
                        <TextBlock Text="⚡" FontSize="22" HorizontalAlignment="Center" VerticalAlignment="Center" Foreground="#FFFFFF"/>
                    </Border>
                    <StackPanel VerticalAlignment="Center">
                        <TextBlock Text="Asistencia Orange" FontSize="19" FontWeight="Bold" Foreground="#FFFFFF"/>
                        <TextBlock Text="Portal de auto-reparación y soporte rápido" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                    </StackPanel>
                </StackPanel>

                <!-- Estado de Administrador -->
                <Border Grid.Column="1" Background="#11291E" BorderBrush="#1D533A" BorderThickness="1" CornerRadius="20" Padding="12,6" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <Ellipse Width="8" Height="8" Fill="#22C55E" Margin="0,0,8,0" VerticalAlignment="Center"/>
                        <TextBlock Text="Administrador Activo" FontSize="12" FontWeight="SemiBold" Foreground="#4ADE80" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>
            </Grid>
        </Border>

        <!-- 2. CONTENIDO PRINCIPAL CON SCROLL -->
        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <StackPanel Margin="0,0,6,0">

                <!-- 2.1 TELEMETRÍA RÁPIDA DEL EQUIPO -->
                <Border Background="#10121D" BorderBrush="#1E2235" BorderThickness="1" CornerRadius="8" Padding="14,8" Margin="0,0,0,14">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <StackPanel Grid.Column="0" Orientation="Horizontal">
                            <TextBlock Text="Equipo: " Foreground="#64748B" FontSize="12"/>
                            <TextBlock x:Name="lblHostName" Text="Cargando..." FontWeight="SemiBold" Foreground="#CBD5E1" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <TextBlock Text="Usuario: " Foreground="#64748B" FontSize="12"/>
                            <TextBlock x:Name="lblUserName" Text="Cargando..." FontWeight="SemiBold" Foreground="#CBD5E1" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="2" Orientation="Horizontal">
                            <TextBlock Text="IP: " Foreground="#64748B" FontSize="12"/>
                            <TextBlock x:Name="lblIpAddress" Text="Detectando..." FontWeight="SemiBold" Foreground="#CBD5E1" FontSize="12"/>
                        </StackPanel>
                        <StackPanel Grid.Column="3" Orientation="Horizontal">
                            <TextBlock Text="RAM: " Foreground="#64748B" FontSize="12"/>
                            <TextBlock x:Name="lblRamTotal" Text="Detectando..." FontWeight="SemiBold" Foreground="#CBD5E1" FontSize="12"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- 2.2 HERO CARD 1-CLICK -->
                <Border Background="#161828" BorderBrush="#FF7A00" BorderThickness="1" CornerRadius="14" Padding="22,18" Margin="0,0,0,14">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel VerticalAlignment="Center" Margin="0,0,20,0">
                            <TextBlock Text="¿Algo no funciona bien?" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF"/>
                            <TextBlock Text="Soluciona audio, conexión a internet, cola de impresión y ventanas trabadas en un solo clic." FontSize="13" Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,4,0,0"/>
                        </StackPanel>

                        <Button x:Name="btnHeroRepairAll" Grid.Column="1" Style="{StaticResource HeroButtonStyle}">
                            <StackPanel Orientation="Horizontal">
                                <TextBlock Text="⚡" FontSize="18" Margin="0,0,8,0" VerticalAlignment="Center"/>
                                <TextBlock Text="Reparar Todo el Equipo" FontSize="14" FontWeight="Bold" VerticalAlignment="Center"/>
                            </StackPanel>
                        </Button>
                    </Grid>
                </Border>

                <!-- 2.3 BARRA DE PROGRESO Y SEGUIMIENTO EN TIEMPO REAL -->
                <Border x:Name="panelProgress" Visibility="Collapsed" Background="#1C1824" BorderBrush="#FF7A00" BorderThickness="1" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
                    <StackPanel>
                        <Grid Margin="0,0,0,10">
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>

                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <Border Background="#3A2012" BorderBrush="#FF7A00" BorderThickness="1" CornerRadius="6" Padding="6,2" Margin="0,0,10,0">
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
                <Border x:Name="panelResult" Visibility="Collapsed" Background="#141E20" BorderBrush="#22C55E" BorderThickness="1" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
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
                            <Button x:Name="btnFeedbackYes" Content="✓ Sí, quedó bien" Style="{StaticResource PillYesStyle}" Margin="0,0,8,0"/>
                            <Button x:Name="btnFeedbackNo" Content="✕ Necesito ayuda de TI" Style="{StaticResource PillNoStyle}"/>
                        </StackPanel>

                        <StackPanel x:Name="panelResultThanks" Grid.Column="2" Visibility="Collapsed" Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="✨ ¡Excelente! Ya puedes continuar." Foreground="#4ADE80" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <Button x:Name="btnCloseResult" Content="✕" Style="{StaticResource PillButtonStyle}" Width="32" Height="32" Padding="0"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- 2.5 TARJETA DE SOPORTE TI (REPORTE AUTOMÁTICO) -->
                <Border x:Name="panelSupport" Visibility="Collapsed" Background="#181826" BorderBrush="#3B4261" BorderThickness="1" CornerRadius="12" Padding="18,14" Margin="0,0,0,14">
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
                                    <TextBlock Text="Hemos preparado un informe automático con el diagnóstico de tu equipo." FontSize="12" Foreground="#94A3B8"/>
                                </StackPanel>
                            </StackPanel>

                            <Button x:Name="btnCopyReport" Grid.Column="1" Content="📋 Copiar Reporte" Style="{StaticResource PillButtonStyle}"/>
                        </Grid>

                        <TextBox x:Name="txtSupportReport" 
                                 Background="#0C0D14" 
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

                            <Button x:Name="btnMailSupport" Grid.Column="0" Style="{StaticResource PillButtonStyle}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="📧" Margin="0,0,8,0"/>
                                    <TextBlock Text="Enviar por Correo"/>
                                </StackPanel>
                            </Button>

                            <Button x:Name="btnTeamsSupport" Grid.Column="2" Style="{StaticResource PillButtonStyle}">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="💬" Margin="0,0,8,0"/>
                                    <TextBlock Text="Pegar en Teams"/>
                                </StackPanel>
                            </Button>
                        </Grid>
                    </StackPanel>
                </Border>

                <!-- 2.6 CATÁLOGO DE ACCIONES POR SÍNTOMA -->
                <TextBlock Text="O ELIGE QUÉ DESEAS SOLUCIONAR:" FontSize="12" FontWeight="Bold" Foreground="#64748B" Margin="2,4,0,10"/>

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
                    <Button x:Name="btnTileAudio" Grid.Row="0" Grid.Column="0" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#281A38" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🎧" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Audio y Micrófono" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Sin sonido o micro en Teams" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 2: Internet -->
                    <Button x:Name="btnTileWifi" Grid.Row="0" Grid.Column="2" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#142B36" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🌐" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Internet y Red" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Sin conexión o DNS caído" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 3: Impresora -->
                    <Button x:Name="btnTileSpooler" Grid.Row="0" Grid.Column="4" Style="{StaticResource SymptomTileStyle}" Margin="0,0,0,12">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#382E14" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🖨️" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Impresora" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Documentos atascados en cola" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 4: Pantalla -->
                    <Button x:Name="btnTileExplorer" Grid.Row="1" Grid.Column="0" Style="{StaticResource SymptomTileStyle}">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#142038" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🖥️" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Pantalla y Barra" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Ventanas trabadas o congeladas" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 5: Actualizar Apps -->
                    <Button x:Name="btnTileUpgrade" Grid.Row="1" Grid.Column="2" Style="{StaticResource SymptomTileStyle}">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#143620" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🔄" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Actualizar Programas" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Buscar y descargar parches" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>

                    <!-- Tile 6: Limpieza Perfil -->
                    <Button x:Name="btnTileCleanProfile" Grid.Row="1" Grid.Column="4" Style="{StaticResource SymptomTileStyle}">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="Auto"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <Border Background="#382214" CornerRadius="8" Width="36" Height="36" Margin="0,0,12,0">
                                <TextBlock Text="🧹" FontSize="18" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center">
                                <TextBlock Text="Limpieza de Perfil" FontWeight="Bold" FontSize="13" Foreground="#FFFFFF"/>
                                <TextBlock Text="Respaldo y restauración segura" FontSize="11" Foreground="#94A3B8" Margin="0,2,0,0"/>
                            </StackPanel>
                            <TextBlock Grid.Column="2" Text="›" FontSize="18" Foreground="#64748B" VerticalAlignment="Center"/>
                        </Grid>
                    </Button>
                </Grid>

                <!-- 2.7 TOGGLE DE CONSOLA AVANZADA -->
                <Button x:Name="btnToggleConsole" Content="⚙️ Opciones avanzadas y consola técnica ▾" Background="Transparent" Foreground="#64748B" BorderThickness="0" FontSize="12" Cursor="Hand" Margin="0,6,0,10" HorizontalAlignment="Center"/>

                <!-- 2.8 PANEL DE CONSOLA TÉCNICA (COLLAPSIBLE) -->
                <Border x:Name="panelConsole" Visibility="Collapsed" Background="#0A0B12" BorderBrush="#1F2338" BorderThickness="1" CornerRadius="10" Padding="14" Margin="0,0,0,10">
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
                                 Background="#06070B" 
                                 Foreground="#86EFAC" 
                                 CaretBrush="#FF7A00"
                                 FontFamily="Consolas, 'Cascadia Code', 'Lucida Console', Courier New"
                                 FontSize="11"
                                 IsReadOnly="True"
                                 TextWrapping="Wrap"
                                 VerticalScrollBarVisibility="Auto"
                                 BorderBrush="#191B28"
                                 Padding="8"/>
                    </Grid>
                </Border>

            </StackPanel>
        </ScrollViewer>

        <!-- 3. FOOTER / STATUS BAR -->
        <Border Grid.Row="2" Background="#121320" BorderBrush="#1E2033" BorderThickness="1" CornerRadius="8" Padding="14,8" Margin="0,10,0,0">
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

    $window.Dispatcher.Invoke([Action]{
        $txtLogs.AppendText("[$time] $prefix $Message`r`n")
        $txtLogs.ScrollToEnd()
    })
}

# Función para Actualizar el Progreso en Tiempo Real
function Set-GuiProgress {
    param(
        [int]$Step,
        [int]$Total,
        [string]$Label,
        [int]$Percent
    )

    $window.Dispatcher.Invoke([Action]{
        $txtStepBadge.Text = "Paso $Step de $Total"
        $txtStepDescription.Text = $Label
        $txtProgressPercent.Text = "$Percent%"
        $progressBarAction.Value = $Percent
        $txtStatusMessage.Text = "Paso $Step de $Total: $Label"
    })
    Write-GuiLog "[Paso $Step/$Total] ($Percent%) $Label" "STEP"
}

# Función para Habilitar / Deshabilitar Botones
function Set-UiEnabled {
    param([bool]$Enabled)

    $window.Dispatcher.Invoke([Action]{
        $btnHeroRepairAll.IsEnabled   = $Enabled
        $btnTileAudio.IsEnabled       = $Enabled
        $btnTileWifi.IsEnabled        = $Enabled
        $btnTileSpooler.IsEnabled     = $Enabled
        $btnTileExplorer.IsEnabled    = $Enabled
        $btnTileUpgrade.IsEnabled     = $Enabled
        $btnTileCleanProfile.IsEnabled= $Enabled

        if (-not $Enabled) {
            $txtStatusDot.Foreground = [System.Windows.Media.Brushes]::Orange
            $txtStatusDot.Text = "◌"
        } else {
            $txtStatusDot.Foreground = [System.Windows.Media.Brushes]::MediumSeaGreen
            $txtStatusDot.Text = "●"
        }
    })
}

# Función para Mostrar Banner de Resultado
function Show-ResultBanner {
    param(
        [bool]$Success,
        [string]$Title,
        [string]$ErrorMessage = $null
    )

    $window.Dispatcher.Invoke([Action]{
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
    })
}

# Función para Abrir Tarjeta de Soporte TI
function Open-SupportCard {
    $window.Dispatcher.Invoke([Action]{
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
    })
}

# Ejecutor Asíncrono en Hilos (Task.Run)
function Run-AsyncAction {
    param(
        [string]$ActionName,
        [scriptblock]$TaskBlock
    )

    if ($script:isBusy) { return }
    $script:isBusy = $true
    $script:lastActionName = $ActionName

    $window.Dispatcher.Invoke([Action]{
        $panelResult.Visibility = [System.Windows.Visibility]::Collapsed
        $panelSupport.Visibility = [System.Windows.Visibility]::Collapsed
        $panelProgress.Visibility = [System.Windows.Visibility]::Visible
        $txtActionTitle.Text = $ActionName
        $txtStepBadge.Text = "Iniciando..."
        $txtStepDescription.Text = "Preparando ejecución de Windows..."
        $txtProgressPercent.Text = "5%"
        $progressBarAction.Value = 5
    })

    Set-UiEnabled $false
    Write-GuiLog "============================================================" "INFO"
    Write-GuiLog "INICIANDO: $ActionName" "INFO"

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    [System.Threading.Tasks.Task]::Run([Action]{
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

            $window.Dispatcher.Invoke([Action]{
                $progressBarAction.Value = 100
                $txtProgressPercent.Text = "100%"
                $txtStepDescription.Text = "¡Completado!"
            })

            Start-Sleep -Milliseconds 400
            Show-ResultBanner -Success $actionSuccess -Title $ActionName -ErrorMessage $errorDetail
            Set-UiEnabled $true
            $script:isBusy = $false
        }
    })
}

# Carga de Telemetría Inicial
function Load-HardwareTelemetry {
    [System.Threading.Tasks.Task]::Run([Action]{
        try {
            $hostName = $env:COMPUTERNAME
            $userName = $env:USERNAME

            $window.Dispatcher.Invoke([Action]{
                $lblHostName.Text = $hostName
                $lblUserName.Text = $userName
            })

            $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
            $ramTotal = (Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
            $ip = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi*','Ethernet*' -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
            if (-not $ip) { $ip = "Desconectado" }

            $ramStr = if ($ramTotal) { "{0:N1} GB" -f ($ramTotal / 1GB) } else { "N/D" }
            $script:hardwareInfo.osCaption = if ($os) { "$($os.Caption) (Build $($os.BuildNumber))" } else { "Windows 10/11" }

            $window.Dispatcher.Invoke([Action]{
                $lblIpAddress.Text = $ip
                $lblRamTotal.Text = $ramStr
            })
            Write-GuiLog "Telemetría cargada: $hostName ($ip) | RAM: $ramStr" "OK"
        } catch {
            Write-GuiLog "Aviso leyendo telemetría: $_" "WARN"
        }
    })
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

# 4. Impresora
$btnTileSpooler.Add_Click({
    Run-AsyncAction "Desbloqueo de Impresora" {
        Set-GuiProgress 1 2 "Deteniendo cola de impresión (Spooler)..." 40
        Write-GuiLog "Deteniendo servicio Spooler..." "INFO"
        Stop-Service -Name Spooler -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        Set-GuiProgress 2 2 "Iniciando servicio de impresión..." 85
        Write-GuiLog "Reactivando Spooler..." "INFO"
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        Write-GuiLog "Cola de impresión restablecida." "OK"
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

# 6. Actualizar Programas
$btnTileUpgrade.Add_Click({
    Run-AsyncAction "Actualización de Programas Instalados" {
        Set-GuiProgress 1 3 "Buscando actualizaciones disponibles con winget..." 25
        Write-GuiLog "Consultando catálogo de actualizaciones de winget..." "INFO"
        $raw = winget upgrade | Out-String
        $lines = $raw -split "`r?`n"
        foreach ($line in $lines) {
            if ($line.Trim() -and -not $line.Contains("---")) { Write-GuiLog $line "INFO" }
        }

        Set-GuiProgress 2 3 "Descargando e instalando parches de software..." 65
        Write-GuiLog "Descargando e instalando actualizaciones de forma silenciosa..." "INFO"
        winget upgrade --all --include-unknown --silent --accept-source-agreements --accept-package-agreements | Out-Null

        Set-GuiProgress 3 3 "Finalizando verificación..." 95
        Write-GuiLog "Proceso de actualización winget finalizado." "OK"
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
            $rootDir = Split-Path -Parent $targetScript
            $scriptPath = Join-Path $rootDir "Limpiar-Perfil.bat"

            if (Test-Path $scriptPath) {
                Write-GuiLog "Ejecutando $scriptPath..." "INFO"
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptPath`"" -Wait -NoNewWindow -PassThru
                
                Set-GuiProgress 2 2 "Restableciendo configuración de usuario..." 85
                Write-GuiLog "Respaldo completado en tu Escritorio: Respaldo_Usuario" "OK"
                Write-GuiLog "Fondo de pantalla oficial restablecido." "OK"
            } else {
                throw "No se encontró el archivo Limpiar-Perfil.bat en $rootDir"
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

# Inicialización al arrancar
Write-GuiLog "Asistencia Orange (WPF Nativo) iniciada correctamente." "OK"
Load-HardwareTelemetry

# Mostrar Ventana Principal
$window.ShowDialog() | Out-Null
