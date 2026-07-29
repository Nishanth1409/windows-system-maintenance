param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')

$skipped = 0
$freed = [long]0
$null = Enable-ClipboardHistory

# Windows temp/prefetch plus the designated D:\Cache folder.
Invoke-MaintenanceStandardCleanup -Skipped ([ref]$skipped) -Freed ([ref]$freed)

try { Clear-RecycleBin -Force -ErrorAction Stop }
catch { $skipped++ }

if (-not $Silent) {
    $localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
    $freedText = if ($freed -gt 0) {
        "`n`nD: cache removed: $([math]::Round($freed / 1MB, 1)) MB"
    } else { '' }
    $msg = "Quick clean finished.`n`nCleared:`n  - $localTemp`n  - %TEMP% and Windows\Temp`n  - Prefetch (if not locked)`n  - D:\Cache contents only`n  - Recycle bin`n`nProtected: Movies, Games, STUDIS, Projects, and personal data.$freedText`n`nFiles in use by open apps are skipped.`nClipboard history (Win+V) was NOT touched."
    if ($skipped -gt 0) { $msg += "`n`nSome locked temp files were skipped." }

    [System.Windows.Forms.MessageBox]::Show(
        $msg, 'System Maintenance', 'OK', 'Information'
    ) | Out-Null
}
