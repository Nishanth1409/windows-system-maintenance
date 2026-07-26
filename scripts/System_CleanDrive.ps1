Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')

$skipped = 0

Invoke-MaintenanceStandardCleanup -Skipped ([ref]$skipped)

function Remove-SafeFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return }
    try {
        $item = Get-Item $Path -Force
        if ($item.PSIsContainer) { return }
        Remove-Item $Path -Force -ErrorAction Stop
    } catch { $script:skipped++ }
}

# Only loose junk FILES at C:\ root — never delete project/app folders
$rootJunkFiles = @(
    'C:\DeleteFiles.csv', 'C:\PfolderList.txt', 'C:\UnableToDeleteList.csv',
    'C:\DumpStack.log', 'C:\DumpStack.log.tmp', 'C:\END',
    'C:\AVScanner.ini', 'C:\logUploaderSettings.ini', 'C:\logUploaderSettings_temp.ini'
)
foreach ($f in $rootJunkFiles) { Remove-SafeFile $f }

# Deep junk: upgrade leftovers only (monthly)
$junkScript = Join-Path $PSScriptRoot 'System_WindowsJunk.ps1'
if (Test-Path $junkScript) {
    & $junkScript -Level Deep -Silent | Out-Null
}

$extra = if ($skipped -gt 0) { "`n`nSome files were in use and skipped." } else { '' }
$localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
[System.Windows.Forms.MessageBox]::Show(
    "Disk cleanup finished.`n`nCleared:`n  - $localTemp`n  - %TEMP% and Windows\Temp`n  - Prefetch (if not locked)`n  - C:\ root junk files`n  - Upgrade leftovers`n`nWindows Update download cache was kept for speed.$extra`n`nOptional: run cleanmgr manually if you need more space.",
    'System Maintenance', 'OK', 'Information'
) | Out-Null
