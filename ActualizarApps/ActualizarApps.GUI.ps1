Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Logica de winget (misma que la version de consola) ---

function Get-PendingUpgrades {
    $raw = winget upgrade --include-unknown | Out-String
    $lines = $raw -split "`r?`n"

    $headerIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\s+Version') { $headerIndex = $i; break }
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
            $apps += [PSCustomObject]@{ Name = $name; Id = $id; Version = $version; Available = $available; Source = $source }
        }
    }
    return ,$apps
}

function Invoke-WingetUpgrade {
    param([string]$Id, [string]$Source, [int]$TimeoutSeconds = 300)

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "winget"
    $psi.Arguments = "upgrade --id `"$Id`" --source `"$Source`" --silent --include-unknown --disable-interactivity --accept-package-agreements --accept-source-agreements"
    $psi.UseShellExecute = $false

    $proc = [System.Diagnostics.Process]::Start($psi)
    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)

    if (-not $finished) {
        try { $proc.Kill() } catch {}
        return [PSCustomObject]@{ Code = -1; TimedOut = $true }
    }
    return [PSCustomObject]@{ Code = $proc.ExitCode; TimedOut = $false }
}

# --- Ventana ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Actualizador de Aplicaciones"
$form.Size = New-Object System.Drawing.Size(720, 560)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(600, 420)
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$listView = New-Object System.Windows.Forms.ListView
$listView.View = 'Details'
$listView.FullRowSelect = $true
$listView.GridLines = $true
$listView.Location = New-Object System.Drawing.Point(12, 12)
$listView.Size = New-Object System.Drawing.Size(680, 240)
$listView.Anchor = 'Top,Bottom,Left,Right'
$listView.Columns.Add("Aplicacion", 260) | Out-Null
$listView.Columns.Add("Actual", 110) | Out-Null
$listView.Columns.Add("Disponible", 110) | Out-Null
$listView.Columns.Add("Estado", 170) | Out-Null
$form.Controls.Add($listView)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(12, 262)
$progressBar.Size = New-Object System.Drawing.Size(680, 18)
$progressBar.Anchor = 'Top,Left,Right'
$form.Controls.Add($progressBar)

$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Multiline = $true
$logBox.ReadOnly = $true
$logBox.ScrollBars = 'Vertical'
$logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$logBox.Location = New-Object System.Drawing.Point(12, 288)
$logBox.Size = New-Object System.Drawing.Size(680, 150)
$logBox.Anchor = 'Top,Bottom,Left,Right'
$form.Controls.Add($logBox)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "Listo."
$statusLabel.Location = New-Object System.Drawing.Point(12, 448)
$statusLabel.Size = New-Object System.Drawing.Size(680, 20)
$statusLabel.Anchor = 'Bottom,Left,Right'
$form.Controls.Add($statusLabel)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Buscar y actualizar todo"
$btnStart.Location = New-Object System.Drawing.Point(12, 476)
$btnStart.Size = New-Object System.Drawing.Size(200, 32)
$btnStart.Anchor = 'Bottom,Left'
$form.Controls.Add($btnStart)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Cerrar"
$btnClose.Location = New-Object System.Drawing.Point(612, 476)
$btnClose.Size = New-Object System.Drawing.Size(80, 32)
$btnClose.Anchor = 'Bottom,Right'
$btnClose.Add_Click({ $form.Close() })
$form.Controls.Add($btnClose)

function Add-LogLine([string]$Text) {
    $logBox.AppendText("$Text`r`n")
}

# --- Trabajo en segundo plano (no congela la ventana) ---

$worker = New-Object System.ComponentModel.BackgroundWorker
$worker.WorkerReportsProgress = $true

