<#
.SYNOPSIS
    Script de Auditoría Completa de Código, Sintaxis, Codificación y Calidad.
#>

$root = $PSScriptRoot
if (-not $root) { $root = Split-Path -Parent $MyInvocation.MyCommand.Path }

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "         AUDITORIA COMPLETA DE CODIGO Y CALIDAD" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$totalFiles = 0
$totalErrors = 0
$utf8Bom = New-Object System.Text.UTF8Encoding($true)

# 1. Auditoría PowerShell
Write-Host "`n[1/4] Auditando Scripts PowerShell (.ps1)..." -ForegroundColor Magenta
$ps1Files = Get-ChildItem -Path $root -Recurse -File -Filter *.ps1 | Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }

foreach ($f in $ps1Files) {
    $totalFiles++
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    
    # Si no tiene BOM, aplicarlo
    if (-not $hasBom) {
        $content = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($f.FullName, $content, $utf8Bom)
        $hasBom = $true
        Write-Host "  -> Aplicado UTF-8 BOM a: $($f.Name)" -ForegroundColor Yellow
    }

    $errs = @()
    $tokens = @()
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    
    if ($errs.Count -eq 0) {
        Write-Host "  [OK] $($f.Name) (BOM: $hasBom | 0 Errores)" -ForegroundColor Green
    } else {
        $totalErrors += $errs.Count
        Write-Host "  [FAIL] $($f.Name) ($($errs.Count) Errores)" -ForegroundColor Red
        foreach ($e in $errs) {
            Write-Host "    Línea $($e.Extent.StartLineNumber): $($e.Message)" -ForegroundColor Red
        }
    }
}

# 2. Auditoría Node.js / JavaScript
Write-Host "`n[2/4] Auditando Archivos JavaScript (.js)..." -ForegroundColor Magenta
$jsFiles = Get-ChildItem -Path $root -Recurse -File -Filter *.js | Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }

foreach ($f in $jsFiles) {
    $totalFiles++
    $check = Start-Process -FilePath "node" -ArgumentList "-c `"$($f.FullName)`"" -NoNewWindow -PassThru -Wait -RedirectStandardError "$root\js_err.tmp"
    $errOutput = if (Test-Path "$root\js_err.tmp") { (Get-Content "$root\js_err.tmp" -Raw) } else { "" }
    Remove-Item "$root\js_err.tmp" -Force -ErrorAction SilentlyContinue

    if ($check.ExitCode -eq 0) {
        Write-Host "  [OK] $($f.Name) (Sintaxis JS válida)" -ForegroundColor Green
    } else {
        $totalErrors++
        Write-Host "  [FAIL] $($f.Name) (Error sintaxis JS)" -ForegroundColor Red
        Write-Host "    $errOutput" -ForegroundColor Red
    }
}

# 3. Auditoría Batch (.bat)
Write-Host "`n[3/4] Auditando Scripts Batch (.bat)..." -ForegroundColor Magenta
$batFiles = Get-ChildItem -Path $root -Recurse -File -Filter *.bat | Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }

foreach ($f in $batFiles) {
    $totalFiles++
    $content = Get-Content $f.FullName -Raw
    $hasUnquotedDpO = ($content -match '%\~dp0[^\"]*\s+[^\"]*')
    if ($hasUnquotedDpO) {
        Write-Host "  [WARN] $($f.Name): Podría tener rutas con espacios no entrecomilladas." -ForegroundColor Yellow
    } else {
        Write-Host "  [OK] $($f.Name)" -ForegroundColor Green
    }
}

# 4. Auditoría de Mapeo XAML en AsistenciaOrange.ps1
Write-Host "`n[4/4] Auditando Mapeo XAML en AsistenciaOrange.ps1..." -ForegroundColor Magenta
$portalPs1 = Join-Path $root "AsistenciaOrange.ps1"
if (Test-Path $portalPs1) {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase -ErrorAction SilentlyContinue
    $rawContent = [System.IO.File]::ReadAllText($portalPs1, [System.Text.Encoding]::UTF8)
    if ($rawContent -match '(?s)\[xml\]\$xaml\s*=\s*@"([\s\S]*?)"@') {
        $xamlXml = [xml]$matches[1]
        $reader = New-Object System.Xml.XmlNodeReader $xamlXml
        $testWin = [System.Windows.Markup.XamlReader]::Load($reader)
        
        # Elementos críticos
        $critElements = @(
            "lblHostName", "lblUserName", "lblIpAddress", "lblRamTotal",
            "btnHeroRepairAll", "btnTileAudio", "btnTileWifi", "btnTileSpooler",
            "btnTileExplorer", "btnTileUpgrade", "btnTileCleanProfile",
            "panelProgress", "txtStepBadge", "txtActionTitle", "txtStepDescription",
            "txtProgressPercent", "progressBarAction", "panelResult", "txtResultIcon",
            "txtResultTitle", "txtResultDesc", "panelResultActions", "panelResultThanks",
            "btnFeedbackYes", "btnFeedbackNo", "btnCloseResult", "panelSupport",
            "txtSupportReport", "btnCopyReport", "btnMailSupport", "btnTeamsSupport",
            "btnToggleConsole", "panelConsole", "txtLogs", "btnCopyLog", "btnClearLog",
            "txtStatusDot", "txtStatusMessage"
        )

        $missing = 0
        foreach ($elem in $critElements) {
            $found = $testWin.FindName($elem)
            if (-not $found) {
                Write-Host "  [FAIL] Control XAML no encontrado: $elem" -ForegroundColor Red
                $missing++
                $totalErrors++
            }
        }
        if ($missing -eq 0) {
            Write-Host "  [OK] Todos los $($critElements.Count) controles XAML mapean al 100%." -ForegroundColor Green
        }
    }
}

Write-Host "`n============================================================" -ForegroundColor Cyan
if ($totalErrors -eq 0) {
    Write-Host "  RESULTADO: 0 ERRORES EN TODOS LOS $totalFiles ARCHIVOS AUDITADOS." -ForegroundColor Green
} else {
    Write-Host "  RESULTADO: SE ENCONTRARON $totalErrors ERRORES." -ForegroundColor Red
}
Write-Host "============================================================" -ForegroundColor Cyan
