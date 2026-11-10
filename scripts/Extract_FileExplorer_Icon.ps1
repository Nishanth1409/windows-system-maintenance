# Build file_explorer.ico from icons\file_explorer.png (or file explorer.svg)
# Applies the custom icon to File Explorer shortcuts. Do not give the pin a
# separate AppUserModelID — that made Explorer open as a second app (This PC
# window next to the pin). Keep the inbox identity so it groups as File Explorer.
param(
    [switch]$RestartExplorer,
    [switch]$Silent
)
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

function Get-RealPythonCommand {
    foreach ($name in @('py', 'python3', 'python')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        # Windows Store alias prints "Python was not found" and exits non-zero.
        if ($cmd.Source -like '*\WindowsApps\python*.exe') { continue }
        if ($cmd.Source -like '*\WindowsApps\py.exe') { continue }
        try {
            $null = & $cmd.Source --version 2>&1
            if ($LASTEXITCODE -eq 0) { return $cmd }
        } catch { }
    }
    return $null
}

$py = Get-RealPythonCommand
$canBuild = $source -and $py -and (Test-Path -LiteralPath $pyBuild)

if ($canBuild) {
    & $py.Source $pyBuild $source
    if ($LASTEXITCODE -ne 0) {
        if (Test-Path -LiteralPath $icoPath) {
            Write-Host "ICO rebuild skipped (Python build failed); using existing $icoPath"
        } else {
            throw 'ICO build failed and no prebuilt file_explorer.ico is present'
        }
    } else {
        Write-Host "Saved: $icoPath"
    }
} elseif (Test-Path -LiteralPath $icoPath) {
    if (-not $source) { Write-Host "No source PNG; applying existing $icoPath" }
    elseif (-not $py) { Write-Host "Python not available; applying existing $icoPath" }
    else { Write-Host "Applying existing $icoPath" }
} else {
    throw "No icon to apply: need $pngPath (or $altPng) plus Python, or a prebuilt $icoPath"
}

if (-not (Test-Path -LiteralPath $icoPath)) { throw "ICO not created: $icoPath" }

# Stable copy: D: may not be ready at logon, so shortcuts point here.
$stableDir = Join-Path $env:LOCALAPPDATA 'SystemMaintenance'
$stableIco = Join-Path $stableDir 'file_explorer.ico'
New-Item -ItemType Directory -Force -Path $stableDir | Out-Null
Copy-Item -LiteralPath $icoPath -Destination $stableIco -Force
$iconForShortcuts = $stableIco

# Inbox File Explorer identity — same grouping as This PC / folder windows
$explorerAppId = 'Microsoft.Windows.Explorer'

if (-not ('SmLnkProps' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, Pack = 4)]
public struct SM_PROPERTYKEY {
    public Guid fmtid;
    public UInt32 pid;
}

[StructLayout(LayoutKind.Sequential)]
public struct SM_PROPVARIANT {
    public ushort vt;
    public ushort wReserved1;
    public ushort wReserved2;
    public ushort wReserved3;
    public IntPtr pszVal;
}

[ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown),
 Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99")]
public interface SM_IPropertyStore {
    void GetCount(out uint cProps);
    void GetAt(uint iProp, out SM_PROPERTYKEY pkey);
    void GetValue(ref SM_PROPERTYKEY key, out SM_PROPVARIANT pv);
    void SetValue(ref SM_PROPERTYKEY key, ref SM_PROPVARIANT pv);
    void Commit();
}

public static class SmLnkProps {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void SHGetPropertyStoreFromParsingName(
        string pszPath, IntPtr pbc, uint flags, [In] ref Guid riid, out SM_IPropertyStore ppv);

    [DllImport("ole32.dll")]
    private static extern void PropVariantClear(ref SM_PROPVARIANT pvar);

