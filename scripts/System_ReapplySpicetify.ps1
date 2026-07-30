# Re-apply Spicetify theme — PowerShell only (not CMD). Prefer System_UpdateSpicetify.ps1 for full update.
param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
. (Join-Path $PSScriptRoot 'System_SpotifySpicetifyCore.ps1')

function Show-Result {
    param([string]$Message, [System.Windows.Forms.MessageBoxIcon]$Icon = 'Information')
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            $Message, 'System Maintenance - Spicetify', 'OK', $Icon
        ) | Out-Null
    }
}

try {
    Assert-UserPowerShellContext
} catch {
    Show-Result $_.Exception.Message 'Warning'
    exit 1
}

if (-not (Test-SpotifyDesktopInstalled)) {
    Show-Result 'Spotify is not installed. Run System Maintenance → Update All Apps, or run System_UpdateSpicetify.ps1 manually.' 'Warning'
    exit 1
}

Stop-SpotifyProcess

if (-not (Resolve-SpicetifyOnPath)) {
    $installed = Install-OfficialSpicetifyCli -Silent:$Silent
    if ($installed.Status -eq 'Failed') {
        Show-Result $installed.Message 'Warning'
        exit 1
    }
}

$null = Invoke-SpicetifyCommand -CommandArgs @('update')
$apply = Invoke-SpicetifyReapply

if ($apply.Status -eq 'Failed') {
    Show-Result $apply.Message 'Warning'
    exit 1
}

Show-Result 'Spicetify re-applied successfully. Open Spotify.' 'Information'
exit 0
