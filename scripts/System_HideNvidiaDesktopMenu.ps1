# Remove NVIDIA duplicate desktop right-click entries (re-added by driver/app updates).
param(
    [switch]$Silent,
    [switch]$Elevated,
    [switch]$CheckOnly,
    [switch]$NoExplorerRestart
)

$handlerNames = @(
    'NvCplDesktopContext',
    'NvAppDesktopContext',
    'NvGpuShExtDesktopContext'
)

$handlerRoots = @(
    'Registry::HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers',
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\shellex\ContextMenuHandlers',
    'HKLM:\SOFTWARE\Classes\Directory\Background\shellex\ContextMenuHandlers',
    'HKLM:\SOFTWARE\Classes\DesktopBackground\shellex\ContextMenuHandlers'
)

$shellRoots = @(
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell',
    'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell'
)

function Test-NvidiaShellEntry {
    param([string]$Name)

    if ($Name -eq 'Perz_02_NVIDIA') { return $false }
    return ($Name -match '^(Nv|NVIDIA)' -or $Name -like '*NvCpl*' -or $Name -like '*NvApp*')
}

# Snapshot of every entry this script would delete, so the caller can diff
# before/after. The elevated pass runs in a child process, so counting
# deletions inline under-reports whenever elevation was required.
function Get-NvidiaDesktopEntries {
    $found = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $handlerRoots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like 'Nv*' -and $_.PSChildName -notlike '*.disabled' } |
            ForEach-Object { $found.Add(($root -replace '.*\\', '') + '\' + $_.PSChildName) | Out-Null }
    }

    foreach ($shellRoot in $shellRoots) {
        if (-not (Test-Path $shellRoot)) { continue }
        Get-ChildItem -LiteralPath $shellRoot -ErrorAction SilentlyContinue |
            Where-Object { Test-NvidiaShellEntry $_.PSChildName } |
            ForEach-Object { $found.Add('Shell\' + $_.PSChildName) | Out-Null }
    }

    return @($found | Select-Object -Unique)
}

function Test-NvidiaDesktopHandlersPresent {
    foreach ($root in $handlerRoots) {
        if (-not (Test-Path $root)) { continue }
        foreach ($name in $handlerNames) {
            if (Test-Path (Join-Path $root $name)) { return $true }
        }
        $extra = Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like 'Nv*' -and $_.PSChildName -notlike '*.disabled' }
        if ($extra) { return $true }
    }
    return $false
}

function Remove-NvidiaDesktopHandlers {
    $removed = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $handlerRoots) {
        if (-not (Test-Path $root)) { continue }

        foreach ($name in $handlerNames) {
            $path = Join-Path $root $name
            if (-not (Test-Path $path)) { continue }
            try {
                Remove-Item -LiteralPath $path -Force -Recurse -ErrorAction Stop
                $removed.Add(($root -replace '.*\\', '') + '\' + $name) | Out-Null
            } catch { }
        }

        Get-ChildItem -LiteralPath $root -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -like 'Nv*' -and $_.PSChildName -notlike '*.disabled' } |
            ForEach-Object {
                if ($handlerNames -contains $_.PSChildName) { return }
                try {
                    Remove-Item -LiteralPath $_.PSPath -Force -Recurse -ErrorAction Stop
                    $removed.Add(($root -replace '.*\\', '') + '\' + $_.PSChildName) | Out-Null
                } catch { }
            }
    }

    foreach ($shellRoot in $shellRoots) {
        if (-not (Test-Path $shellRoot)) { continue }
        Get-ChildItem -LiteralPath $shellRoot -ErrorAction SilentlyContinue |
            Where-Object { Test-NvidiaShellEntry $_.PSChildName } |
            ForEach-Object {
                try {
                    Remove-Item -LiteralPath $_.PSPath -Force -Recurse -ErrorAction Stop
                    $removed.Add('Shell\' + $_.PSChildName) | Out-Null
                } catch { }
            }
    }

    return @($removed | Select-Object -Unique)
}

if ($CheckOnly) {
    return [PSCustomObject]@{
        Removed      = @()
        StillPresent = (Test-NvidiaDesktopHandlersPresent)
    }
}

$before = Get-NvidiaDesktopEntries

Remove-NvidiaDesktopHandlers | Out-Null

if ((Test-NvidiaDesktopHandlersPresent) -and -not $Elevated) {
    $self = Join-Path $PSScriptRoot 'System_HideNvidiaDesktopMenu.ps1'
    # The child runs as admin in its own session context; this process owns the
    # single Explorer restart once the diff below is known.
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self,
        '-Silent', '-Elevated', '-NoExplorerRestart'
    ) -Wait -WindowStyle Hidden | Out-Null
    Remove-NvidiaDesktopHandlers | Out-Null
}

$after = Get-NvidiaDesktopEntries
$removedItems = @($before | Where-Object { $after -notcontains $_ })

$result = [PSCustomObject]@{
    Removed      = $removedItems
    StillPresent = (Test-NvidiaDesktopHandlersPresent)
}

if ($result.Removed.Count -gt 0 -and -not $NoExplorerRestart) {
    . (Join-Path $PSScriptRoot 'System_RestartExplorerCore.ps1')
    Restart-ExplorerSafe -WaitSeconds 4 | Out-Null
}

if (-not $Silent -and $result.Removed.Count -gt 0) {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
    $list = ($result.Removed | ForEach-Object { "  - $_" }) -join "`n"
    [System.Windows.Forms.MessageBox]::Show(
        "Removed NVIDIA duplicate desktop menu entries:`n`n$list`n`nUse desktop menu: NVIDIA submenu only.",
        'System Maintenance',
        'OK',
        'Information'
    ) | Out-Null
}

return $result
