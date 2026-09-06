# Protect Logitech Options+ mouse/keyboard settings across cleanup and app updates.
#
# Cleanup never targets these folders today; they are still listed as protected so
# future cleaners cannot wipe them. Update All Apps / Full Maintenance may upgrade
# logioptionsplus.exe - that is allowed - but settings are snapshotted first and
# restored if the upgrade leaves settings.db missing or emptied.

function Get-LogiOptionsRootPaths {
    return @(
        (Join-Path $env:LOCALAPPDATA 'LogiOptionsPlus'),
        (Join-Path $env:APPDATA 'LogiOptionsPlus'),
        (Join-Path $env:ProgramData 'Logishrd\LogiOptionsPlus')
    )
}

function Get-LogiOptionsBackupRoot {
    $dir = Join-Path $env:LOCALAPPDATA 'SystemMaintenance\Backups\LogiOptionsPlus'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return $dir
}

function Get-LogiOptionsSettingFiles {
    $local = Join-Path $env:LOCALAPPDATA 'LogiOptionsPlus'
    $roaming = Join-Path $env:APPDATA 'LogiOptionsPlus'
    $names = @(
        'settings.db', 'settings.db-wal', 'settings.db-shm',
        'macros.db', 'macros.db-wal', 'macros.db-shm',
        'privacy_settings.db', 'privacy_settings.db-wal', 'privacy_settings.db-shm',
        'cc_config.json'
    )
    $files = [System.Collections.Generic.List[string]]::new()
    foreach ($n in $names) {
        $p = Join-Path $local $n
        if (Test-Path -LiteralPath $p) { $files.Add($p) }
    }
    foreach ($n in @('config.json', 'Preferences')) {
        $p = Join-Path $roaming $n
        if (Test-Path -LiteralPath $p) { $files.Add($p) }
    }
    $flow = Join-Path $local 'flow'
    if (Test-Path -LiteralPath $flow) {
        Get-ChildItem -LiteralPath $flow -Recurse -File -ErrorAction SilentlyContinue |
            ForEach-Object { $files.Add($_.FullName) }
    }
    $devio = Join-Path $local 'devio_cache'
    if (Test-Path -LiteralPath $devio) {
        Get-ChildItem -LiteralPath $devio -Filter '*.xml' -File -ErrorAction SilentlyContinue |
            ForEach-Object { $files.Add($_.FullName) }
    }
    return @($files)
}

