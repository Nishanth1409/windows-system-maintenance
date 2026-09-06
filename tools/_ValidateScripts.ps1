# Final audit - syntax, menu targets, required files, safe smoke tests
. (Join-Path (Split-Path $PSScriptRoot -Parent) '_Root.ps1')
$base = $SMRoot
$scriptsDir = $SMScripts
$toolsDir = $SMTools
$fail = 0

function Write-Pass { param([string]$Msg) Write-Host "OK $Msg" -ForegroundColor Green }
function Write-Fail {
    param([string]$Msg)
    Write-Host "FAIL $Msg" -ForegroundColor Red
    $script:fail++
}

Write-Host '=== Syntax check (System_*.ps1) ==='
Get-ChildItem $scriptsDir -Filter 'System_*.ps1' | ForEach-Object {
    $pe = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$pe)
    if ($pe) {
        Write-Fail $_.Name
        $pe | ForEach-Object { Write-Host "  $($_.Message)" }
    } else {
        Write-Pass $_.Name
    }
}

$helperScripts = @(
    @{ Dir = $scriptsDir; Name = 'Open_NVIDIA.ps1' },
    @{ Dir = $scriptsDir; Name = 'Extract_NVIDIA_Icons.ps1' },
    @{ Dir = $scriptsDir; Name = 'Extract_DesktopMenuIcons.ps1' },
    @{ Dir = $scriptsDir; Name = 'Extract_FileExplorer_Icon.ps1' },
    @{ Dir = $scriptsDir; Name = 'Install_NvidiaMenuGuard.ps1' },
    @{ Dir = $scriptsDir; Name = 'Build_DesktopMenuReg.ps1' },
    @{ Dir = $scriptsDir; Name = 'Install_NilesoftMenuIcons.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_OemProfile.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_ApplyOemGuards.ps1' },
    @{ Dir = $scriptsDir; Name = 'Show_SetupComplete.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_MaintenanceProtect.ps1' },
    @{ Dir = $toolsDir; Name = '_AuditMenu.ps1' },
    @{ Dir = $toolsDir; Name = '_ValidateScripts.ps1' }
)
Write-Host '=== Syntax check (helpers) ==='
foreach ($item in $helperScripts) {
    $path = Join-Path $item.Dir $item.Name
    if (-not (Test-Path $path)) {
        Write-Fail "Missing $($item.Name)"
        continue
    }
    $pe = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$pe)
    if ($pe) { Write-Fail $item.Name; $pe | ForEach-Object { Write-Host "  $($_.Message)" } }
    else { Write-Pass $item.Name }
}

Write-Host '=== Required files ==='
$required = @(
    'Add_Desktop_Menu.reg',
    'Install_Menu.bat',
    'MAKE_PORTABLE_PACKAGE.bat',
    'SETUP_NEW_PC.bat',
    'app\RAMMap64.exe',
    'System_AllInOne.bat',
    'System_Admin.bat',
    'System_EmptyRAM.bat',
    'GUIDE.md',
    'icons\nvidia_app.ico',
    'icons\nvidia_controlpanel.ico',
    'icons\menu_apps.ico',
    'icons\menu_maintenance.ico',
    'icons\menu_power.ico',
    'icons\menu_restart.ico',
    'icons\menu_sleep.ico',
    'icons\menu_shutdown.ico',
    'shell\SystemMaintenance.nss',
    'icons\file_explorer.ico',
    'icons\file_explorer_256.png',
    'scripts\System_SetLockScreen.ps1',
    'scripts\Extract_DesktopMenuIcons.ps1',
    'scripts',
    'tools'
)
foreach ($rel in $required) {
    if (Test-Path (Join-Path $base $rel)) { Write-Pass $rel }
    else { Write-Fail "Missing $rel" }
}

