# Internal/manual wrapper: official Spotify installer + Spicetify iwr|iex + re-apply theme.
# App update workflows call the same shared operation automatically as their final step.
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

$result = Invoke-SpotifySpicetifyFullUpdate -Silent:$Silent
$icon = if ($result.ExitCode -ne 0) { 'Warning' } else { 'Information' }
Show-UpdateResult -Lines $result.Notes -Icon $icon
exit $result.ExitCode
