# Register a scheduled task that re-hides the NVIDIA duplicate desktop menu
# entries. NVIDIA app self-updates re-create NvCplDesktopContext, so without a
# recurring trigger the duplicate stays until Install_Menu.bat is run by hand.
param(
    [string]$TargetRoot = (Split-Path $PSScriptRoot -Parent),
    [int]$RepeatHours = 6,
    [switch]$Remove,
    [switch]$Silent,
    [switch]$Elevated
)

$taskPath = '\SystemMaintenance\'
$taskName = 'HideNvidiaDesktopMenu'

function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated) -and -not $Elevated) {
    $self = Join-Path $PSScriptRoot 'Install_NvidiaMenuGuard.ps1'
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"",
        '-TargetRoot', "`"$TargetRoot`"", '-RepeatHours', $RepeatHours, '-Elevated')
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

$hideScript = Join-Path (Join-Path $TargetRoot 'scripts') 'System_HideNvidiaDesktopMenu.ps1'
if (-not (Test-Path -LiteralPath $hideScript)) {
    throw "Missing $hideScript — deploy the package to $TargetRoot first."
}

# Runs as the interactive user with highest privileges: the task is already
# elevated (so -Elevated skips the UAC path) and Restart-ExplorerSafe still
# relaunches Explorer into the user's session rather than session 0.
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument (
    '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ' +
    "`"$hideScript`" -Silent -Elevated")

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logonTrigger.Delay = 'PT2M'

$repeatTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddMinutes(5) `
    -RepetitionInterval (New-TimeSpan -Hours $RepeatHours)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName `
    -Action $action -Trigger @($logonTrigger, $repeatTrigger) `
    -Principal $principal -Settings $settings `
    -Description 'Removes NVIDIA duplicate desktop right-click entries re-added by NVIDIA app/driver updates.' `
    -Force | Out-Null

if (-not $Silent) {
    Write-Host "Registered $taskPath$taskName — runs at logon and every $RepeatHours hours."
    Write-Host "Target: $hideScript"
}