# .gitignore keeps these as separate projects; a copy inside this repo is a
# duplicate that will drift, so their presence is the failure, not their absence.
$noSecondCopy = @(
    'windhawk',
    'chrome-extensions',
    'vlc',
    'PortablePackage'
)
Write-Host '=== No duplicated sibling projects ==='
foreach ($rel in $noSecondCopy) {
    if (Test-Path (Join-Path $base $rel)) { Write-Fail "Second copy present: $rel" }
    else { Write-Pass "no second copy of $rel" }
}

Write-Host '=== Desktop menu script targets ==='
$menuScripts = @(
    @{ Dir = $scriptsDir; Name = 'System_SoftwareCheckup.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_QuickClean.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_UpdateWindows.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_CleanDrive.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_UpdateApps.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_SecurityScan.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_StartupApps.ps1' },
    @{ Dir = $scriptsDir; Name = 'System_FixExplorer.ps1' },
    @{ Dir = $base; Name = 'System_EmptyRAM.bat' },
    @{ Dir = $base; Name = 'System_AllInOne.bat' },
    @{ Dir = $scriptsDir; Name = 'Open_NVIDIA.ps1' }
)
foreach ($item in $menuScripts) {
    $path = Join-Path $item.Dir $item.Name
    if (Test-Path $path) { Write-Pass "menu -> $($item.Name)" }
    else { Write-Fail "menu missing $($item.Name)" }
}

Write-Host '=== Registry menu keys ==='
$regKeys = @(
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_01_Apps',
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_02_NVIDIA',
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_03_SystemMaintenance',
    'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Pwrz_04_Power'
)
foreach ($key in $regKeys) {
    if (Test-Path $key) { Write-Pass ($key -replace '.*\\', '') }
    else { Write-Fail "Registry missing $key" }
}

$maintShell = 'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell\Perz_03_SystemMaintenance\shell'
$subCount = (Get-ChildItem $maintShell -ErrorAction SilentlyContinue).Count
if ($subCount -eq 10) { Write-Pass 'System Maintenance submenu (10 items)' }
else { Write-Fail "System Maintenance submenu has $subCount items (expected 10)" }

Write-Host '=== Menu command paths (from .reg) ==='
# The .reg ships C:\SystemMaintenance as a placeholder; Install_Menu.bat rewrites
# it to wherever the toolkit actually lives, so resolve it the same way here.
# \x22 is a double quote - kept escaped so the pattern holds no literal quote.
$placeholder = 'C:\SystemMaintenance'
$pathPattern = 'C:\\\\SystemMaintenance\\\\[^\x22\\]+(?:\\[^\x22\\]+)*'
$regPath = Join-Path $base 'Add_Desktop_Menu.reg'
$regText = Get-Content -Path $regPath -Raw

$targets = [regex]::Matches($regText, $pathPattern) | ForEach-Object {
    $literal = $_.Value -replace '\\\\', '\'
    $literal -replace [regex]::Escape($placeholder), $base
}
$targets = $targets | Select-Object -Unique

foreach ($target in $targets) {
    if (Test-Path $target) { Write-Pass "reg -> $target" }
    else { Write-Fail "reg missing $target" }
}

Write-Host '=== Live menu labels (installed registry) ==='
$dash = [char]0x2014
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
    if (-not (Test-Path $itemPath)) {
        Write-Fail "live menu missing $($item.Key)"
        continue
    }
    $label = (Get-ItemProperty $itemPath).'(default)'
    if ($label -ne $item.Label) {
        Write-Fail "live label $($item.Key): $label"
        continue
    }
    $cmd = (Get-ItemProperty (Join-Path $itemPath 'command')).'(default)'
    if ($cmd -notlike "*$($item.Script)*") {
        Write-Fail "live command $($item.Key) missing $($item.Script)"
        continue
    }
    Write-Pass "live $($item.Key)"
}
if (Test-Path (Join-Path $maintShell '05b_UpdateSpicetify')) {
    Write-Fail 'obsolete Spotify + Spicetify menu item is still installed'
} else {
    Write-Pass 'Spotify + Spicetify integrated into Update All Apps'
}

