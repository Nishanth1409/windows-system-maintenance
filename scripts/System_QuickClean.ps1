param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')

$skipped = 0
$null = Ensure-ClipboardHistoryEnabled

# Temp (%TEMP%, user Temp, Windows\Temp) + Prefetch. Locked files are skipped.
Invoke-MaintenanceStandardCleanup -Skipped ([ref]$skipped)

try { Clear-RecycleBin -Force -ErrorAction Stop }
catch { $skipped++ }

if (-not $Silent) {
    $localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
    $msg = "Quick clean finished.`n`nCleared:`n  - $localTemp`n  - %TEMP% and Windows\Temp`n  - Prefetch (if not locked)`n  - Recycle bin`n`nFiles in use by open apps are skipped.`nClipboard history (Win+V) was NOT touched."
    if ($skipped -gt 0) { $msg += "`n`nSome locked temp files were skipped." }

    [System.Windows.Forms.MessageBox]::Show(
        $msg, 'System Maintenance', 'OK', 'Information'
    ) | Out-Null
}
