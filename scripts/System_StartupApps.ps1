Add-Type -AssemblyName System.Windows.Forms

Start-Process 'ms-settings:startupapps'

[System.Windows.Forms.MessageBox]::Show(
    "Startup Apps settings opened.`n`nTurn off apps you do not need at login — this speeds up every boot.",
    "System Maintenance",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
) | Out-Null
