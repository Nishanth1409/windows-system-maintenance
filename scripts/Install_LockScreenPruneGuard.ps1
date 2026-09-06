# Register a scheduled task that keeps the wallpaper backup folders lean.
#
# The "Lock Screen Wallpaper" Windhawk mod re-stages a fresh timestamped copy on
# every boot / unlock / sign-in and never removes the old ones, so without a
# recurring trigger they accumulate (they had reached 285 files / 1.55 GB). This
# runs System_LockScreenPrune.ps1 at logon and on a short interval so only the
# active image plus the newest copy survive.
param(
    [string]$TargetRoot = (Split-Path $PSScriptRoot -Parent),
    [int]$RepeatMinutes = 60,
    [int]$KeepNewest = 1,
    [switch]$Remove,
    [switch]$Silent,
    [switch]$Elevated
)

$taskPath = '\SystemMaintenance\'
$taskName = 'LockScreenBackupPrune'

function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated) -and -not $Elevated) {
    $self = Join-Path $PSScriptRoot 'Install_LockScreenPruneGuard.ps1'
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"",
        '-TargetRoot', "`"$TargetRoot`"", '-RepeatMinutes', $RepeatMinutes,
        '-KeepNewest', $KeepNewest, '-Elevated')
    if ($Remove) { $psArgs += '-Remove' }
    if ($Silent) { $psArgs += '-Silent' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $psArgs -Wait | Out-Null
    return
}

if ($Remove) {
    if (Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false
        if (-not $Silent) { Write-Host "Removed scheduled task $taskPath$taskName" }
    } elseif (-not $Silent) {
        Write-Host "No scheduled task $taskPath$taskName to remove."
    }
    return
}

$pruneScript = Join-Path (Join-Path $TargetRoot 'scripts') 'System_LockScreenPrune.ps1'
if (-not (Test-Path -LiteralPath $pruneScript)) {
    throw "Missing $pruneScript - deploy the package to $TargetRoot first."
}

# Launch through SmRunHidden.exe: "powershell.exe -WindowStyle Hidden" still
# flashes a console for an instant because Windows creates the window before
# PowerShell can hide it, and this task repeats all day.
. (Join-Path $PSScriptRoot 'System_HiddenLauncherCore.ps1')
$launcher = Resolve-HiddenLauncher -TargetRoot $TargetRoot

$action = New-ScheduledTaskAction -Execute $launcher -Argument (
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ' +
    "`"$pruneScript`" -Silent -KeepNewest $KeepNewest")

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logonTrigger.Delay = 'PT1M'

$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(3) `
    -RepetitionInterval (New-TimeSpan -Minutes $RepeatMinutes)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName `
    -Action $action -Trigger @($logonTrigger, $repeatTrigger) `
    -Principal $principal -Settings $settings `
    -Description 'Keeps only the active wallpaper plus newest backup in WindhawkLockScreen and the Windows theme cache; deletes older disposable copies.' `
    -Force | Out-Null

if (-not $Silent) {
    Write-Host "Registered $taskPath$taskName - runs at logon and every $RepeatMinutes minutes."
    Write-Host "Target: $pruneScript"
}