$updateAppsBody = Get-Content (Join-Path $scriptsDir 'System_UpdateApps.ps1') -Raw
$userBody = Get-Content (Join-Path $scriptsDir 'System_User.ps1') -Raw
if ($updateAppsBody -match 'Invoke-SpotifySpicetifyFullUpdate' -and
    $userBody -match 'Invoke-SpotifySpicetifyFullUpdate') {
    Write-Pass 'Spotify + Spicetify final step wired into app and full maintenance'
} else {
    Write-Fail 'Spotify + Spicetify final step missing from an update workflow'
}

Write-Host '=== Image lock-screen integration ==='
$lockScreenKey = 'Registry::HKEY_CURRENT_USER\Software\Classes\SystemFileAssociations\image\shell\SetLockScreen'
$lockScreenCommand = Join-Path $lockScreenKey 'command'
if ((Get-ItemProperty $lockScreenKey -ErrorAction SilentlyContinue).'(default)' -eq 'Set as lock screen' -and
    (Get-ItemProperty $lockScreenCommand -ErrorAction SilentlyContinue).'(default)' -like '*System_SetLockScreen.ps1*') {
    Write-Pass 'Set as lock screen registered for image files'
} else {
    Write-Fail 'Set as lock screen image command is not registered'
}

Write-Host '=== Clipboard protection ==='
. (Join-Path $scriptsDir 'System_MaintenanceProtect.ps1')
$clipPath = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Clipboard'
if (Test-ProtectedMaintenancePath $clipPath) { Write-Pass 'clipboard path protected' }
else { Write-Fail 'clipboard path not protected' }
$clipKey = 'HKCU:\Software\Microsoft\Clipboard'
if ((Get-ItemProperty $clipKey -Name EnableClipboardHistory -EA SilentlyContinue).EnableClipboardHistory -eq 1) {
    Write-Pass 'clipboard history enabled (Win+V)'
} else {
    Write-Fail 'clipboard history not enabled'
}

Write-Host '=== Explorer view protection ==='
$explorerState = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
if (Test-ProtectedMaintenancePath $explorerState) { Write-Pass 'Explorer view state protected' }
else { Write-Fail 'Explorer view state not protected' }
if (Test-ExplorerViewProfile) { Write-Pass 'Explorer view profile intact (folders + This PC)' }
else { Write-Fail 'Explorer view profile drifted — run Fix Slow Explorer' }
$cleanupScripts = @('System_QuickClean.ps1', 'System_CleanDrive.ps1', 'System_WindowsJunk.ps1')
foreach ($cleanup in $cleanupScripts) {
    $body = Get-Content (Join-Path $scriptsDir $cleanup) -Raw
    if ($body -match 'Invoke-MaintenanceStandardCleanup') {
        Write-Pass "$cleanup uses guarded cleanup"
    } else {
        Write-Fail "$cleanup bypasses the Explorer view guard"
    }
}

Write-Host '=== WinGet resolution ==='
. (Join-Path $scriptsDir 'System_WingetHelpers.ps1')
$wingetPath = Get-WingetExecutablePath
if ($wingetPath) { Write-Pass "winget -> $wingetPath" }
else { Write-Fail 'winget executable not found' }

Write-Host '=== NVIDIA desktop menu (no duplicates) ==='
$nvHideScript = Join-Path $scriptsDir 'System_HideNvidiaDesktopMenu.ps1'
if (Test-Path $nvHideScript) {
    $nv = & $nvHideScript -CheckOnly
    if ($nv.StillPresent) {
        Write-Fail 'NVIDIA duplicate desktop handlers present (run Install_Menu.bat as admin)'
    } else {
        Write-Pass 'NVIDIA handlers hidden (use Perz_02_NVIDIA submenu only)'
    }
} else {
    Write-Fail 'Missing System_HideNvidiaDesktopMenu.ps1'
}

