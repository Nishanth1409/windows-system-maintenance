Add-Type -AssemblyName System.Windows.Forms

$started = $false

try {
    $defender = Get-Command Start-MpScan -ErrorAction Stop
    if ($defender) {
        Start-Process powershell.exe -ArgumentList @(
            '-NoProfile', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass',
            '-Command', 'Start-MpScan -ScanType QuickScan -ErrorAction SilentlyContinue'
        ) -WindowStyle Hidden
        $started = $true
    }
} catch { }

if (-not $started) {
    $mpCmd = Join-Path ${env:ProgramFiles} 'Windows Defender\MpCmdRun.exe'
    if (Test-Path $mpCmd) {
        Start-Process -FilePath $mpCmd -ArgumentList '-Scan', '-ScanType', '1' -WindowStyle Hidden
        $started = $true
    }
}

if ($started) {
    [System.Windows.Forms.MessageBox]::Show(
        "Windows Security quick scan started in the background.`n`nIt may take 5–15 minutes.`n`nOpen Windows Security later to see results.",
        "System Maintenance",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
} else {
    Start-Process 'windowsdefender://threat/'
    [System.Windows.Forms.MessageBox]::Show(
        "Could not start scan automatically.`n`nWindows Security will open — run Quick scan manually.",
        "System Maintenance",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
}
