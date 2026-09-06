# Full suite: syntax, files, live menu, guards. Exit 0 only if all pass.
. (Join-Path (Split-Path $PSScriptRoot -Parent) '_Root.ps1')
$base = $SMRoot
$scriptsDir = $SMScripts
$toolsDir = $SMTools
$fail = 0
$dash = [char]0x2014
$placeholder = 'C:\SystemMaintenance'
$maintShell = 'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_03_SystemMaintenance\shell'

function Write-Pass { param([string]$Msg) Write-Host "OK $Msg" -ForegroundColor Green }
function Write-Fail {
    param([string]$Msg)
    Write-Host "FAIL $Msg" -ForegroundColor Red
    $script:fail++
}

function Test-PsSyntax {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) { Write-Fail "Missing $Name"; return }
    $pe = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$pe)
    if ($pe) {
        Write-Fail $Name
        $pe | ForEach-Object { Write-Host "  $($_.Message)" }
    } else {
        Write-Pass $Name
    }
}

Write-Host '=== Syntax ==='
Get-ChildItem $scriptsDir -Filter 'System_*.ps1' | ForEach-Object {
    Test-PsSyntax $_.FullName $_.Name
}
@(
    'Open_NVIDIA.ps1',
    'Extract_NVIDIA_Icons.ps1',
    'Extract_DesktopMenuIcons.ps1',
    'Extract_FileExplorer_Icon.ps1',
    'Install_NvidiaMenuGuard.ps1',
    'Build_DesktopMenuReg.ps1',
    'Install_NilesoftMenuIcons.ps1',
    'Show_SetupComplete.ps1'
) | ForEach-Object { Test-PsSyntax (Join-Path $scriptsDir $_) $_ }
@('_AuditMenu.ps1', '_ValidateScripts.ps1', '_FinalCheck.ps1') | ForEach-Object {
    Test-PsSyntax (Join-Path $toolsDir $_) $_
}

Write-Host '=== Required files ==='
@(
    'Add_Desktop_Menu.reg',
    'Install_Menu.bat',
    'MAKE_PORTABLE_PACKAGE.bat',
    'SETUP_NEW_PC.bat',
    'System_AllInOne.bat',
    'System_Admin.bat',
    'System_EmptyRAM.bat',
    'GUIDE.md',
    'shell\SystemMaintenance.nss',
    'app\RAMMap64.exe',
    'icons\nvidia_app.ico',
    'icons\nvidia_controlpanel.ico',
    'icons\menu_apps.ico',
    'icons\menu_maintenance.ico',
    'icons\menu_power.ico',
    'icons\menu_restart.ico',
    'icons\menu_sleep.ico',
    'icons\menu_shutdown.ico',
    'icons\file_explorer.ico',
    'icons\file_explorer_256.png',
    'scripts\Extract_DesktopMenuIcons.ps1',
    'scripts\System_SetLockScreen.ps1',
    'tools\_FinalCheck.ps1',
    'tools\_ValidateScripts.ps1',
    'tools\_AuditMenu.ps1',
    'tools\_SmRunHidden.cs'
) | ForEach-Object {
    if (Test-Path (Join-Path $base $_)) { Write-Pass $_ }
    else { Write-Fail "Missing $_" }
}

Write-Host '=== No duplicate copies ==='
@('windhawk', 'chrome-extensions', 'vlc', 'PortablePackage') | ForEach-Object {
    if (Test-Path (Join-Path $base $_)) { Write-Fail "Second copy: $_" }
    else { Write-Pass "no $_" }
}

Write-Host '=== Menu script targets ==='
@(
    @{ Dir = $scriptsDir; Name = 'System_SoftwareCheckup.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_QuickClean.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_UpdateWindows.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_CleanDrive.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_UpdateApps.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_SecurityScan.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_StartupApps.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_FixExplorer.ps1' },
    @{ Dir = $scriptsDir; Name = 'Open_NVIDIA.ps1' },
    @{ Dir = $base; Name = 'System_EmptyRAM.bat' },
    @{ Dir = $base; Name = 'System_AllInOne.bat' }
) | ForEach-Object {
    if (Test-Path (Join-Path $_.Dir $_.Name)) { Write-Pass $_.Name }
    else { Write-Fail "menu missing $($_.Name)" }
}

Write-Host '=== Registry menu ==='
@(
    'Perz_01_Apps',
    'Perz_02_NVIDIA',
    'Perz_03_SystemMaintenance',
    'Pwrz_04_Power'
) | ForEach-Object {
    $key = "Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\$_"
    if (Test-Path $key) { Write-Pass $_ }
    else { Write-Fail "missing $_" }
}

$subCount = @(Get-ChildItem $maintShell -ErrorAction SilentlyContinue).Count
if ($subCount -eq 10) { Write-Pass 'submenu 10 items' }
else { Write-Fail "submenu $subCount items (expected 10)" }

