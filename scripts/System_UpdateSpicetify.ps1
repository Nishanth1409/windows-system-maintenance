# As needed — Update Spicetify: official Spotify installer + Spicetify iwr|iex + re-apply theme.
param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

. (Join-Path $PSScriptRoot 'System_SpotifySpicetifyCore.ps1')

function Show-UpdateResult {
    param([string[]]$Lines, [System.Windows.Forms.MessageBoxIcon]$Icon = 'Information')
    if ($Silent) { return }
    $body = ($Lines | ForEach-Object { '  - ' + $_ }) -join "`n"
    [System.Windows.Forms.MessageBox]::Show(
        "Update Spicetify finished.`n`n$body",
        'System Maintenance - Spicetify',
        'OK',
        $Icon
    ) | Out-Null
}

$notes = New-Object System.Collections.Generic.List[string]

try {
    Assert-UserPowerShellContext
} catch {
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, 'System Maintenance - Spicetify', 'OK', 'Warning') | Out-Null
    }
    exit 1
}

Stop-SpotifyProcess

$spotify = Install-OfficialSpotifyDesktop -Silent:$Silent
$notes.Add("Spotify: $($spotify.Message)") | Out-Null
if ($spotify.Status -eq 'Failed') {
    Show-UpdateResult -Lines $notes -Icon 'Warning'
    exit 1
}

$spicetify = Install-OfficialSpicetifyCli -Silent:$Silent
$notes.Add("Spicetify CLI: $($spicetify.Message)") | Out-Null
if ($spicetify.Status -eq 'Failed') {
    Show-UpdateResult -Lines $notes -Icon 'Warning'
    exit 1
}

$apply = Invoke-SpicetifyReapply -FreshSpotify
$notes.Add("Theme: $($apply.Message)") | Out-Null

$icon = if ($apply.Status -eq 'Failed') { 'Warning' } else { 'Information' }
Show-UpdateResult -Lines $notes -Icon $icon
exit $(if ($apply.Status -eq 'Failed') { 1 } else { 0 })
