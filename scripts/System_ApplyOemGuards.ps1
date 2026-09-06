# Apply only the OEM-relevant guards for this PC (any Windows laptop/desktop).
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent),
    [switch]$Silent
)

$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'System_OemProfile.ps1')
$oem = Get-SmOemProfile

if (-not $Silent) {
    Write-Host ("OEM family={0} form={1} NVIDIA={2} AWCC={3}" -f `
        $oem.Family, $oem.FormFactorHint, $oem.HasNvidia, $oem.ApplyAwccGuards)
    Write-Host ("  note: {0}" -f $oem.OemCareNote)
}

# NVIDIA duplicate desktop entries — only when an NVIDIA GPU is present.
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
} else {
    # Remove stray NVIDIA submenu / handlers if this PC previously had a GPU or
    # received a package copied from an NVIDIA machine.
    $nvidiaKey = 'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_02_NVIDIA'
    if (Test-Path -LiteralPath $nvidiaKey) {
        Remove-Item -LiteralPath $nvidiaKey -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $Silent) { Write-Host '  Removed leftover NVIDIA submenu (no NVIDIA GPU)' }
    }
    $guardRemove = Join-Path $PSScriptRoot 'Install_NvidiaMenuGuard.ps1'
    if (Test-Path -LiteralPath $guardRemove) {
        & $guardRemove -TargetRoot $Root -Remove -Silent -Elevated | Out-Null
    }
    if (-not $Silent) { Write-Host '  NVIDIA desktop-menu hide: skipped' }
}

# Alienware / AWCC only — never touch MyASUS, Vantage, HP Support, MSI Center, etc.
if ($oem.ApplyAwccGuards) {
    . (Join-Path $PSScriptRoot 'System_AwccOverlayGuard.ps1')
    try { Set-AwccOnboardingComplete } catch { }
    if (-not $Silent) { Write-Host '  AWCC Welcome/overlay guard: applied' }
} elseif (-not $Silent) {
    Write-Host '  AWCC guards: skipped on this PC'
}

return $oem
