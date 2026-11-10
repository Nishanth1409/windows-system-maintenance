# Shared Spotify + Spicetify helpers (user PowerShell only).
$script:SpotifySetupUri = 'https://download.scdn.co/SpotifySetup.exe'

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
        throw 'Spotify and Spicetify updates must run as the normal user, not Administrator.'
    }
}

function Test-SpotifyDesktopInstalled {
    return Test-Path (Join-Path $env:APPDATA 'Spotify\Spotify.exe')
}

function Get-SpotifyProcesses {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'Spotify*' -or
        ($_.Path -and $_.Path -like '*\Spotify\*')
    }
}

function Stop-SpotifyProcess {
    param([int]$WaitSeconds = 20)

    # Official SpotifySetup.exe relaunches the app after /silent. Close the
    # window first, then force-kill leftover helpers so Spicetify is never
    # blocked on a y/yes "Spotify is still running" prompt.
    for ($i = 0; $i -lt 3; $i++) {
        Get-SpotifyProcesses | ForEach-Object {
            try { $_.CloseMainWindow() | Out-Null } catch { }
        }
        Start-Sleep -Milliseconds 800
        Get-SpotifyProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
        if (-not (Get-SpotifyProcesses)) { break }
    }

    $deadline = (Get-Date).AddSeconds($WaitSeconds)
    while ((Get-Date) -lt $deadline -and (Get-SpotifyProcesses)) {
        Get-SpotifyProcesses | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 400
    }

    return -not [bool](Get-SpotifyProcesses)
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

    # Installer detaches Spotify.exe after setup.exe exits.
    Start-Sleep -Seconds 3
    $closed = Stop-SpotifyProcess
    if (-not $closed) {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = 'Spotify updated but would not close. Close Spotify, then run Update All Apps again.'
        }
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
        Message = "Spotify desktop app from download.scdn.co ($label, closed after install)."
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

function Get-SpicetifyArchTag {
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'ARM64' { return 'arm64' }
        'AMD64' { return 'x64' }
        default { return 'x32' }
    }
}

function Install-SpicetifyFromGithubZip {
    param([switch]$Silent)

    $folder = Join-Path $env:LOCALAPPDATA 'spicetify'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    try {
        if (-not $Silent) { Write-Host 'Fetching latest Spicetify CLI...' }
        $headers = @{ 'User-Agent' = 'SystemMaintenance' }
        $latest = Invoke-RestMethod -Uri 'https://api.github.com/repos/spicetify/cli/releases/latest' -Headers $headers
        $version = [string]$latest.tag_name -replace '^v', ''
        $arch = Get-SpicetifyArchTag
        $zip = Join-Path $env:TEMP 'spicetify.zip'
        $uri = "https://github.com/spicetify/cli/releases/download/v$version/spicetify-$version-windows-$arch.zip"
        Invoke-WebRequest -Uri $uri -OutFile $zip -UseBasicParsing -Headers $headers
        Expand-Archive -Path $zip -DestinationPath $folder -Force
        Remove-Item $zip -Force -ErrorAction SilentlyContinue
    } catch {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = "Spicetify download failed: $($_.Exception.Message)"
        }
    }

    $exe = Join-Path $folder 'spicetify.exe'
    if (-not (Test-Path $exe)) {
        return [PSCustomObject]@{
            Status  = 'Failed'
            Message = 'Spicetify zip extracted but spicetify.exe was not found.'
        }
    }

    $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
    if ($userPath -notlike "*$folder*") {
        [Environment]::SetEnvironmentVariable('PATH', "$userPath;$folder", 'User')
    }
    if (($env:PATH -split ';') -notcontains $folder) {
        $env:PATH = "$env:PATH;$folder"
    }

    return [PSCustomObject]@{
        Status  = 'Installed'
        Message = "Spicetify CLI v$version installed (no prompts)."
    }
}

function Install-OfficialSpicetifyCli {
    param([switch]$Silent)

    # Never run the official install.ps1 unattended: it now PromptForChoice
    # "already installed / fix your installation?" which waits for y/yes.
    if (Resolve-SpicetifyOnPath) {
        Stop-SpotifyProcess | Out-Null
        $upd = Invoke-SpicetifyCommand -CommandArgs @('update')
        if ($upd.ExitCode -ne 0 -and $upd.Output -notmatch '(?i)up-to-date|already') {
            $fresh = Install-SpicetifyFromGithubZip -Silent:$Silent
            if ($fresh.Status -eq 'Failed') { return $fresh }
            return [PSCustomObject]@{
                Status  = 'Installed'
                Message = 'Spicetify CLI refreshed from GitHub zip (no prompts).'
            }
        }
        return [PSCustomObject]@{
            Status  = 'Installed'
            Message = 'Spicetify CLI already present; update ran without prompts.'
        }
    }

    return Install-SpicetifyFromGithubZip -Silent:$Silent
}

