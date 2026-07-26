# Per-user app updates — normal USER PowerShell (not admin)
param(
    [switch]$Silent,
    [switch]$ShowProgress
)

. (Join-Path $PSScriptRoot 'System_WingetHelpers.ps1')

if ($ShowProgress) {
    return Start-WingetUpgradeSession -Scope user -Silent:$false
}

return Start-WingetUpgradeSession -Scope user -Silent:$Silent
