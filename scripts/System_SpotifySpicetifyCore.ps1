# Shared Spotify + Spicetify helpers (user PowerShell only).
$script:SpotifySetupUri = 'https://download.scdn.co/SpotifySetup.exe'
$script:SpicetifyInstallUri = 'https://raw.githubusercontent.com/spicetify/cli/main/install.ps1'

function Test-IsPowerShellHost {
    $proc = (Get-Process -Id $PID -ErrorAction SilentlyContinue).ProcessName
    return $proc -match '^(powershell|pwsh)$'
}

function Test-IsAdminSession {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal $id
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-UserPowerShellContext {
    if (-not (Test-IsPowerShellHost)) {
        throw 'Spicetify and Spotify updates must run in PowerShell only (not CMD).'
    }
    if (Test-IsAdminSession) {
        throw 'Run as normal user PowerShell, not Administrator. Use: System Maintenance → As needed → Update Spicetify'
    }
}

function Test-SpotifyDesktopInstalled {
    return Test-Path (Join-Path $env:APPDATA 'Spotify\Spotify.exe')
}

function Stop-SpotifyProcess {
    Get-Process -Name 'Spotify' -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.CloseMainWindow() | Out-Null } catch { }
    }
    Start-Sleep -Seconds 2
    Get-Process -Name 'Spotify' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

function Install-OfficialSpotifyDesktop {
    param([switch]$Silent)

    $wasInstalled = Test-SpotifyDesktopInstalled
    $installer = Join-Path $env:TEMP 'SpotifySetup.exe'
    try {
        if (-not $Silent) { Write-Host "Downloading Spotify from $script:SpotifySetupUri ..." }
        Invoke-WebRequest -Uri $script:SpotifySetupUri -OutFile $installer -UseBasicParsing
    } catch {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = "Spotify download failed: $($_.Exception.Message)"
        }
    }

    if (-not (Test-Path $installer)) {
        return [PSCustomObject]@{ Status = 'Failed'; Message = 'Spotify installer was not saved.' }
    }

    try {
        if (-not $Silent) { Write-Host 'Installing/updating Spotify (silent)...' }
        $proc = Start-Process -FilePath $installer -ArgumentList '/silent' -PassThru -Wait
        if ($proc.ExitCode -ne 0) {
            return [PSCustomObject]@{
                Status  = 'Failed'
                Message = "Spotify installer exited with code $($proc.ExitCode)."
            }
        }
    } catch {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = "Spotify install failed: $($_.Exception.Message)"
        }
    } finally {
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-SpotifyDesktopInstalled)) {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = 'Spotify installer finished but Spotify.exe was not found in %AppData%\Spotify.'
        }
    }

    $label = if ($wasInstalled) { 'Updated' } else { 'Installed' }
    return [PSCustomObject]@{
        Status  = $label
        Message = "Spotify desktop app from download.scdn.co ($label)."
    }
}

function Resolve-SpicetifyOnPath {
    if (Get-Command spicetify -ErrorAction SilentlyContinue) { return $true }
    $local = Join-Path $env:LOCALAPPDATA 'spicetify\spicetify.exe'
    if (Test-Path $local) {
        $env:Path = "$(Split-Path $local);$env:Path"
        return $true
    }
    return $false
}

function Get-PatchedSpicetifyInstallScript {
    $content = (Invoke-WebRequest -Uri $script:SpicetifyInstallUri -UseBasicParsing).Content
    # Hidden/menu PowerShell cannot answer prompts — auto-resume install and accept Marketplace (Yes).
    $content = $content -replace '(?ms)\$choice = \$Host\.UI\.PromptForChoice\(\s*''''\s*,\s*''Do you want to abort the installation process\?''[^\)]+\)', '$choice = 1'
    $content = $content -replace '(?ms)\$choice = \$Host\.UI\.PromptForChoice\(\s*''''\s*,\s*"`nDo you also want to install Spicetify Marketplace\?[^\)]+\)', '$choice = 0'
    return $content
}