function Backup-LogiOptionsSettings {
    param(
        [int]$Keep = 10,
        [string]$Reason = 'manual'
    )

    $files = @(Get-LogiOptionsSettingFiles)
    if ($files.Count -eq 0) {
        return [pscustomobject]@{ Ok = $false; Path = $null; FileCount = 0; Note = 'No Logi Options+ settings files found' }
    }

    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $dest = Join-Path (Get-LogiOptionsBackupRoot) ("{0}_{1}" -f $stamp, ($Reason -replace '[^\w\-]', '_'))
    New-Item -ItemType Directory -Path $dest -Force | Out-Null

    $copied = 0
    foreach ($src in $files) {
        try {
            $rel = $src
            $localRoot = Join-Path $env:LOCALAPPDATA 'LogiOptionsPlus'
            $roamRoot = Join-Path $env:APPDATA 'LogiOptionsPlus'
            if ($src.StartsWith($localRoot, [StringComparison]::OrdinalIgnoreCase)) {
                $rel = Join-Path 'Local' $src.Substring($localRoot.Length).TrimStart('\')
            } elseif ($src.StartsWith($roamRoot, [StringComparison]::OrdinalIgnoreCase)) {
                $rel = Join-Path 'Roaming' $src.Substring($roamRoot.Length).TrimStart('\')
            } else {
                $rel = Split-Path $src -Leaf
            }
            $target = Join-Path $dest $rel
            $parent = Split-Path $target -Parent
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            Copy-Item -LiteralPath $src -Destination $target -Force -ErrorAction Stop
            $copied++
        } catch { }
    }

    # Prune oldest backups; never remove the one we just made.
    $backups = @(Get-ChildItem -LiteralPath (Get-LogiOptionsBackupRoot) -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending)
    foreach ($old in ($backups | Select-Object -Skip $Keep)) {
        Remove-Item -LiteralPath $old.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }

    return [pscustomobject]@{
        Ok        = ($copied -gt 0)
        Path      = $dest
        FileCount = $copied
        Note      = "Backed up $copied Logi Options+ settings file(s)"
    }
}

function Get-LatestLogiOptionsBackup {
    Get-ChildItem -LiteralPath (Get-LogiOptionsBackupRoot) -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Test-LogiOptionsSettingsHealthy {
    $settings = Join-Path $env:LOCALAPPDATA 'LogiOptionsPlus\settings.db'
    if (-not (Test-Path -LiteralPath $settings)) { return $false }
    $len = (Get-Item -LiteralPath $settings).Length
    # A real profile DB on this PC is ~400 KB; empty/reset installs are tiny.
    return ($len -ge 32KB)
}

function Restore-LogiOptionsSettingsFromBackup {
    param(
        [string]$BackupPath,
        [switch]$Force
    )

    if (-not $BackupPath) {
        $latest = Get-LatestLogiOptionsBackup
        if (-not $latest) {
            return [pscustomobject]@{ Ok = $false; Note = 'No Logi Options+ backup available' }
        }
        $BackupPath = $latest.FullName
    }
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        return [pscustomobject]@{ Ok = $false; Note = "Backup missing: $BackupPath" }
    }
    if (-not $Force -and (Test-LogiOptionsSettingsHealthy)) {
        return [pscustomobject]@{ Ok = $true; Note = 'Logi Options+ settings already healthy - restore skipped' }
    }

    # Agent can lock settings.db; stop UI/agent briefly for restore only.
    $stopped = @()
    foreach ($name in @('logioptionsplus', 'logioptionsplus_agent', 'logioptionsplus_appbroker')) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Stop-Process -Id $_.Id -Force -ErrorAction Stop
                $stopped += $name
            } catch { }
        }
    }
    if ($stopped.Count -gt 0) { Start-Sleep -Seconds 2 }

    $restored = 0
    $localRoot = Join-Path $env:LOCALAPPDATA 'LogiOptionsPlus'
    $roamRoot = Join-Path $env:APPDATA 'LogiOptionsPlus'
    foreach ($scope in @(@{ Rel = 'Local'; Dest = $localRoot }, @{ Rel = 'Roaming'; Dest = $roamRoot })) {
        $srcRoot = Join-Path $BackupPath $scope.Rel
        if (-not (Test-Path -LiteralPath $srcRoot)) { continue }
        Get-ChildItem -LiteralPath $srcRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
            $rel = $_.FullName.Substring($srcRoot.Length).TrimStart('\')
            $dest = Join-Path $scope.Dest $rel
            $parent = Split-Path $dest -Parent
            if (-not (Test-Path -LiteralPath $parent)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }
            try {
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force -ErrorAction Stop
                $restored++
            } catch { }
        }
    }

    return [pscustomobject]@{
        Ok        = ($restored -gt 0)
        Path      = $BackupPath
        FileCount = $restored
        Note      = "Restored $restored Logi Options+ settings file(s) from backup"
    }
}

function Repair-LogiOptionsSettingsAfterUpdate {
    if (Test-LogiOptionsSettingsHealthy) {
        return [pscustomobject]@{ Ok = $true; Restored = $false; Note = 'Logi Options+ settings intact after update' }
    }
    $result = Restore-LogiOptionsSettingsFromBackup -Force
    return [pscustomobject]@{
        Ok       = $result.Ok
        Restored = $result.Ok
        Note     = $result.Note
        Path     = $result.Path
    }
}
