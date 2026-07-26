Add-Type -AssemblyName System.Windows.Forms

$steps = @()

# 1) Windows Update scan
$usoClient = Join-Path $env:SystemRoot 'System32\UsoClient.exe'
if (Test-Path $usoClient) {
    Start-Process -FilePath $usoClient -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction SilentlyContinue
    $steps += 'Windows Update scan started'
} else {
    $steps += 'Windows Update scan skipped (UsoClient not found)'
}

Start-Sleep -Seconds 1

# 2) Security quick scan (background)
$scanStarted = $false
try {
    if (Get-Command Start-MpScan -ErrorAction Stop) {
        Start-Process powershell.exe -ArgumentList @(
            '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
            '-Command', 'Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue'
        ) -WindowStyle Hidden
        $scanStarted = $true
    }
} catch { }

if (-not $scanStarted) {
    $mpCmd = Join-Path ${env:ProgramFiles} 'Windows Defender\MpCmdRun.exe'
    if (Test-Path $mpCmd) {
        Start-Process -FilePath $mpCmd -ArgumentList '-Scan', '-ScanType', '1' -WindowStyle Hidden
        $scanStarted = $true
    }
}

if ($scanStarted) {
    $steps += 'Security quick scan running in background'
} else {
    $steps += 'Security scan — open Windows Security manually'
}

# 3) Offer app updates (winget can take a long time)
$choice = [System.Windows.Forms.MessageBox]::Show(
    "Software checkup started:`n`n  - $($steps -join "`n  - ")`n`nRun Update All Apps now?`n(Winget + Chocolatey; Spotify/Spicetify use separate menu item)`nThis can take several minutes.",
    "System Maintenance",
    [System.Windows.Forms.MessageBoxButtons]::YesNo,
    [System.Windows.Forms.MessageBoxIcon]::Question
)

if ($choice -eq [System.Windows.Forms.DialogResult]::Yes) {
    $updateScript = Join-Path $PSScriptRoot 'System_UpdateApps.ps1'
    if (Test-Path $updateScript) {
        & $updateScript
    }
}

Start-Process 'ms-settings:windowsupdate-action'
Start-Process 'ms-settings:startupapps'

[System.Windows.Forms.MessageBox]::Show(
    "Software checkup finished.`n`nOpened:`n  - Windows Update`n  - Startup Apps`n`nInstall Windows updates and disable unneeded startup apps.",
    "System Maintenance",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