Write-Host '=== Live menu points at this folder ==='
$wrongRoot = @()
Get-ChildItem $maintShell -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = (Get-ItemProperty (Join-Path $_.PSPath 'command') -ErrorAction SilentlyContinue).'(default)'
    if ($cmd -and $cmd -notlike "*$base*") { $wrongRoot += $_.PSChildName }
}
if ($wrongRoot.Count -gt 0) {
    Write-Fail ('Menu still points elsewhere (run Install_Menu.bat): ' + ($wrongRoot -join ', '))
} else {
    Write-Pass "menu commands resolve to $base"
}

if (Test-Path $placeholder) {
    Write-Fail "$placeholder still exists - the toolkit should live in exactly one place"
} else {
    Write-Pass "no $placeholder duplicate/junction"
}

$nvGuard = Get-ScheduledTask -TaskPath '\SystemMaintenance\' -TaskName 'HideNvidiaDesktopMenu' -EA SilentlyContinue
if (-not $nvGuard) {
    Write-Fail 'NVIDIA guard task missing (run scripts\Install_NvidiaMenuGuard.ps1)'
} elseif ($nvGuard.Principal.RunLevel -ne 'Highest') {
    Write-Fail 'NVIDIA guard task not set to run with highest privileges'
} else {
    Write-Pass 'NVIDIA guard task registered (logon + periodic)'
}

Write-Host '=== Nilesoft Shell menu icons ==='
# Nilesoft Shell draws the desktop menu itself and swaps some registry icons for
# its own glyphs, so the toolkit installs an override next to its config.
$nilesoftRoot = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) |
    Where-Object { $_ } |
    ForEach-Object { Join-Path $_ 'Nilesoft Shell' } |
    Where-Object { Test-Path (Join-Path $_ 'shell.nss') } |
    Select-Object -First 1

if (-not $nilesoftRoot) {
    Write-Pass 'Nilesoft Shell not installed - registry icons apply directly'
} else {
    $override = Join-Path $nilesoftRoot 'imports\systemmaintenance.nss'
    $nilesoftConfig = Join-Path $nilesoftRoot 'shell.nss'
    $overrideText = if (Test-Path $override) { Get-Content $override -Raw } else { '' }
    $requiredPins = @(
        'menu_apps.ico',
        'menu_maintenance.ico',
        'menu_power.ico',
        'menu_restart.ico',
        'menu_sleep.ico',
        'menu_shutdown.ico',
        'nvidia_app.ico',
        'nvidia_controlpanel.ico'
    )
    if (-not (Test-Path $override)) {
        Write-Fail 'Nilesoft icon override missing (run Install_Menu.bat as admin)'
    } elseif ($overrideText -notlike "*$base*") {
        Write-Fail "Nilesoft icon override points outside $base (run Install_Menu.bat as admin)"
    } elseif ((Get-Content $nilesoftConfig -Raw) -notlike '*imports/systemmaintenance.nss*') {
        Write-Fail 'Nilesoft shell.nss does not import the override (run Install_Menu.bat as admin)'
    } else {
        $missingPins = @($requiredPins | Where-Object { $overrideText -notlike "*$_*" })
        if ($missingPins.Count -gt 0) {
            Write-Fail ("Nilesoft override missing pins: {0} (run Install_Menu.bat as admin)" -f ($missingPins -join ', '))
        } else {
            Write-Pass 'All custom menu icons pinned in Nilesoft Shell config'
        }
    }
}

Write-Host '=== Safe run tests ==='
$runTests = @(
    { & (Join-Path $scriptsDir 'System_WindowsJunk.ps1') -Level Quick -Silent | Out-Null },
    { & (Join-Path $scriptsDir 'System_QuickClean.ps1') -Silent | Out-Null }
)

$i = 0
foreach ($test in $runTests) {
    $i++
    try {
        $null = & $test
        Write-Pass "run test $i"
    } catch {
        Write-Fail "run test $i : $_"
    }
}

if ($fail -gt 0) {
    Write-Host "=== $fail CHECK(S) FAILED ===" -ForegroundColor Red
    exit 1
}
Write-Host '=== ALL CHECKS PASSED ===' -ForegroundColor Green