    public static void SetAppId(string path, string appId) {
        Guid iid = new Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99");
        SM_IPropertyStore store;
        SHGetPropertyStoreFromParsingName(path, IntPtr.Zero, 2 /* GPS_READWRITE */, ref iid, out store);
        SM_PROPERTYKEY key;
        key.fmtid = new Guid("9F4C2855-9F79-4B39-A8D0-E1D42DE1D5F3");
        key.pid = 5;
        SM_PROPVARIANT pv = new SM_PROPVARIANT();
        if (string.IsNullOrEmpty(appId)) {
            pv.vt = 0; // VT_EMPTY — remove a custom identity
        } else {
            pv.vt = 31; // VT_LPWSTR
            pv.pszVal = Marshal.StringToCoTaskMemUni(appId);
        }
        try {
            store.SetValue(ref key, ref pv);
            store.Commit();
        } finally {
            PropVariantClear(ref pv);
        }
        Marshal.ReleaseComObject(store);
    }
}
'@
}

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
    try { [SmLnkProps]::SetAppId($LnkPath, $explorerAppId) } catch { }
    if (-not $Silent) { Write-Host "Updated: $LnkPath" }
    return $true
}

function Test-LnkTargetsExplorer {
    param([string]$LnkPath)
    if (-not (Test-Path -LiteralPath $LnkPath)) { return $false }
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($LnkPath)
        return ($sc.TargetPath -match '(?i)\\explorer\.exe$')
    } catch { return $false }
}

$shortcutTargets = @(
    "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\File Explorer.lnk"
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\File Explorer.lnk"
    (Join-Path $env:USERPROFILE 'OneDrive\Desktop\File Explorer.lnk')
    (Join-Path $env:USERPROFILE 'Desktop\File Explorer.lnk')
)

$pinnedDir = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar"
if (Test-Path -LiteralPath $pinnedDir) {
    Get-ChildItem -LiteralPath $pinnedDir -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { Test-LnkTargetsExplorer $_.FullName } |
        ForEach-Object { $shortcutTargets += $_.FullName }
}

foreach ($lnk in ($shortcutTargets | Select-Object -Unique)) {
    Set-FileExplorerShortcut -LnkPath $lnk -IconPath $iconForShortcuts | Out-Null
}

$desktop = Join-Path $env:USERPROFILE 'OneDrive\Desktop'
if (-not (Test-Path -LiteralPath $desktop)) {
    $desktop = Join-Path $env:USERPROFILE 'Desktop'
}
$desktopLnk = Join-Path $desktop 'File Explorer.lnk'
Set-FileExplorerShortcut -LnkPath $desktopLnk -IconPath $iconForShortcuts | Out-Null

$taskbarLnk = "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\File Explorer.lnk"
if (-not (Test-Path -LiteralPath $taskbarLnk) -and (Test-Path -LiteralPath $desktopLnk)) {
    Copy-Item -LiteralPath $desktopLnk -Destination $taskbarLnk -Force
}
if (Test-Path -LiteralPath $taskbarLnk) {
    Set-FileExplorerShortcut -LnkPath $taskbarLnk -IconPath $iconForShortcuts | Out-Null
}

# Per-monitor copies created by Independent taskbar per monitor
$linkRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Windhawk'),
    (Join-Path $env:ProgramData 'Windhawk')
)
foreach ($root in $linkRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Recurse -Filter '*.lnk' -ErrorAction SilentlyContinue |
        Where-Object { $_.DirectoryName -match 'TaskbarLinks' -and (Test-LnkTargetsExplorer $_.FullName) } |
        ForEach-Object {
            Set-FileExplorerShortcut -LnkPath $_.FullName -IconPath $iconForShortcuts | Out-Null
        }
}

if (-not ('SmShellNotify' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SmShellNotify {
    [DllImport("shell32.dll")]
    public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@
}
[SmShellNotify]::SHChangeNotify(0x08000000, 0x1000, [IntPtr]::Zero, [IntPtr]::Zero)

if ($RestartExplorer) {
    if (-not $Silent) { Write-Host 'Refreshing icon cache...' }
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
}

if (-not $Silent) {
    Write-Host ''
    Write-Host 'File Explorer icon applied.'
    Write-Host 'Check taskbar + desktop. If still the yellow folder: unpin File Explorer, then pin the desktop shortcut.'
}