function Install-OfficialSpicetifyCli {
    param([switch]$Silent)

    try {
        if (-not $Silent) { Write-Host 'Installing/updating Spicetify CLI from GitHub (auto-yes to prompts)...' }
        $installScript = Get-PatchedSpicetifyInstallScript
        Invoke-Expression $installScript
        Start-Sleep -Seconds 2
    } catch {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = "Spicetify install failed: $($_.Exception.Message)"
        }
    }

    if (-not (Resolve-SpicetifyOnPath)) {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = 'Spicetify install script finished but spicetify command was not found.'
        }
    }

    return [PSCustomObject]@{
        Status  = 'Installed'
        Message = 'Spicetify CLI installed/updated via iwr | iex (prompts answered Yes).'
    }
}

function Invoke-SpicetifyCommand {
    param([string[]]$CommandArgs)
    if (-not (Resolve-SpicetifyOnPath)) {
        return [PSCustomObject]@{ ExitCode = 1; Output = 'spicetify not found' }
    }
    # Pipe yes/y so CLI prompts never block hidden menu PowerShell.
    $autoYes = ("y$([Environment]::NewLine)" * 12)
    $output = $autoYes | & spicetify @CommandArgs 2>&1 | Out-String
    $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    return [PSCustomObject]@{ ExitCode = $code; Output = $output }
}

function Test-SpicetifyResultOk {
    param($Result)
    if ($Result.ExitCode -ne 0) { return $false }
    if ($Result.Output -match '(?i)Spotify version mismatch|Cannot find symbol for Custom app') { return $false }
    return $true
}

function Invoke-SpicetifyReapply {
    param([switch]$FreshSpotify)

    $steps = New-Object System.Collections.Generic.List[string]

    $upd = Invoke-SpicetifyCommand -CommandArgs @('update')
    $steps.Add('spicetify update') | Out-Null
    if (-not (Test-SpicetifyResultOk $upd)) {
        $upd = Invoke-SpicetifyCommand -CommandArgs @('update')
    }

    if ($FreshSpotify) {
        $null = Invoke-SpicetifyCommand -CommandArgs @('restore', 'backup')
        $steps.Add('restore backup (fresh Spotify)') | Out-Null
        $null = Invoke-SpicetifyCommand -CommandArgs @('backup')
        $steps.Add('backup (new Spotify build)') | Out-Null
    }

    $apply = Invoke-SpicetifyCommand -CommandArgs @('apply')
    $steps.Add('apply') | Out-Null

    if (-not (Test-SpicetifyResultOk $apply)) {
        $null = Invoke-SpicetifyCommand -CommandArgs @('update')
        $null = Invoke-SpicetifyCommand -CommandArgs @('restore', 'backup')
        $null = Invoke-SpicetifyCommand -CommandArgs @('backup')
        $apply = Invoke-SpicetifyCommand -CommandArgs @('apply')
        $steps.Add('retry: update → restore → backup → apply') | Out-Null
    }

    if (Test-SpicetifyResultOk $apply) {
        return [PSCustomObject]@{
            Status  = 'Applied'
            Message = ('Spicetify synced and applied (' + ($steps -join ' → ') + ').')
        }
    }

    $fallback = Invoke-SpicetifyCommand -CommandArgs @('restore', 'backup', 'apply')
    if (Test-SpicetifyResultOk $fallback) {
        return [PSCustomObject]@{
            Status  = 'Applied'
            Message = 'Spicetify restored from backup and applied.'
        }
    }

    $hint = 'Close Spotify, then in user PowerShell run:'
    if ($apply.Output -match 'version mismatch') {
        $hint = 'Spotify may be newer than Spicetify supports. Run `spicetify update` again, or use an older Spotify build from download.scdn.co.'
    }

    return [PSCustomObject]@{
        Status  = 'Failed'
        Message = "$hint`n  spicetify restore backup apply"
    }
}
