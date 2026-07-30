Add-Type -AssemblyName System.Windows.Forms

. (Join-Path $PSScriptRoot 'System_WingetHelpers.ps1')
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')
. (Join-Path $PSScriptRoot 'System_SpotifySpicetifyCore.ps1')
$null = Enable-ClipboardHistory

Write-Host "=== USER MAINTENANCE ===" -ForegroundColor Cyan

Write-Host "=== USER APP UPDATES ===" -ForegroundColor Cyan
& "$PSScriptRoot\System_WingetUser.ps1" -Silent | Out-Null

Write-Host "=== USER TEMP CLEANUP ===" -ForegroundColor Cyan
& "$PSScriptRoot\System_QuickClean.ps1" -Silent 2>$null

Write-Host "=== SPOTIFY + SPICETIFY (FINAL STEP) ===" -ForegroundColor Cyan
try {
    $spotifySpicetify = Invoke-SpotifySpicetifyFullUpdate -Silent
} catch {
    $spotifySpicetify = [PSCustomObject]@{
        ExitCode = 1
        Notes    = @("Spotify + Spicetify: unexpected failure - $($_.Exception.Message)")
    }
}
$spotifySpicetifySummary = ($spotifySpicetify.Notes | ForEach-Object { '  - ' + $_ }) -join "`n"
$messageIcon = if ($spotifySpicetify.ExitCode -eq 0) { 'Information' } else { 'Warning' }

Write-Host "=== USER TASKS COMPLETED ===" -ForegroundColor Green

[System.Windows.Forms.MessageBox]::Show(
    "User maintenance finished.`n`n  - Cleanup (Windows temp, prefetch, D:\Cache, recycle bin)`n  - User-scope app updates (winget)`n  - Spotify + Spicetify processed last`n  - Personal data on D: was not touched`n`n$spotifySpicetifySummary",
    'System Maintenance', 'OK', $messageIcon
) | Out-Null
