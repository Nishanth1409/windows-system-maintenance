# Apply only the OEM-relevant guards for this PC.
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Silent
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'System_OemProfile.ps1')
$oem = Get-SmOemProfile

if (-not $Silent) {
    Write-Host ("OEM family={0} NVIDIA={1} AWCC={2}" -f $oem.Family, $oem.HasNvidia, $oem.ApplyAwccGuards)
}

# NVIDIA duplicate desktop entries — all brands with an NVIDIA GPU.
if ($oem.ApplyNvidiaMenu) {
    $hide = Join-Path $PSScriptRoot 'System_HideNvidiaDesktopMenu.ps1'
    if (Test-Path -LiteralPath $hide) {
        & $hide -Silent -Elevated -NoExplorerRestart | Out-Null
    }
    $guard = Join-Path $PSScriptRoot 'Install_NvidiaMenuGuard.ps1'
    if (Test-Path -LiteralPath $guard) {
        & $guard -TargetRoot $Root -Silent -Elevated | Out-Null
    }
    if (-not $Silent) { Write-Host '  NVIDIA desktop-menu hide + guard: applied' }
} elseif (-not $Silent) {
    Write-Host '  NVIDIA desktop-menu hide: skipped'
}

# Alienware / AWCC only — never touch ASUS MyASUS / Armoury Crate.
if ($oem.ApplyAwccGuards) {
    . (Join-Path $PSScriptRoot 'System_AwccOverlayGuard.ps1')
    try { Set-AwccOnboardingComplete } catch { }
    if (-not $Silent) { Write-Host '  AWCC Welcome/overlay guard: applied' }
} elseif (-not $Silent) {
    Write-Host '  AWCC guards: skipped on this PC'
}

return $oem
