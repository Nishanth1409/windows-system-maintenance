# Re-apply the custom File Explorer icon after logon. Shortcuts keep the inbox
# File Explorer app identity so windows group with This PC, not a second app.
param(
    [string]$TargetRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$Remove,
    [switch]$Silent,
    [switch]$Elevated
)

$taskPath = '\SystemMaintenance\'
$taskName = 'ApplyFileExplorerIcon'

function Test-IsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsElevated) -and -not $Elevated) {
    $self = Join-Path $PSScriptRoot 'Install_FileExplorerIconGuard.ps1'
    $psArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$self`"",
        '-TargetRoot', "`"$TargetRoot`"", '-Elevated')
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

$applyScript = Join-Path (Join-Path $TargetRoot 'scripts') 'Extract_FileExplorer_Icon.ps1'
if (-not (Test-Path -LiteralPath $applyScript)) {
    throw "Missing $applyScript — deploy the package to $TargetRoot first."
}

. (Join-Path $PSScriptRoot 'System_HiddenLauncherCore.ps1')
$launcher = Resolve-HiddenLauncher -TargetRoot $TargetRoot

$action = New-ScheduledTaskAction -Execute $launcher -Argument (
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ' +
    "`"$applyScript`" -Silent")

$logonTrigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$logonTrigger.Delay = 'PT1M'

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName `
    -Action $action -Trigger $logonTrigger `
    -Principal $principal -Settings $settings `
    -Description 'Re-applies the custom File Explorer icon after Windows resets the inbox pin on logon.' `
    -Force | Out-Null

if (-not $Silent) {
    Write-Host "Registered $taskPath$taskName — runs 1 minute after logon."
    Write-Host "Target: $applyScript"
}
