# Build file_explorer.ico from icons\file_explorer.png (or file explorer.svg)
# Applies icon to File Explorer shortcuts + refreshes Windows icon cache
$ErrorActionPreference = 'Stop'

$iconsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'icons'
$svgPath  = Join-Path $iconsDir 'file explorer.svg'
$pngPath  = Join-Path $iconsDir 'file_explorer.png'
$altPng   = Join-Path $iconsDir 'file_explorer_256.png'
$icoPath  = Join-Path $iconsDir 'file_explorer.ico'
$pyBuild  = Join-Path (Split-Path $PSScriptRoot -Parent) 'tools\_BuildFileExplorerIco.py'
$explorerExe = Join-Path $env:SystemRoot 'explorer.exe'

New-Item -ItemType Directory -Force -Path $iconsDir | Out-Null

if (Test-Path -LiteralPath $svgPath) {
    $svg = Get-Content -LiteralPath $svgPath -Raw -Encoding UTF8
    if ($svg -match 'data:image/png;base64,([^"'']+)') {
        [IO.File]::WriteAllBytes($pngPath, [Convert]::FromBase64String($matches[1]))
        Write-Host "Extracted PNG from SVG"
    }
}

# The original file_explorer.png source is optional: the 256 PNG this script
# emits is a valid source for a rebuild, and a prebuilt .ico needs no source at
# all. Only fail when there is nothing to apply.
$source = $null
foreach ($candidate in @($pngPath, $altPng)) {
    if (Test-Path -LiteralPath $candidate) { $source = $candidate; break }
}

$py = Get-Command python -ErrorAction SilentlyContinue
$canBuild = $source -and $py

if ($canBuild) {
    & $py.Source $pyBuild $source
    if ($LASTEXITCODE -ne 0) { throw 'ICO build failed' }
    Write-Host "Saved: $icoPath"
} elseif (Test-Path -LiteralPath $icoPath) {
    if (-not $source) { Write-Host "No source PNG; applying existing $icoPath" }
    elseif (-not $py) { Write-Host "Python not available; applying existing $icoPath" }
} else {
    throw "No icon to apply: need $pngPath (or $altPng) plus Python, or a prebuilt $icoPath"
}

if (-not (Test-Path -LiteralPath $icoPath)) { throw "ICO not created: $icoPath" }

function Set-FileExplorerShortcut {
    param(
        [string]$LnkPath,
        [string]$IconPath
    )
    $dir = Split-Path $LnkPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { return $false }

    $sh = New-Object -ComObject WScript.Shell
    $sc = $sh.CreateShortcut($LnkPath)
    $sc.TargetPath = $explorerExe
    $sc.Arguments = ''
    $sc.WorkingDirectory = $env:USERPROFILE
    $sc.IconLocation = "$IconPath,0"
    $sc.Description = 'File Explorer'
    $sc.Save()
    Write-Host "Updated: $LnkPath"
    return $true
}

$shortcutTargets = @(
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\File Explorer.lnk"
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk"
    (Join-Path $env:USERPROFILE 'OneDrive\Desktop\File Explorer.lnk')
    (Join-Path $env:USERPROFILE 'Desktop\File Explorer.lnk')
)

foreach ($lnk in $shortcutTargets) {
    Set-FileExplorerShortcut -LnkPath $lnk -IconPath $icoPath | Out-Null
}

# Ensure a desktop shortcut exists for re-pin if taskbar still shows old icon
$desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
if (-not (Test-Path -LiteralPath $desktop)) {
    $desktop = Join-Path $env:USERPROFILE 'Desktop'
}
$desktopLnk = Join-Path $desktop 'File Explorer.lnk'
Set-FileExplorerShortcut -LnkPath $desktopLnk -IconPath $icoPath | Out-Null

# Recreate taskbar pin so Windows picks up the new icon (Win11 caches default AUMID icon)
$taskbarLnk = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\File Explorer.lnk"
if (Test-Path -LiteralPath $taskbarLnk) {
    Remove-Item -LiteralPath $taskbarLnk -Force
    Start-Sleep -Milliseconds 500
}
Copy-Item -LiteralPath $desktopLnk -Destination $taskbarLnk -Force
Set-FileExplorerShortcut -LnkPath $taskbarLnk -IconPath $icoPath | Out-Null

Write-Host 'Refreshing icon cache...'
Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object {
    try { $_.CloseMainWindow() | Out-Null } catch { }
}
Start-Sleep -Seconds 2
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$iconCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
Get-ChildItem $iconCache -Filter 'iconcache*' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem $iconCache -Filter 'thumbcache*' -ErrorAction SilentlyContinue |
    Remove-Item -Force -ErrorAction SilentlyContinue

$ie4u = Join-Path ${env:ProgramFiles(x86)} 'Internet Explorer\ie4uinit.exe'
if (Test-Path -LiteralPath $ie4u) {
    Start-Process -FilePath $ie4u -ArgumentList '-show' -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
}

Start-Process -FilePath $explorerExe
Start-Sleep -Seconds 3

Write-Host ''
Write-Host 'File Explorer icon applied.'
Write-Host 'Check taskbar + desktop shortcut. If still old: unpin taskbar icon, then Pin to taskbar from desktop shortcut.'
