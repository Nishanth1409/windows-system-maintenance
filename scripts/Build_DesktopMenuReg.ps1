# Rewrite Add_Desktop_Menu.reg so every path points at wherever this toolkit
# actually lives. There is no fixed install folder any more, so the menu is
# generated at install time instead of shipping hardcoded C:\SystemMaintenance.
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

# The checked-in .reg uses this as its placeholder default so it stays valid
# and importable on a machine that really does install to C:\SystemMaintenance.
$placeholder = 'C:\SystemMaintenance'

$text = [System.IO.File]::ReadAllText($source)

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

Write-Host "Menu registry built for root: $Root"
Write-Host "Output: $OutFile"
