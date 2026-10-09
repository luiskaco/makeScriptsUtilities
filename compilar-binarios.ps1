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

# Helper para cerrar procesos previos si estuvieran abiertos
function Prepare-OutputFile {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        $procName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
        Get-Process -Name $procName -ErrorAction SilentlyContinue | ForEach-Object {
            try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
        }
        Start-Sleep -Milliseconds 300
    }
}

# 1. Asistencia Orange (Portal de Auto-Atencion WPF)
$srcPortal = Join-Path $root "AsistenciaOrange.ps1"
$outPortal = Join-Path $root "AsistenciaOrange.exe"
if (Test-Path $srcPortal) {
    Write-Host "`n[1/3] Compilando AsistenciaOrange.exe..." -ForegroundColor Green
    Prepare-OutputFile $outPortal
    try {
        Invoke-ps2exe -inputFile $srcPortal -outputFile $outPortal -noConsole -requireAdmin -sta `
            -title "Asistencia Orange" -description "Centro de Auto-Atencion y Reparacion Rapida" `
            -company "Orange Latam" -product "Asistencia Orange" -version "1.1.0.0"
    } catch {
        Write-Host "  [!] Si AsistenciaOrange.exe esta abierto en pantalla, cierralo para permitir sobreescribir el binario." -ForegroundColor Yellow
    }
}

# 2. Utilidad Orange Latam (GUI de Soporte TI WPF)
$srcUtil = Join-Path $root "utilities\UtilidadOrangeLatam.GUI.ps1"
$outUtil = Join-Path $root "utilities\UtilidadOrangeLatam.exe"
if (Test-Path $srcUtil) {
    Write-Host "`n[2/3] Compilando utilities\UtilidadOrangeLatam.exe..." -ForegroundColor Green
    Prepare-OutputFile $outUtil
    try {
        Invoke-ps2exe -inputFile $srcUtil -outputFile $outUtil -noConsole -requireAdmin -sta `
            -title "Utilidades Orange Latam" -description "Herramientas de Mantenimiento y Diagnostico TI" `
            -company "Orange Latam" -product "Utilidades Orange" -version "1.1.0.0"
    } catch {
        Write-Host "  [!] Si UtilidadOrangeLatam.exe esta abierto en pantalla, cierralo para permitir sobreescribir el binario." -ForegroundColor Yellow
    }
}

# 3. Actualizador de Aplicaciones (Winget CLI)
$srcUpdate = Join-Path $root "ActualizarApps\updateScripts.ps1"
$outUpdate = Join-Path $root "ActualizarApps\ActualizarApps.exe"
if (Test-Path $srcUpdate) {
    Write-Host "`n[3/3] Compilando ActualizarApps\ActualizarApps.exe..." -ForegroundColor Green
    Prepare-OutputFile $outUpdate
    Invoke-ps2exe -inputFile $srcUpdate -outputFile $outUpdate -requireAdmin `
        -title "Actualizador de Aplicaciones" -description "Actualiza todas las aplicaciones instaladas via winget" `
        -company "Orange Latam" -version "1.1.0.0"
}

Write-Host "`n[OK] Proceso de compilacion finalizado." -ForegroundColor Cyan
Write-Host "Binarios disponibles:" -ForegroundColor Gray
Write-Host " - $outPortal" -ForegroundColor White
Write-Host " - $outUtil" -ForegroundColor White
Write-Host " - $outUpdate" -ForegroundColor White
