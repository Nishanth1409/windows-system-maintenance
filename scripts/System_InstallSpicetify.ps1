param(
    [switch]$Silent,
    [switch]$AfterAppUpdate,
    [switch]$SpotifyUpdated,
    [switch]$Force
)

# Spicetify — https://spicetify.app/
# Official install (user PowerShell only):
#   iwr -useb https://raw.githubusercontent.com/spicetify/cli/main/install.ps1 | iex

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
. (Join-Path $PSScriptRoot 'System_SpotifySpicetifyCore.ps1')

$result = [PSCustomObject]@{ Status = 'Skipped'; Message = 'Spicetify already installed' }

try {
    Assert-UserPowerShellContext
} catch {
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message, 'System Maintenance', 'OK', 'Warning'
        ) | Out-Null
    }
    return [PSCustomObject]@{ Status = 'Skipped'; Message = $_.Exception.Message }
}

if ($AfterAppUpdate -and -not $SpotifyUpdated) {
    $result.Message = 'Skipped — Spotify was not updated this run'
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            "Spicetify runs only when Spotify was updated.`n`nSpotify had no update in this maintenance run.",
            'System Maintenance', 'OK', 'Information'
        ) | Out-Null
    }
    return $result
}

if ((Resolve-SpicetifyOnPath) -and -not $Force -and -not $AfterAppUpdate) {
    if (-not $Silent) {
        [System.Windows.Forms.MessageBox]::Show(
            "Spicetify is already installed.`n`nUpdate All Apps refreshes Spotify + Spicetify automatically as its final step.",
            'System Maintenance', 'OK', 'Information'
        ) | Out-Null
    }
    return $result
}

if ($AfterAppUpdate -and $SpotifyUpdated -and (Resolve-SpicetifyOnPath)) {
    $reapply = Join-Path $PSScriptRoot 'System_ReapplySpicetify.ps1'
    if (Test-Path $reapply) {
        & $reapply -Silent | Out-Null
        return [PSCustomObject]@{
            Status  = 'Updated'
            Message = 'Re-applied to Spotify after update.'
        }
    }
}

$installed = Install-OfficialSpicetifyCli -Silent:$Silent
if ($installed.Status -eq 'Failed') {
  return [PSCustomObject]@{ Status = 'Failed'; Message = $installed.Message }
}

$result.Status = 'Installed'
$result.Message = $installed.Message

if (Test-SpotifyDesktopInstalled) {
    $apply = Invoke-SpicetifyReapply
    if ($apply.Status -eq 'Applied') {
        $result.Message += ' ' + $apply.Message
    }
}

if (-not $Silent -and $result.Status -ne 'Skipped') {
    $icon = if ($result.Status -eq 'Failed') { 'Warning' } else { 'Information' }
    [System.Windows.Forms.MessageBox]::Show($result.Message, 'System Maintenance', 'OK', $icon) | Out-Null
}

return $result
