# Remove NVIDIA duplicate desktop right-click entries (re-added by driver/app updates).
param(
    [switch]$Silent,
    [switch]$Elevated,
    [switch]$CheckOnly
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

    $shellRoots = @(
        'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell',
        'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell'
    )
    foreach ($shellRoot in $shellRoots) {
        if (-not (Test-Path $shellRoot)) { continue }
        Get-ChildItem -LiteralPath $shellRoot -ErrorAction SilentlyContinue |
            Where-Object {
                $n = $_.PSChildName
                if ($n -eq 'Perz_02_NVIDIA') { return $false }
                return ($n -match '^(Nv|NVIDIA)' -or $n -like '*NvCpl*' -or $n -like '*NvApp*')
            } |
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

$removedItems = Remove-NvidiaDesktopHandlers

if ((Test-NvidiaDesktopHandlersPresent) -and -not $Elevated) {
    $self = Join-Path $PSScriptRoot 'System_HideNvidiaDesktopMenu.ps1'
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $self, '-Silent', '-Elevated'
    ) -Wait -WindowStyle Hidden | Out-Null
    $removedItems = @($removedItems + (Remove-NvidiaDesktopHandlers) | Select-Object -Unique)
}

$result = [PSCustomObject]@{
    Removed      = $removedItems
    StillPresent = (Test-NvidiaDesktopHandlersPresent)
}

if ($result.Removed.Count -gt 0 -and -not $CheckOnly) {
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
