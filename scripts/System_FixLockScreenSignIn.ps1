#Requires -Version 5.1
<#
.SYNOPSIS
  Lock screen: 12-hour clock with AM/PM + require sign-in when the PC wakes.
#>
param(
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Set-InternationalTimeFormat {
    param([string]$RootPath)

    if (-not (Test-Path $RootPath)) {
        Write-Log "  Skip (missing): $RootPath" 'DarkYellow'
        return $false
    }

    try {
        Set-ItemProperty -Path $RootPath -Name 'sShortTime' -Value 'h:mm tt' -Type String
        Set-ItemProperty -Path $RootPath -Name 'sTimeFormat' -Value 'h:mm:ss tt' -Type String
        Set-ItemProperty -Path $RootPath -Name 'sLongTime' -Value 'h:mm:ss tt' -Type String
        Set-ItemProperty -Path $RootPath -Name 'sTime' -Value ':' -Type String
        Set-ItemProperty -Path $RootPath -Name 's1159' -Value 'AM' -Type String
        Set-ItemProperty -Path $RootPath -Name 's2359' -Value 'PM' -Type String
        Set-ItemProperty -Path $RootPath -Name 'iTime' -Value '0' -Type String
        return $true
    } catch {
        Write-Log "  Skip (access denied): $RootPath" 'DarkYellow'
        return $false
    }
}

function Sync-InternationalSettingsToWelcomeScreen {
    if (-not (Get-Command Copy-UserInternationalSettingsToSystem -ErrorAction SilentlyContinue)) {
        Write-Log '  Copy-UserInternationalSettingsToSystem not available on this Windows build.' 'DarkYellow'
        return $false
    }

    try {
        Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $false
        Write-Log '  Copied format to welcome screen + system accounts.' 'Green'
        return $true
    } catch {
        Write-Log "  Copy-UserInternationalSettingsToSystem failed: $($_.Exception.Message)" 'DarkYellow'
        return $false
    }
}

function Send-IntlSettingsChange {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class IntlNotify {
  [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@ -ErrorAction SilentlyContinue

    $result = [UIntPtr]::Zero
    [void][IntlNotify]::SendMessageTimeout(
        [IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'intl', 2, 5000, [ref]$result)
}

function Restart-LockApp {
    $lockApp = Get-Process -Name LockApp -ErrorAction SilentlyContinue
    if ($lockApp) {
        $lockApp | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log '  Restarted LockApp (lock screen clock process).' 'Green'
    }
}

function Enable-RequireSignInOnWake {
    $commands = @(
        'powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1',
        'powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_NONE CONSOLELOCK 1',
        'powercfg /SETACTIVE SCHEME_CURRENT'
    )
    foreach ($cmd in $commands) {
        $null = cmd.exe /c $cmd 2>&1
    }

    $desktopKey = 'HKCU:\Control Panel\Desktop'
    if (-not (Test-Path $desktopKey)) {
        New-Item -Path $desktopKey -Force | Out-Null
    }
    Set-ItemProperty -Path $desktopKey -Name 'DelayLockInterval' -Value 0xFFFFFFFF -Type DWord
}

Write-Log '=== Lock screen: 12-hour AM/PM + sign-in on wake ===' 'Cyan'

Write-Log '[1/3] Setting 12-hour AM/PM format (lock screen uses Short time)...' 'Yellow'

if (-not (Get-PSDrive -Name HKU -PSProvider Registry -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS | Out-Null
}

$intlTargets = @(
    'HKCU:\Control Panel\International',
    'HKU:\.DEFAULT\Control Panel\International'
)

foreach ($sid in @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')) {
    $intlTargets += "Registry::HKEY_USERS\$sid\Control Panel\International"
}

$applied = 0
foreach ($target in $intlTargets) {
    if (Set-InternationalTimeFormat -RootPath $target) {
        Write-Log "  Updated: $target" 'Green'
        $applied++
    }
}

Write-Log '[2/3] Syncing to welcome screen (required for Win+L lock screen)...' 'Yellow'
$null = Sync-InternationalSettingsToWelcomeScreen
Send-IntlSettingsChange
Restart-LockApp

Write-Log '[3/3] Requiring sign-in when PC wakes from sleep...' 'Yellow'
Enable-RequireSignInOnWake
Write-Log '  Require password on wakeup: ON' 'Green'

Write-Log '=== Done ===' 'Green'
Write-Log 'Press Win+L now. You should see AM or PM next to the time.' 'Gray'
Write-Log 'If not, restart once — welcome-screen copy needs a reboot on some PCs.' 'Gray'

if (-not $Silent) {
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(
        @"
Lock screen clock set to 12-hour with AM/PM.

Press Win+L to check.
If AM/PM still missing, restart the laptop once.

Sign-in on wake: ON
"@,
        'System Maintenance',
        'OK',
        'Information'
    )
}
