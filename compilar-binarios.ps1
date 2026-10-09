<#
.SYNOPSIS
    Compilador de binarios ejecutables (.exe) para todas las herramientas de Orange Latam.
#>

[CmdletBinding()]
param()

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "    COMPILADOR DE BINARIOS EJECUTABLES (.EXE)" -ForegroundColor Yellow
Write-Host "==================================================" -ForegroundColor Cyan

# Asegurar modulo ps2exe
if (-not (Get-Module -ListAvailable ps2exe)) {
    Write-Host "[*] Instalando modulo ps2exe..." -ForegroundColor Gray
    Install-Module -Name ps2exe -Scope CurrentUser -Force -SkipPublisherCheck
}
Import-Module ps2exe -Force

# 1. Asistencia Orange (Portal de Auto-Atencion WPF)
$srcPortal = Join-Path $root "AsistenciaOrange.ps1"
$outPortal = Join-Path $root "AsistenciaOrange.exe"
if (Test-Path $srcPortal) {
    Write-Host "`n[1/3] Compilando AsistenciaOrange.exe..." -ForegroundColor Green
    Invoke-ps2exe -inputFile $srcPortal -outputFile $outPortal -noConsole -requireAdmin -sta `
        -title "Asistencia Orange" -description "Centro de Auto-Atencion y Reparacion Rapida" `
        -company "Orange Latam" -product "Asistencia Orange" -version "1.1.0.0"
}

# 2. Utilidad Orange Latam (GUI de Soporte TI WPF)
$srcUtil = Join-Path $root "utilities\UtilidadOrangeLatam.GUI.ps1"
$outUtil = Join-Path $root "utilities\UtilidadOrangeLatam.exe"
if (Test-Path $srcUtil) {
    Write-Host "`n[2/3] Compilando utilities\UtilidadOrangeLatam.exe..." -ForegroundColor Green
    Invoke-ps2exe -inputFile $srcUtil -outputFile $outUtil -noConsole -requireAdmin -sta `
        -title "Utilidades Orange Latam" -description "Herramientas de Mantenimiento y Diagnostico TI" `
        -company "Orange Latam" -product "Utilidades Orange" -version "1.1.0.0"
}

# 3. Actualizador de Aplicaciones (Winget CLI)
$srcUpdate = Join-Path $root "ActualizarApps\updateScripts.ps1"
$outUpdate = Join-Path $root "ActualizarApps\ActualizarApps.exe"
if (Test-Path $srcUpdate) {
    Write-Host "`n[3/3] Compilando ActualizarApps\ActualizarApps.exe..." -ForegroundColor Green
    Invoke-ps2exe -inputFile $srcUpdate -outputFile $outUpdate -requireAdmin `
        -title "Actualizador de Aplicaciones" -description "Actualiza todas las aplicaciones instaladas via winget" `
        -company "Orange Latam" -version "1.1.0.0"
}

Write-Host "`n[OK] Compilacion finalizada exitosamente." -ForegroundColor Cyan
Write-Host "Binarios generados:" -ForegroundColor Gray
Write-Host " - $outPortal" -ForegroundColor White
Write-Host " - $outUtil" -ForegroundColor White
Write-Host " - $outUpdate" -ForegroundColor White
