# Paths and settings maintenance must never change (clipboard history,
# File Explorer view/sort/group profile, etc.)

. (Join-Path $PSScriptRoot 'System_ExplorerViewProfile.ps1')

function Get-ProtectedMaintenancePaths {
    return @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Clipboard'),
        # Explorer's own state folder: icon/thumb cache and view data live here.
        # Deleting it makes Explorer rebuild views and re-read folder layouts.
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\UsrClass.dat'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\UsrClass.dat.LOG1'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\UsrClass.dat.LOG2')
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
        [ref]$Skipped,
        [ref]$Freed
    )

    if (-not $Folder) { return }
    if (Test-ProtectedMaintenancePath $Folder) { return }
    if (-not (Test-Path $Folder)) { return }

    Get-ChildItem $Folder -Force -ErrorAction SilentlyContinue | ForEach-Object {
        if (Test-ProtectedMaintenancePath $_.FullName) { return }
        try {
            $bytes = if ($_.PSIsContainer) {
                (Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
            } else {
                $_.Length
            }
            Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop
            if ($Freed -and $bytes) { $Freed.Value += [long]$bytes }
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

function Invoke-MaintenanceDataDriveCacheCleanup {
    param(
        [ref]$Skipped,
        [ref]$Freed
    )

    # D:\Cache is the designated transient-data folder. Keep the root itself,
    # but clear its contents. Never scan or infer other D: folders here.
    Clear-MaintenanceFolderContents -Folder 'D:\Cache' -Skipped $Skipped -Freed $Freed
}

function Invoke-MaintenanceDataDriveDeepCacheCleanup {
    param(
        [ref]$Skipped,
        [ref]$Freed
    )

    # pnpm's content-addressed store is disposable package cache. Packages are
    # downloaded again if needed; project files and node_modules are untouched.
    Clear-MaintenanceFolderContents -Folder 'D:\.pnpm-store' -Skipped $Skipped -Freed $Freed

    $projectsRoot = 'D:\Projects'
    if (-not (Test-Path $projectsRoot)) { return }

    # Strict allowlist of generated caches only. Explicitly skip dependency,
    # environment, and Git trees; do not remove .next itself, dist, or build.
    $cacheNames = @(
        '__pycache__',
        '.pytest_cache',
        '.mypy_cache',
        '.ruff_cache',
        '.turbo',
        '.cache'
    )
    $cacheFolders = [System.Collections.Generic.List[System.IO.DirectoryInfo]]::new()
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($projectsRoot)
    $excludedNames = @('node_modules', '.git', '.venv', 'venv')

    while ($pending.Count -gt 0) {
        $parent = $pending.Pop()
        foreach ($folder in (Get-ChildItem $parent -Directory -Force -ErrorAction SilentlyContinue)) {
            if ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { continue }
            if ($excludedNames -contains $folder.Name) { continue }

            $isCache = $cacheNames -contains $folder.Name
            $isNextCache = $folder.Name -eq 'cache' -and $folder.Parent.Name -eq '.next'
            if ($isCache -or $isNextCache) {
                $cacheFolders.Add($folder)
                continue
            }
            $pending.Push($folder.FullName)
        }
    }

    foreach ($folder in $cacheFolders) {
        if (-not (Test-Path -LiteralPath $folder.FullName)) { continue }
        try {
            $bytes = (Get-ChildItem $folder.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
            Remove-Item $folder.FullName -Recurse -Force -ErrorAction Stop
            if ($Freed -and $bytes) { $Freed.Value += [long]$bytes }
        } catch {
            if ($Skipped) { $Skipped.Value++ }
        }
    }
}

function Invoke-MaintenanceStandardCleanup {
    param(
        [ref]$Skipped,
        [ref]$Freed
    )

    Invoke-MaintenanceTempCleanup -Skipped $Skipped
    Invoke-MaintenancePrefetchCleanup -Skipped $Skipped
    Invoke-MaintenanceDataDriveCacheCleanup -Skipped $Skipped -Freed $Freed
    Protect-ExplorerViewSettings | Out-Null
}

function Protect-ExplorerViewSettings {
    # Cleanup must never change how File Explorer sorts, groups, or displays
    # folders. Rewrites the saved profile only if something drifted.
    try {
        return (Restore-ExplorerViewProfile -PassThru)
    } catch {
        return $false
    }
}

function Enable-ClipboardHistory {
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
