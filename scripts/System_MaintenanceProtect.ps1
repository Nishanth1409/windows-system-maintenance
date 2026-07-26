# Paths and settings maintenance must never change (clipboard history, etc.)

function Get-ProtectedMaintenancePaths {
    return @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Clipboard')
    )
}

function Test-ProtectedMaintenancePath {
    param([string]$Path)

    if (-not $Path) { return $false }
    try {
        $normalized = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    } catch {
        return $false
    }

    foreach ($protected in Get-ProtectedMaintenancePaths) {
        if (-not (Test-Path $protected)) {
            $prot = $protected.TrimEnd('\')
        } else {
            $prot = [System.IO.Path]::GetFullPath($protected).TrimEnd('\')
        }
        if ($normalized -eq $prot -or $normalized.StartsWith($prot + '\', [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Clear-MaintenanceFolderContents {
    param(
        [string]$Folder,
        [ref]$Skipped
    )

    if (-not $Folder) { return }
    if (Test-ProtectedMaintenancePath $Folder) { return }
    if (-not (Test-Path $Folder)) { return }

    Get-ChildItem $Folder -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (Test-ProtectedMaintenancePath $_.FullName) { return }
        try {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
        } catch {
            if ($Skipped) { $Skipped.Value++ }
        }
    }
}

function Get-MaintenanceTempFolders {
    $paths = @(
        $env:TEMP
        (Join-Path $env:LOCALAPPDATA 'Temp')
        (Join-Path $env:WINDIR 'Temp')
    )

    $unique = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $paths) {
        if (-not $path) { continue }
        try {
            $resolved = [System.IO.Path]::GetFullPath($path).TrimEnd('\')
            [void]$unique.Add($resolved)
        } catch { }
    }
    return @($unique)
}

function Invoke-MaintenanceTempCleanup {
    param([ref]$Skipped)

    foreach ($folder in (Get-MaintenanceTempFolders)) {
        Clear-MaintenanceFolderContents -Folder $folder -Skipped $Skipped
    }

    Start-Sleep -Seconds 1
    foreach ($folder in (Get-MaintenanceTempFolders)) {
        Clear-MaintenanceFolderContents -Folder $folder -Skipped $Skipped
    }
}

function Invoke-MaintenancePrefetchCleanup {
    param([ref]$Skipped)

    Clear-MaintenanceFolderContents -Folder "$env:WINDIR\Prefetch" -Skipped $Skipped
}

function Invoke-MaintenanceStandardCleanup {
    param([ref]$Skipped)

    Invoke-MaintenanceTempCleanup -Skipped $Skipped
    Invoke-MaintenancePrefetchCleanup -Skipped $Skipped
}

function Ensure-ClipboardHistoryEnabled {
    # Keep Win+V history on disk — user clears manually in Clipboard UI only.
    $key = 'HKCU:\Software\Microsoft\Clipboard'
    if (-not (Test-Path $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    $current = (Get-ItemProperty -Path $key -Name EnableClipboardHistory -ErrorAction SilentlyContinue).EnableClipboardHistory
    if ($current -ne 1) {
        Set-ItemProperty -Path $key -Name EnableClipboardHistory -Value 1 -Type DWord -Force
        return $true
    }
    return $false
}
