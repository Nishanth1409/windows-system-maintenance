Add-Type -AssemblyName System.Windows.Forms

. (Join-Path $PSScriptRoot 'System_WingetHelpers.ps1')
. (Join-Path $PSScriptRoot 'System_MaintenanceProtect.ps1')
$null = Enable-ClipboardHistory

Write-Host "=== USER MAINTENANCE ===" -ForegroundColor Cyan

Write-Host "=== USER APP UPDATES ===" -ForegroundColor Cyan
& "$PSScriptRoot\System_WingetUser.ps1" -Silent | Out-Null

Write-Host "=== USER TEMP CLEANUP ===" -ForegroundColor Cyan
& "$PSScriptRoot\System_QuickClean.ps1" -Silent 2>$null

Write-Host "=== USER TASKS COMPLETED ===" -ForegroundColor Green

[System.Windows.Forms.MessageBox]::Show(
    "User maintenance finished.`n`n  - Cleanup (Windows temp, prefetch, D:\Cache, recycle bin)`n  - User-scope app updates (winget)`n  - Personal data on D: was not touched`n`nSpotify + Spicetify: use System Maintenance → As needed → Update Spotify + Spicetify",
    'System Maintenance', 'OK', 'Information'
) | Out-Null
