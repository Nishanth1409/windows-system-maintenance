# One-shot desktop menu audit (live registry vs files)
$fail = 0
function Fail($m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fail++ }
function Pass($m) { Write-Host "OK $m" -ForegroundColor Green }

# Spicetify is integrated into Update All Apps / Full Maintenance — not a separate
# desktop submenu item (05b was removed from Add_Desktop_Menu.reg).
$expected = @(
    @{ Key = '01_SoftwareCheckup'; Label = 'Weekly — Software Checkup (All)'; Script = 'System_SoftwareCheckup.ps1' },
    @{ Key = '02_QuickClean'; Label = 'Weekly — Quick Clean'; Script = 'System_QuickClean.ps1' },
    @{ Key = '03_UpdateWindows'; Label = 'Weekly — Update Windows'; Script = 'System_UpdateWindows.ps1' },
    @{ Key = '04_FreeSpace'; Label = 'Monthly — Free Disk Space'; Script = 'System_CleanDrive.ps1' },
    @{ Key = '05_UpdateApps'; Label = 'Monthly — Update All Apps'; Script = 'System_UpdateApps.ps1' },
    @{ Key = '06_SecurityScan'; Label = 'Monthly — Security Quick Scan'; Script = 'System_SecurityScan.ps1' },
    @{ Key = '07_StartupApps'; Label = 'Monthly — Startup Apps'; Script = 'System_StartupApps.ps1' },
    @{ Key = '08_FixExplorer'; Label = 'As needed — Fix Slow Explorer'; Script = 'System_FixExplorer.ps1' },
    @{ Key = '09_RamEmpty'; Label = 'As needed — RAM Map Empty'; Script = 'System_EmptyRAM.bat' },
    @{ Key = '10_FullMaintenance'; Label = '1-2 Months — Full Maintenance (Admin)'; Script = 'System_AllInOne.bat' }
)

$base = Split-Path $PSScriptRoot -Parent
$scriptsDir = Join-Path $base 'scripts'
$shellRoot = 'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell'

Write-Host '=== Main menu groups ==='
foreach ($group in @('Perz_01_Apps', 'Perz_02_NVIDIA', 'Perz_03_SystemMaintenance', 'Pwrz_04_Power')) {
    $path = Join-Path $shellRoot $group
    if (Test-Path $path) { Pass $group } else { Fail "Missing $group" }
}

$nvidia = @('01_NVIDIAApp', '02_ControlPanel')
foreach ($n in $nvidia) {
    $cmdPath = Join-Path $shellRoot "Perz_02_NVIDIA\shell\$n\command"
    if (-not (Test-Path $cmdPath)) { Fail "NVIDIA submenu $n"; continue }
    $cmd = (Get-ItemProperty $cmdPath).'(default)'
    if ($cmd -like '*Open_NVIDIA.ps1*') { Pass "NVIDIA $n" } else { Fail "NVIDIA $n command" }
}

$power = @('01_Restart', '02_Sleep', '03_Shutdown')
foreach ($p in $power) {
    if (Test-Path (Join-Path $shellRoot "Pwrz_04_Power\shell\$p\command")) { Pass "Power $p" }
    else { Fail "Power $p" }
}

Write-Host '=== System Maintenance submenu ==='
$maintRoot = Join-Path $shellRoot 'Perz_03_SystemMaintenance\shell'
$installed = Get-ChildItem $maintRoot -ErrorAction SilentlyContinue | Sort-Object PSChildName
if ($installed.Count -ne $expected.Count) {
    Fail "Submenu count $($installed.Count) (expected $($expected.Count))"
} else {
    Pass "Submenu count $($expected.Count)"
}

if (Test-Path (Join-Path $maintRoot '05b_UpdateSpicetify')) {
    Fail 'Legacy 05b_UpdateSpicetify still present (should be removed)'
} else {
    Pass 'No legacy Spicetify submenu item'
}

foreach ($item in $expected) {
    $itemPath = Join-Path $maintRoot $item.Key
    if (-not (Test-Path $itemPath)) { Fail "Missing $($item.Key)"; continue }
    $label = (Get-ItemProperty $itemPath).'(default)'
    if ($label -ne $item.Label) { Fail "$($item.Key) label: $label" }
    else { Pass "$($item.Key) label" }

    $cmdPath = Join-Path $itemPath 'command'
    $cmd = (Get-ItemProperty $cmdPath).'(default)'
    $scriptDir = if ($item.Script -like '*.ps1') { $scriptsDir } else { $base }
    $scriptPath = Join-Path $scriptDir $item.Script
    if ($cmd -notlike "*$($item.Script)*") { Fail "$($item.Key) command missing $($item.Script)"; continue }
    if (-not (Test-Path $scriptPath)) { Fail "$($item.Key) target missing $scriptPath"; continue }
    Pass "$($item.Key) -> $($item.Script)"
}

# Icon files used by registry + Nilesoft pins
Write-Host '=== Menu icon files ==='
$iconFiles = @(
    'icons\menu_apps.ico',
    'icons\menu_maintenance.ico',
    'icons\menu_power.ico',
    'icons\menu_restart.ico',
    'icons\menu_sleep.ico',
    'icons\menu_shutdown.ico',
    'icons\nvidia_app.ico',
    'icons\nvidia_controlpanel.ico'
)
foreach ($rel in $iconFiles) {
    if (Test-Path (Join-Path $base $rel)) { Pass $rel }
    else { Fail "Missing $rel" }
}

if ($fail -gt 0) {
    Write-Host "=== $fail ISSUE(S) ===" -ForegroundColor Red
    exit 1
}
Write-Host '=== MENU AUDIT PASSED ===' -ForegroundColor Green
exit 0
