param(
    [ValidateSet('Quick', 'Deep', 'Admin')]
    [string]$Level = 'Quick',
    [switch]$Silent,
    [switch]$ShowProgress,
    [switch]$NoDism
)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')

$script:freed = [long]0
$script:skipped = 0
$script:removed = [System.Collections.Generic.List[string]]::new()

function Write-Step {
    param([string]$Message)
    if ($ShowProgress) { Write-Host "  -> $Message" }
}

function Remove-SafePath {
    param([string]$Path, [string]$Label = '')
    if (Test-ProtectedMaintenancePath $Path) { return }
    if (-not (Test-Path $Path)) { return }
    Write-Step $Label
    try {
        $item = Get-Item $Path -Force -ErrorAction Stop
        if (-not $item.PSIsContainer) { $script:freed += [long]$item.Length }
        Remove-Item $Path -Recurse -Force -ErrorAction Stop
        if ($Label) { $script:removed.Add($Label) | Out-Null }
    } catch { $script:skipped++ }
}

function Clear-FolderContents {
    param([string]$Folder, [string]$Label = '')
    if (Test-ProtectedMaintenancePath $Folder) { return }
    if (-not (Test-Path $Folder)) { return }
    Write-Step $Label
    $cleared = $false
    foreach ($item in (Get-ChildItem $Folder -Force -ErrorAction SilentlyContinue)) {
        if (Test-ProtectedMaintenancePath $item.FullName) { continue }
        try {
            if (-not $item.PSIsContainer) { $script:freed += [long]$item.Length }
            Remove-Item $item.FullName -Recurse -Force -ErrorAction Stop
            $cleared = $true
        } catch { $script:skipped++ }
    }
    if ($cleared -and $Label) { $script:removed.Add($Label) | Out-Null }
}

function Clear-OldLogFiles {
    param([string]$Folder, [int]$DaysOld = 60)
    if (-not (Test-Path $Folder)) { return }
    $cutoff = (Get-Date).AddDays(-$DaysOld)
    Get-ChildItem $Folder -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            try {
                $script:freed += $_.Length
                Remove-Item $_.FullName -Force -ErrorAction Stop
            } catch { $script:skipped++ }
        }
}

# Quick = intentionally empty — weekly clean uses System_QuickClean.ps1

if ($Level -in @('Deep', 'Admin')) {
    Invoke-MaintenanceStandardCleanup -Skipped ([ref]$script:skipped) -Freed ([ref]$script:freed)
    Invoke-MaintenanceDataDriveDeepCacheCleanup -Skipped ([ref]$script:skipped) -Freed ([ref]$script:freed)
    $script:removed.Add("Temp folders ($([System.IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Temp'))), Windows\Temp)") | Out-Null
    $script:removed.Add('Prefetch') | Out-Null
    $script:removed.Add('D: cache only (D:\Cache, pnpm store, generated project caches)') | Out-Null

    $upgradeLeftovers = @(
        'C:\$WINDOWS.~BT', 'C:\$Windows.~WS', 'C:\$GetCurrent', 'C:\ESD'
    )
    foreach ($path in $upgradeLeftovers) {
        if (Test-Path $path) { Remove-SafePath $path 'Windows upgrade leftover' }
    }

    $winOld = 'C:\Windows.old'
    if ((Test-Path $winOld) -and (((Get-Date) - (Get-Item $winOld -Force).LastWriteTime).TotalDays -ge 14)) {
        Remove-SafePath $winOld 'Old Windows install (Windows.old)'
    }

    Clear-OldLogFiles "$env:WINDIR\Logs\CBS" 60
    Clear-OldLogFiles "$env:WINDIR\Logs\DISM" 60

    foreach ($log in @('C:\DumpStack.log', 'C:\DumpStack.log.tmp')) {
        if (Test-Path $log) { Remove-SafePath $log 'Dump stack log' }
    }

    # NEVER delete SoftwareDistribution\Download, thumb/icon cache, or INetCache —
    # that slows Windows Update, winget installs, and File Explorer.
}

if ($Level -eq 'Admin') {
    Clear-FolderContents "$env:WINDIR\Minidump" 'Crash minidumps'
    Clear-FolderContents "$env:WINDIR\LiveKernelReports" 'Kernel crash reports'
    if (Test-Path 'C:\Config.Msi') { Remove-SafePath 'C:\Config.Msi' 'Failed installer cache' }

    if (-not $NoDism) {
        Write-Step 'DISM component cleanup (manual step in Admin.bat when -NoDism not set)'
    }
}

$result = [PSCustomObject]@{
    Freed   = $script:freed
    Skipped = $script:skipped
    Level   = $Level
    Items   = $script:removed
}

if (-not $Silent) {
    $mb = [math]::Round($script:freed / 1MB, 1)
    $summary = if ($script:removed.Count -gt 0) {
        ($script:removed | Select-Object -Unique | ForEach-Object { "  - $_" }) -join "`n"
    } else { '  (nothing to remove)' }

    $msg = if ($mb -lt 0.1) {
        "Cleanup finished.`n`nSystem is already clean.`n`nChecked:`n$summary"
    } else {
        "Cleanup finished.`n`nRemoved approx. $mb MB.`n$summary"
    }

    [System.Windows.Forms.MessageBox]::Show($msg, 'System Maintenance', 'OK', 'Information') | Out-Null
}

return $result
