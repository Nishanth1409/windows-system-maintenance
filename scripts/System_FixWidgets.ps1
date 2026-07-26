# Fix Windows Widgets feed — clean reinstall Web Experience + clear stale cache
param([switch]$Silent)
$ErrorActionPreference = 'Continue'
. (Join-Path (Split-Path $PSScriptRoot -Parent) '_Root.ps1')
$base = $SMRoot
$log = Join-Path $env:LOCALAPPDATA 'SystemMaintenance\WidgetsFix.log'
$stateDir = Split-Path $log -Parent
if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

function Log([string]$m) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Add-Content -Path $log -Value $line -Encoding UTF8
    if (-not $Silent) { Write-Host $m }
}

function Test-IsAdmin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Stop-WidgetProcesses {
    foreach ($n in @('WidgetService', 'WebExperienceHost', 'StartMenuExperienceHost')) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force
    }
    Start-Sleep -Seconds 2
}

function Clear-WidgetCache {
    $roots = @(
        Join-Path $env:LOCALAPPDATA 'Packages\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy\LocalState',
        Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.StartExperiencesApp_8wekyb3d8bbwe\LocalState'
    )
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem $root -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log "Cleared cache: $root"
    }
}

function Get-WingetExe {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'),
        (Join-Path $env:ProgramFiles 'WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8we\winget.exe')
    )
    foreach ($c in $candidates) {
        if ($c -like '*`*') {
            $hit = Get-ChildItem ($c -replace '\\winget.exe','') -Filter winget.exe -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($hit) { return $hit.FullName }
        }
        elseif (Test-Path $c) { return $c }
    }
    return 'winget.exe'
}

function Invoke-WingetInstall([string[]]$WingetArgs) {
    $wg = Get-WingetExe
    Log "winget $($WingetArgs -join ' ')"
    $p = Start-Process -FilePath $wg -ArgumentList $WingetArgs -Wait -PassThru -WindowStyle Hidden
    return $p.ExitCode
}

function Register-WidgetPackages {
    Stop-WidgetProcesses
    foreach ($name in @(
        'MicrosoftWindows.Client.WebExperience',
        'Microsoft.WidgetsPlatformRuntime',
        'Microsoft.StartExperiencesApp'
    )) {
        $pkg = Get-AppxPackage -Name $name -ErrorAction SilentlyContinue
        if (-not $pkg) { continue }
        $manifest = Join-Path $pkg.InstallLocation 'AppXManifest.xml'
        if (Test-Path $manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue | Out-Null
            Log "Re-registered $name v$($pkg.Version)"
        }
    }
}

function Enable-WidgetTaskbar {
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if (-not (Test-Path $adv)) { New-Item -Path $adv -Force | Out-Null }
    Remove-ItemProperty $adv -Name TaskbarDa -ErrorAction SilentlyContinue
    Set-ItemProperty $adv TaskbarMn 1 -Type DWord -Force
    foreach ($pol in @(
        'HKCU:\Software\Policies\Microsoft\Dsh',
        'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
    )) {
        if (Test-Path $pol) { Remove-ItemProperty $pol -Name AllowNewsAndInterests -ErrorAction SilentlyContinue }
    }
}

# --- Main ---
if (-not (Test-IsAdmin)) {
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Silent')
    Start-Process powershell.exe -ArgumentList $a -Verb RunAs -WorkingDirectory $base -Wait
    if (Test-Path $log) { Get-Content $log -Tail 12 }
    exit 0
}

Log '=== Widgets feed repair ==='
Stop-WidgetProcesses
Clear-WidgetCache

# Clean reinstall Web Experience (fixes stale "app was uninstalled" feed state)
Invoke-WingetInstall @('uninstall', '--id', '9MSSGKG348SP', '--disable-interactivity') | Out-Null
Stop-WidgetProcesses
Start-Sleep -Seconds 2
$code = Invoke-WingetInstall @(
    'install', '--id', '9MSSGKG348SP',
    '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
)
Log "Web Experience winget install exit $code"

# Ensure Widgets Platform Runtime
if (-not (Get-AppxPackage -Name 'Microsoft.WidgetsPlatformRuntime' -ErrorAction SilentlyContinue)) {
    Invoke-WingetInstall @(
        'install', '--id', '9NBLGGH4R315',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    ) | Out-Null
}

Register-WidgetPackages
Enable-WidgetTaskbar

foreach ($name in @('MicrosoftWindows.Client.WebExperience', 'Microsoft.WidgetsPlatformRuntime', 'Microsoft.StartExperiencesApp')) {
    $pkg = Get-AppxPackage -Name $name -ErrorAction SilentlyContinue
    if ($pkg) { Log "OK $name v$($pkg.Version)" } else { Log "MISSING $name" }
}

Get-Process WidgetService -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Start-Process WidgetService -ErrorAction SilentlyContinue

Log '=== Done — press Win+W; sign in with Microsoft account if feed is empty ==='
