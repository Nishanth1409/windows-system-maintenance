# Machine-wide app updates — ADMINISTRATOR only
param(
    [switch]$Silent,
    [switch]$ShowProgress
)

. (Join-Path $PSScriptRoot 'System_WingetHelpers.ps1')

$sessionResult = if ($ShowProgress) {
    Start-WingetUpgradeSession -Scope machine -Elevate -Silent:$false
} else {
    Start-WingetUpgradeSession -Scope machine -Elevate -Silent:$Silent
}

$hideScript = Join-Path $PSScriptRoot 'System_HideNvidiaDesktopMenu.ps1'
if (Test-Path $hideScript) {
    & $hideScript -Silent -Elevated | Out-Null
}

return $sessionResult
