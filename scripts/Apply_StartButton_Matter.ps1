# Matter Start button — panel acrylic + custom icon on Border (requires admin)
param([switch]$Restore)

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $elevArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    if ($Restore) { $elevArgs += '-Restore' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $elevArgs -Wait
    exit $LASTEXITCODE
}

$modKey = 'HKLM:\SOFTWARE\Windhawk\Engine\Mods\windows-11-taskbar-styler'
$settingsKey = "$modKey\Settings"
$windhawkExe = 'C:\Program Files\Windhawk\windhawk.exe'
$imgPath = 'C:\SystemMaintenance\icons\Start.png'
if (-not (Test-Path -LiteralPath $imgPath)) {
    throw "Missing image: $imgPath"
}
$imgBrush = "<ImageBrush Stretch=`"Uniform`" ImageSource=`"$imgPath`" />"

if (-not (Test-Path $settingsKey)) {
    throw 'Windhawk mod windows-11-taskbar-styler is not installed or enabled.'
}

function Set-Style {
    param([int]$i, [string]$t, [string[]]$s)
    New-ItemProperty -Path $settingsKey -Name "controlStyles[$i].target" -PropertyType String -Force -Value $t | Out-Null
    for ($j = 0; $j -lt $s.Count; $j++) {
        New-ItemProperty -Path $settingsKey -Name "controlStyles[$i].styles[$j]" -PropertyType String -Force -Value $s[$j] | Out-Null
    }
}

function Clear-Style {
    param([int]$i)
    Remove-ItemProperty -Path $settingsKey -Name "controlStyles[$i].target" -ErrorAction SilentlyContinue
    0..15 | ForEach-Object {
        Remove-ItemProperty -Path $settingsKey -Name "controlStyles[$i].styles[$_]" -ErrorAction SilentlyContinue
    }
}

function Restart-ShellAndWindhawk {
    if (Test-Path -LiteralPath $windhawkExe) {
        Get-Process -Name windhawk -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 2
        Start-Process -FilePath $windhawkExe -WindowStyle Hidden
        Start-Sleep -Seconds 3
    }
    Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.CloseMainWindow() | Out-Null } catch { }
    }
    Start-Sleep -Seconds 2
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process (Join-Path $env:SystemRoot 'explorer.exe')
    Start-Sleep -Seconds 3
}

if ($Restore) {
    0..10 | ForEach-Object { Clear-Style $_ }
    $unix = [int][double]::Parse((Get-Date -UFormat %s))
    Set-ItemProperty -Path $modKey -Name 'SettingsChangeTime' -Value $unix -Type DWord -Force
    Restart-ShellAndWindhawk
    Write-Host 'Start button custom styles removed.'
    exit 0
}

0..10 | ForEach-Object { Clear-Style $_ }

$legPanel = 'Taskbar.ExperienceToggleButton#LaunchListButton[AutomationProperties.AutomationId=StartButton] > Taskbar.TaskListButtonPanel'
$legBorder = "$legPanel > Border#BackgroundElement"
$legPlayer = "$legPanel > Microsoft.UI.Xaml.Controls.AnimatedVisualPlayer#Icon"

Set-Style 0 $legPanel @(
    'Background:=$base',
    'CornerRadius=$mainRadius',
    'Width=40',
    'Height=40',
    'HorizontalAlignment=Center',
    'VerticalAlignment=Center'
)
Set-Style 1 $legBorder @(
    "Background:=$imgBrush",
    'Width=28',
    'Height=28',
    'HorizontalAlignment=Center',
    'VerticalAlignment=Center'
)
Set-Style 2 $legPlayer @('Visibility=Collapsed')

$unix = [int][double]::Parse((Get-Date -UFormat %s))
Set-ItemProperty -Path $modKey -Name 'SettingsChangeTime' -Value $unix -Type DWord -Force
New-ItemProperty -Path $settingsKey -Name 'theme' -PropertyType String -Force -Value 'Matter' | Out-Null
New-ItemProperty -Path $settingsKey -Name 'styleConstants[1]' -PropertyType String -Force -Value '' | Out-Null
New-ItemProperty -Path $settingsKey -Name 'resourceVariables[0].variableKey' -PropertyType String -Force -Value '' | Out-Null
New-ItemProperty -Path $settingsKey -Name 'resourceVariables[0].value' -PropertyType String -Force -Value '' | Out-Null

Restart-ShellAndWindhawk
Write-Host "Start button: Matter panel + icon on border applied ($imgPath)"
Write-Host 'To undo: Apply_StartButton_Matter.ps1 -Restore'
