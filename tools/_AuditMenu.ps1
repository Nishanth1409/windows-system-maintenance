# Quick live desktop-menu check. Full suite: _FinalCheck.ps1
$fail = 0
function Fail([string]$m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fail++ }
function Pass([string]$m) { Write-Host "OK $m" -ForegroundColor Green }

$dash = [char]0x2014
$base = Split-Path $PSScriptRoot -Parent
$scriptsDir = Join-Path $base 'scripts'
$shell = 'Registry::HKEY_CLASSES_ROOT\DesktopBackground\Shell'
$maint = Join-Path $shell 'Perz_03_SystemMaintenance\shell'

$expected = @(
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

Write-Host '=== Groups ==='
@('Perz_01_Apps', 'Perz_02_NVIDIA', 'Perz_03_SystemMaintenance', 'Pwrz_04_Power') | ForEach-Object {
    if (Test-Path (Join-Path $shell $_)) { Pass $_ } else { Fail "missing $_" }
}

@('01_NVIDIAApp', '02_ControlPanel') | ForEach-Object {
    $cmdPath = Join-Path $shell "Perz_02_NVIDIA\shell\$_\command"
    if (-not (Test-Path $cmdPath)) { Fail "NVIDIA $_"; return }
    $cmd = (Get-ItemProperty $cmdPath).'(default)'
    if ($cmd -like '*Open_NVIDIA.ps1*') { Pass "NVIDIA $_" } else { Fail "NVIDIA $_ cmd" }
}

@('01_Restart', '02_Sleep', '03_Shutdown') | ForEach-Object {
    if (Test-Path (Join-Path $shell "Pwrz_04_Power\shell\$_\command")) { Pass "Power $_" }
    else { Fail "Power $_" }
}

Write-Host '=== Submenu ==='
$n = @(Get-ChildItem $maint -EA SilentlyContinue).Count
if ($n -eq $expected.Count) { Pass "count $n" } else { Fail "count $n (expected $($expected.Count))" }
if (Test-Path (Join-Path $maint '05b_UpdateSpicetify')) { Fail 'legacy 05b present' }
else { Pass 'no 05b' }

foreach ($item in $expected) {
    $path = Join-Path $maint $item.Key
    if (-not (Test-Path $path)) { Fail "missing $($item.Key)"; continue }
    if ((Get-ItemProperty $path).'(default)' -ne $item.Label) { Fail "$($item.Key) label"; continue }
    $cmd = (Get-ItemProperty (Join-Path $path 'command')).'(default)'
    $targetDir = if ($item.Script -like '*.ps1') { $scriptsDir } else { $base }
    if ($cmd -notlike "*$($item.Script)*") { Fail "$($item.Key) cmd"; continue }
    if (-not (Test-Path (Join-Path $targetDir $item.Script))) { Fail "$($item.Key) file"; continue }
    Pass $item.Key
}

if ($fail -gt 0) {
    Write-Host "=== $fail FAILED ===" -ForegroundColor Red
    exit 1
}
Write-Host '=== MENU AUDIT PASSED ===' -ForegroundColor Green
exit 0