Write-Host '=== .reg paths ==='
$pathPattern = 'C:\\\\SystemMaintenance\\\\[^\x22\\]+(?:\\[^\x22\\]+)*'
$regText = Get-Content (Join-Path $base 'Add_Desktop_Menu.reg') -Raw
$targets = [regex]::Matches($regText, $pathPattern) | ForEach-Object {
    ($_.Value -replace '\\\\', '\') -replace [regex]::Escape($placeholder), $base
} | Select-Object -Unique
foreach ($target in $targets) {
    if (Test-Path $target) { Write-Pass "reg $($target.Replace($base + '\', ''))" }
    else { Write-Fail "reg missing $target" }
}

Write-Host '=== Live menu labels ==='
$menuExpected = @(
    @{ Key = '01_SoftwareCheckup'; Label = "Weekly $dash Software Checkup (All)"; Script = 'System_SoftwareCheckup.ps1' },
    @{ Key = '02_QuickClean'; Label = "Weekly $dash Quick Clean"; Script = 'System_QuickClean.ps1' },
    @{ Key = '03_UpdateWindows'; Label = "Weekly $dash Update Windows"; Script = 'System_UpdateWindows.ps1' },
    @{ Key = '04_FreeSpace'; Label = "Monthly $dash Free Disk Space"; Script = 'System_CleanDrive.ps1' },
    @{ Key = '05_UpdateApps'; Label = "Monthly $dash Update All Apps"; Script = 'System_UpdateApps.ps1' },
    @{ Key = '06_SecurityScan'; Label = "Monthly $dash Security Quick Scan"; Script = 'System_SecurityScan.ps1' },
    @{ Key = '07_StartupApps'; Label = "Monthly $dash Startup Apps"; Script = 'System_StartupApps.ps1' },
    @{ Key = '08_FixExplorer'; Label = "As needed $dash Fix Slow Explorer"; Script = 'System_FixExplorer.ps1' },
    @{ Key = '09_RamEmpty'; Label = "As needed $dash RAM Map Empty"; Script = 'System_EmptyRAM.bat' },
    @{ Key = '10_FullMaintenance'; Label = "1-2 Months $dash Full Maintenance (Admin)"; Script = 'System_AllInOne.bat' }
)
foreach ($item in $menuExpected) {
    $itemPath = Join-Path $maintShell $item.Key
    if (-not (Test-Path $itemPath)) { Write-Fail "live missing $($item.Key)"; continue }
    $label = (Get-ItemProperty $itemPath).'(default)'
    if ($label -ne $item.Label) { Write-Fail "live label $($item.Key)"; continue }
    $cmd = (Get-ItemProperty (Join-Path $itemPath 'command')).'(default)'
    if ($cmd -notlike "*$($item.Script)*") { Write-Fail "live cmd $($item.Key)"; continue }
    Write-Pass $item.Key
}
if (Test-Path (Join-Path $maintShell '05b_UpdateSpicetify')) {
    Write-Fail 'obsolete 05b_UpdateSpicetify still installed'
} else {
    Write-Pass 'no 05b Spicetify item'
}

$updateAppsBody = Get-Content (Join-Path $scriptsDir 'System_UpdateApps.ps1') -Raw
$userBody = Get-Content (Join-Path $scriptsDir 'System_User.ps1') -Raw
if ($updateAppsBody -match 'Invoke-SpotifySpicetifyFullUpdate' -and
    $userBody -match 'Invoke-SpotifySpicetifyFullUpdate') {
    Write-Pass 'Spicetify wired into Update Apps + Full Maintenance'
} else {
    Write-Fail 'Spicetify step missing from update workflow'
}

Write-Host '=== Lock screen / clipboard / Explorer ==='
$lockKey = 'Registry::HKEY_CURRENT_USER\Software\Classes\SystemFileAssociations\image\shell\SetLockScreen'
$lockCmd = Join-Path $lockKey 'command'
if ((Get-ItemProperty $lockKey -EA SilentlyContinue).'(default)' -eq 'Set as lock screen' -and
    (Get-ItemProperty $lockCmd -EA SilentlyContinue).'(default)' -like '*System_SetLockScreen.ps1*') {
    Write-Pass 'Set as lock screen'
} else {
    Write-Fail 'Set as lock screen missing'
}

. (Join-Path $scriptsDir 'System_MaintenanceProtect.ps1')
$clipPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Clipboard'
if (Test-ProtectedMaintenancePath $clipPath) { Write-Pass 'clipboard protected' }
else { Write-Fail 'clipboard not protected' }
if ((Get-ItemProperty 'HKCU:\Software\Microsoft\Clipboard' -Name EnableClipboardHistory -EA SilentlyContinue).EnableClipboardHistory -eq 1) {
    Write-Pass 'clipboard history on'
} else {
    Write-Fail 'clipboard history off'
}

$explorerState = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
if (Test-ProtectedMaintenancePath $explorerState) { Write-Pass 'Explorer state protected' }
else { Write-Fail 'Explorer state not protected' }
if (Test-ExplorerViewProfile) { Write-Pass 'Explorer view profile OK' }
else { Write-Fail 'Explorer view profile drifted' }
@('System_QuickClean.ps1', 'System_CleanDrive.ps1', 'System_WindowsJunk.ps1') | ForEach-Object {
    $body = Get-Content (Join-Path $scriptsDir $_) -Raw
    if ($body -match 'Invoke-MaintenanceStandardCleanup') { Write-Pass "$_ guarded" }
    else { Write-Fail "$_ unguarded cleanup" }
}

Write-Host '=== WinGet / NVIDIA / paths ==='
. (Join-Path $scriptsDir 'System_WingetHelpers.ps1')
$wingetPath = Get-WingetExecutablePath
if ($wingetPath) { Write-Pass "winget $wingetPath" }
else { Write-Fail 'winget missing' }

$nvHide = Join-Path $scriptsDir 'System_HideNvidiaDesktopMenu.ps1'
if (Test-Path $nvHide) {
    $nv = & $nvHide -CheckOnly
    if ($nv.StillPresent) { Write-Fail 'NVIDIA duplicate handlers present' }
    else { Write-Pass 'NVIDIA duplicates hidden' }
} else {
    Write-Fail 'System_HideNvidiaDesktopMenu.ps1 missing'
}

$wrongRoot = @()
Get-ChildItem $maintShell -EA SilentlyContinue | ForEach-Object {
    $cmd = (Get-ItemProperty (Join-Path $_.PSPath 'command') -EA SilentlyContinue).'(default)'
    if ($cmd -and $cmd -notlike "*$base*") { $wrongRoot += $_.PSChildName }
}
if ($wrongRoot.Count -gt 0) { Write-Fail ('menu points elsewhere: ' + ($wrongRoot -join ', ')) }
else { Write-Pass "menu -> $base" }

if (Test-Path $placeholder) { Write-Fail "$placeholder still exists" }
else { Write-Pass "no $placeholder junction" }

$nvGuard = Get-ScheduledTask -TaskPath '\SystemMaintenance\' -TaskName 'HideNvidiaDesktopMenu' -EA SilentlyContinue
if (-not $nvGuard) { Write-Fail 'NVIDIA guard task missing' }
elseif ($nvGuard.Principal.RunLevel -ne 'Highest') { Write-Fail 'NVIDIA guard not Highest' }
else { Write-Pass 'NVIDIA guard task OK' }

Write-Host '=== Nilesoft icons ==='
$nilesoftRoot = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
    Where-Object { $_ } |
    ForEach-Object { Join-Path $_ 'Nilesoft Shell' } |
    Where-Object { Test-Path (Join-Path $_ 'shell.nss') } |
    Select-Object -First 1

if (-not $nilesoftRoot) {
    Write-Pass 'Nilesoft not installed'
} else {
    $override = Join-Path $nilesoftRoot 'imports\systemmaintenance.nss'
    $config = Join-Path $nilesoftRoot 'shell.nss'
    $text = if (Test-Path $override) { Get-Content $override -Raw } else { '' }
    $pins = @(
        'menu_apps.ico', 'menu_maintenance.ico', 'menu_power.ico',
        'menu_restart.ico', 'menu_sleep.ico', 'menu_shutdown.ico',
        'nvidia_app.ico', 'nvidia_controlpanel.ico'
    )
    if (-not (Test-Path $override)) { Write-Fail 'Nilesoft override missing' }
    elseif ($text -notlike "*$base*") { Write-Fail 'Nilesoft override wrong root' }
    elseif ((Get-Content $config -Raw) -notlike '*imports/systemmaintenance.nss*') { Write-Fail 'Nilesoft import missing' }
    else {
        $missing = @($pins | Where-Object { $text -notlike "*$_*" })
        if ($missing.Count) { Write-Fail ('Nilesoft missing: ' + ($missing -join ', ')) }
        else { Write-Pass 'Nilesoft pins OK' }
    }
}

Write-Host '=== Smoke ==='
$i = 0
@(
    { & (Join-Path $scriptsDir 'System_WindowsJunk.ps1') -Level Quick -Silent | Out-Null },
    { & (Join-Path $scriptsDir 'System_QuickClean.ps1') -Silent | Out-Null }
) | ForEach-Object {
    $i++
    try { & $_; Write-Pass "smoke $i" }
    catch { Write-Fail "smoke $i : $_" }
}

if ($fail -gt 0) {
    Write-Host "=== $fail FAILED ===" -ForegroundColor Red
    exit 1
}
Write-Host '=== ALL CHECKS PASSED ===' -ForegroundColor Green
exit 0
