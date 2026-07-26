Add-Type -AssemblyName System.Windows.Forms

$usoClient = Join-Path $env:SystemRoot 'System32\UsoClient.exe'

if (Test-Path $usoClient) {
    Start-Process -FilePath $usoClient -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

Start-Process 'ms-settings:windowsupdate-action'

[System.Windows.Forms.MessageBox]::Show(
    "Windows Update scan started.`n`nSettings will open — install any available updates.`nRestart the PC if Windows asks you to.",
    "System Maintenance",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
