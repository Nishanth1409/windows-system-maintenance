# Rewrite Add_Desktop_Menu.reg so every path points at wherever this toolkit
# actually lives. Omit the NVIDIA submenu on PCs without an NVIDIA GPU.
param(
    [string]$Root,
    [Parameter(Mandatory = $true)][string]$OutFile
)

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

$source = Join-Path $Root 'Add_Desktop_Menu.reg'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing registry source: $source"
}

. (Join-Path $PSScriptRoot 'System_OemProfile.ps1')
$oem = Get-SmOemProfile

# The checked-in .reg uses this as its placeholder default so it stays valid
# and importable on a machine that really does install to C:\SystemMaintenance.
$placeholder = 'C:\SystemMaintenance'

$text = [System.IO.File]::ReadAllText($source)

if (-not $oem.ShowNvidiaDesktopMenu) {
    # Drop the NVIDIA submenu body and delete any leftover key on import.
    $text = [regex]::Replace(
        $text,
        '(?ms)^; =+\r?\n; 8 — NVIDIA.*?(?=^; =+\r?\n; 9 — System Maintenance)',
        "; =============================================================================`r`n" +
        "; 8 — NVIDIA omitted on this PC (no NVIDIA GPU)`r`n" +
        "; =============================================================================`r`n" +
        "[-HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_02_NVIDIA]`r`n`r`n"
    )
    Write-Host 'NVIDIA desktop submenu: omitted (no NVIDIA GPU detected)'
} else {
    Write-Host 'NVIDIA desktop submenu: included'
}

# .reg values escape every backslash, so both sides must be doubled.
$escapedRoot = $Root -replace '\\', '\\'
$escapedPlaceholder = $placeholder -replace '\\', '\\'

$text = $text.Replace($escapedPlaceholder, $escapedRoot)

$leftover = [regex]::Matches($text, [regex]::Escape($escapedPlaceholder)).Count
if ($leftover -gt 0 -and $Root -ne $placeholder) {
    throw "$leftover path(s) still point at $placeholder after rewrite."
}

$outDir = Split-Path $OutFile -Parent
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

# reg.exe reads a BOM-less file as ANSI, which is how the source already works.
[System.IO.File]::WriteAllText($OutFile, $text, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Menu registry built for root: $Root ($($oem.Family))"
Write-Host "Output: $OutFile"