function Invoke-SpicetifyCommand {
    param(
        [string[]]$CommandArgs,
        [switch]$AllowRestart
    )
    if (-not (Resolve-SpicetifyOnPath)) {
        return [PSCustomObject]@{ ExitCode = 1; Output = 'spicetify not found' }
    }

    Stop-SpotifyProcess | Out-Null

    # -n / --no-restart: we close Spotify ourselves; do not let CLI relaunch it
    # mid-flow (that is what left the app open and blocked the next step).
    $flags = @('-n')
    if ($AllowRestart) { $flags = @() }

    # Pipe y/yes in case an older CLI still reads stdin. Host PromptForChoice
    # is avoided by not using install.ps1.
    $nl = [Environment]::NewLine
    $autoYes = (('y' + $nl) * 8) + (('yes' + $nl) * 8)
    $output = $autoYes | & spicetify @flags @CommandArgs 2>&1 | Out-String
    $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
    Stop-SpotifyProcess | Out-Null
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
    Stop-SpotifyProcess | Out-Null

    # After a Spotify client update, docs say: close Spotify, then backup apply.
    # restore first when the previous backup no longer matches this build.
    if ($FreshSpotify) {
        $null = Invoke-SpicetifyCommand -CommandArgs @('restore')
        $steps.Add('restore') | Out-Null
        $apply = Invoke-SpicetifyCommand -CommandArgs @('backup', 'apply')
        $steps.Add('backup apply') | Out-Null
    } else {
        $apply = Invoke-SpicetifyCommand -CommandArgs @('backup', 'apply')
        $steps.Add('backup apply') | Out-Null
    }

    if (-not (Test-SpicetifyResultOk $apply)) {
        $null = Invoke-SpicetifyCommand -CommandArgs @('update')
        $apply = Invoke-SpicetifyCommand -CommandArgs @('restore', 'backup', 'apply')
        $steps.Add('retry: update then restore backup apply') | Out-Null
    }

    Stop-SpotifyProcess | Out-Null

    if (Test-SpicetifyResultOk $apply) {
        return [PSCustomObject]@{
            Status  = 'Applied'
            Message = ('Spicetify synced (' + ($steps -join ' → ') + '). Spotify left closed — open it when ready.')
        }
    }

    $hint = 'Close Spotify, then in user PowerShell run:'
    if ($apply.Output -match 'version mismatch') {
        $hint = 'Spotify may be newer than Spicetify supports. Wait for a Spicetify release, or run `spicetify update` then `spicetify backup apply`.'
    }

    return [PSCustomObject]@{
        Status  = 'Failed'
        Message = "$hint`n  spicetify restore backup apply"
    }
}

function Invoke-SpotifySpicetifyFullUpdate {
    param([switch]$Silent)

    $notes = New-Object System.Collections.Generic.List[string]

    try {
        Assert-UserPowerShellContext
    } catch {
        $notes.Add($_.Exception.Message) | Out-Null
        return [PSCustomObject]@{
            Status   = 'Failed'
            ExitCode = 1
            Notes    = @($notes)
        }
    }

    Stop-SpotifyProcess | Out-Null

    $spotify = Install-OfficialSpotifyDesktop -Silent:$Silent
    $notes.Add("Spotify: $($spotify.Message)") | Out-Null
    if ($spotify.Status -eq 'Failed') {
        return [PSCustomObject]@{
            Status   = 'Failed'
            ExitCode = 1
            Notes    = @($notes)
        }
    }

    Stop-SpotifyProcess | Out-Null

    $spicetify = Install-OfficialSpicetifyCli -Silent:$Silent
    $notes.Add("Spicetify CLI: $($spicetify.Message)") | Out-Null
    if ($spicetify.Status -eq 'Failed') {
        return [PSCustomObject]@{
            Status   = 'Failed'
            ExitCode = 1
            Notes    = @($notes)
        }
    }

    Stop-SpotifyProcess | Out-Null

    $apply = Invoke-SpicetifyReapply -FreshSpotify
    $notes.Add("Theme: $($apply.Message)") | Out-Null
    $exitCode = if ($apply.Status -eq 'Failed') { 1 } else { 0 }

    Stop-SpotifyProcess | Out-Null

    return [PSCustomObject]@{
        Status   = if ($exitCode -eq 0) { 'Completed' } else { 'Failed' }
        ExitCode = $exitCode
        Notes    = @($notes)
    }
}