$worker.Add_DoWork({
    param($sender, $e)

    $sender.ReportProgress(0, [PSCustomObject]@{ Type = "Status"; Text = "Actualizando fuentes de winget..." })
    winget source update | Out-Null

    $sender.ReportProgress(0, [PSCustomObject]@{ Type = "Status"; Text = "Buscando actualizaciones pendientes..." })
    $apps = Get-PendingUpgrades
    $sender.ReportProgress(0, [PSCustomObject]@{ Type = "ScanDone"; Apps = $apps })

    if ($apps.Count -eq 0) {
        $sender.ReportProgress(100, [PSCustomObject]@{ Type = "Finished"; Ok = 0; Fail = 0; Total = 0 })
        return
    }

    $total = $apps.Count
    $index = 0
    $ok = 0
    $fail = 0

    foreach ($app in $apps) {
        $index++
        $sender.ReportProgress([int]((($index - 1) / $total) * 100), [PSCustomObject]@{ Type = "AppStart"; Name = $app.Name })

        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $result = Invoke-WingetUpgrade -Id $app.Id -Source $app.Source -TimeoutSeconds 300
        $sw.Stop()

        $success = (-not $result.TimedOut -and $result.Code -eq 0)
        if ($success) { $ok++ } else { $fail++ }

        $sender.ReportProgress([int](($index / $total) * 100), [PSCustomObject]@{
            Type     = "AppDone"
            Name     = $app.Name
            Ok       = $success
            TimedOut = $result.TimedOut
            Code     = $result.Code
            Elapsed  = "{0:mm\:ss}" -f $sw.Elapsed
        })
    }

    $sender.ReportProgress(100, [PSCustomObject]@{ Type = "Finished"; Ok = $ok; Fail = $fail; Total = $total })
})

$worker.Add_ProgressChanged({
    param($sender, $e)
    $info = $e.UserState
    $progressBar.Value = [Math]::Min([Math]::Max($e.ProgressPercentage, 0), 100)

    switch ($info.Type) {
        "Status" {
            $statusLabel.Text = $info.Text
            Add-LogLine $info.Text
        }
        "ScanDone" {
            $listView.Items.Clear()
            foreach ($app in $info.Apps) {
                $item = New-Object System.Windows.Forms.ListViewItem($app.Name)
                $item.SubItems.Add($app.Version) | Out-Null
                $item.SubItems.Add($app.Available) | Out-Null
                $item.SubItems.Add("Pendiente") | Out-Null
                $listView.Items.Add($item) | Out-Null
            }
            if ($info.Apps.Count -eq 0) {
                $statusLabel.Text = "No hay aplicaciones pendientes de actualizar."
                Add-LogLine "No hay aplicaciones pendientes de actualizar."
            } else {
                $statusLabel.Text = "Se encontraron $($info.Apps.Count) aplicacion(es) pendiente(s)."
                Add-LogLine "Se encontraron $($info.Apps.Count) aplicacion(es) pendiente(s)."
            }
        }
        "AppStart" {
            $statusLabel.Text = "Actualizando: $($info.Name)..."
            foreach ($item in $listView.Items) {
                if ($item.Text -eq $info.Name) { $item.SubItems[3].Text = "Actualizando..."; break }
            }
        }
        "AppDone" {
            $reason = if ($info.TimedOut) { "Sin respuesta ($($info.Elapsed))" } elseif ($info.Ok) { "Actualizado ($($info.Elapsed))" } else { "Error codigo $($info.Code)" }
            foreach ($item in $listView.Items) {
                if ($item.Text -eq $info.Name) {
                    $item.SubItems[3].Text = $reason
                    $item.ForeColor = if ($info.Ok) { [System.Drawing.Color]::DarkGreen } elseif ($info.TimedOut) { [System.Drawing.Color]::DarkOrange } else { [System.Drawing.Color]::DarkRed }
                    break
                }
            }
            Add-LogLine "$($info.Name): $reason"
        }
        "Finished" {
            $btnStart.Enabled = $true
            if ($info.Total -eq 0) {
                $statusLabel.Text = "Listo - no habia nada pendiente."
            } elseif ($info.Fail -eq 0) {
                $statusLabel.Text = "Listo - $($info.Ok) aplicacion(es) actualizada(s)."
            } else {
                $statusLabel.Text = "Terminado con avisos - $($info.Fail) de $($info.Total) fallaron."
            }
            Add-LogLine "-----------------------------"
            Add-LogLine $statusLabel.Text
        }
    }
})

$btnStart.Add_Click({
    $btnStart.Enabled = $false
    $listView.Items.Clear()
    $logBox.Clear()
    $progressBar.Value = 0
    $statusLabel.Text = "Iniciando..."
    $worker.RunWorkerAsync()
})

[void]$form.ShowDialog()
