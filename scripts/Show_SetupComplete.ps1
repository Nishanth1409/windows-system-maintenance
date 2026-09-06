Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
$text = @(
    'System Maintenance is installed on this PC.',
    '',
    'Folder: C:\SystemMaintenance',
    '',
    'Right-click desktop - Show more options - System Maintenance',
    '',
    'Read GUIDE.md for the schedule.'
) -join [Environment]::NewLine

[void][System.Windows.Forms.MessageBox]::Show(
    $text,
    'Setup Complete',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
