# App update helpers — winget (all sources/scopes) + Chocolatey, full coverage, visible progress.

$script:WingetExecutablePath = $null

function Get-WingetExecutablePath {
    if ($script:WingetExecutablePath -and (Test-Path -LiteralPath $script:WingetExecutablePath)) {
        return $script:WingetExecutablePath
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe')
        (Join-Path ${env:ProgramFiles} 'WindowsApps\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\winget.exe')
    )

    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) {
            $script:WingetExecutablePath = $path
            return $path
        }
    }

    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source) -and $cmd.Source -like '*.exe') {
        $script:WingetExecutablePath = $cmd.Source
        return $cmd.Source
    }

    return $null
}

function Test-WingetAvailable {
    return $null -ne (Get-WingetExecutablePath)
}

function Format-WingetQuotedPath {
    $path = Get-WingetExecutablePath
    if (-not $path) { return 'winget' }
    return '"' + ($path -replace '"', '""') + '"'
}

function Join-WingetArgsForCmd {
    param([string[]]$Tokens)
    return ($Tokens | ForEach-Object {
        if ($_ -match '\s|"') { "`"$($_ -replace '"', '""')`"" } else { $_ }
    }) -join ' '
}

function Join-WingetCommandLine {
    param([string[]]$Tokens)
    return "$(Format-WingetQuotedPath) $(Join-WingetArgsForCmd -Tokens $Tokens)"
}

function Invoke-WingetOutput {
    param(
        [string[]]$WingetArgs,
        [int]$TimeoutSeconds = 180
    )

    $exe = Get-WingetExecutablePath
    if (-not $exe) {
        Write-Warning 'WinGet executable not found. Repair App Installer in Microsoft Store, or run: winget source reset --force'
        return @()
    }

    $argLine = Join-WingetArgsForCmd -Tokens $WingetArgs
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $exe
        $psi.Arguments = $argLine
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true

        $proc = [System.Diagnostics.Process]::Start($psi)
        if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
            try { $proc.Kill() } catch { }
            Write-Warning "WinGet timed out after $TimeoutSeconds seconds: winget $($WingetArgs -join ' ')"
            return @()
        }

        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $text = ($stdout + "`n" + $stderr).Trim()
        if (-not $text) { return @() }
        return @($text -split "`r?`n")
    } catch {
        Write-Warning "WinGet failed: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-WingetCommand {
    param(
        [string[]]$WingetArgs,
        [int]$TimeoutSeconds = 3600
    )

    $null = Invoke-WingetOutput -WingetArgs $WingetArgs -TimeoutSeconds $TimeoutSeconds
}

function Test-ProtectedAppPackage {
    param(
        [string]$Id = '',
        [string]$Name = ''
    )
    if ($Id -eq 'Nilesoft.Shell') { return $true }
    $lower = $Name.ToLowerInvariant()
    if ($lower -eq 'nilesoft-shell' -or $lower -like '*nilesoft*shell*') { return $true }
    if ($Id -like '*Nilesoft*') { return $true }
    return $false
}

function Test-IsSpotifyPackage {
    param($Package)

    if (-not $Package) { return $false }
    if ($Package.Id -eq 'Spotify.Spotify') { return $true }
    $lower = $Package.Name.ToLowerInvariant()
    if ($lower -eq 'spotify' -or $lower -like 'spotify*') { return $true }
    return $false
}

function Test-SpotifyHadPendingUpdate {
    param($Scan)

    if (-not $Scan) { return $false }
    $all = @($Scan.WingetMachine) + @($Scan.WingetUser) + @($Scan.Chocolatey)
    return ($all | Where-Object { Test-IsSpotifyPackage $_ }).Count -gt 0
}

function Get-SpotifyDesktopVersion {
    $path = Join-Path $env:APPDATA 'Spotify\Spotify.exe'
    if (-not (Test-Path $path)) { return $null }
    return (Get-Item $path).VersionInfo.FileVersion
}

function Test-SpotifyWasUpdatedInSession {
    param(
        [Parameter(Mandatory = $true)]
        $PreScan,
        [Parameter(Mandatory = $true)]
        $PostScan,
        [string]$VersionBefore = $null,
        [string]$VersionAfter = $null,
        [array]$UpgradeResults = @()
    )

    if ((Test-SpotifyHadPendingUpdate -Scan $PreScan) -and -not (Test-SpotifyHadPendingUpdate -Scan $PostScan)) {
        return $true
    }

    if ($VersionBefore -and $VersionAfter -and ($VersionBefore -ne $VersionAfter)) {
        return $true
    }

    foreach ($result in $UpgradeResults) {
        if (-not $result -or $result.Skipped) { continue }
        $spotifyPkgs = @($result.Packages | Where-Object { Test-IsSpotifyPackage $_ })
        if ($spotifyPkgs.Count -eq 0) { continue }
        if ($result.Upgraded) { return $true }
        if ($result.Remaining) {
            $stillPending = @($result.Remaining | Where-Object { Test-IsSpotifyPackage $_ })
            if ($stillPending.Count -eq 0) { return $true }
        }
    }

    return $false
}

function Get-UpgradeScanSnapshotPath {
    $dir = Join-Path $env:LOCALAPPDATA 'SystemMaintenance'
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    return Join-Path $dir 'PreScan.clixml'
}

function Save-UpgradeScanSnapshot {
    param([string]$Path = (Get-UpgradeScanSnapshotPath))

    $scan = Get-ComprehensiveUpgradeScan
    $scan | Export-Clixml -Path $Path -Force
    return $Path
}

function Get-UpgradeScanSnapshot {
    param([string]$Path = (Get-UpgradeScanSnapshotPath))

    if (-not (Test-Path $Path)) { return $null }
    return Import-Clixml $Path
}

function Get-WingetUpgradeArgTokens {
    param(
        [ValidateSet('machine', 'user')]
        [string]$Scope,
        [string]$Source = ''
    )

    # In-place upgrade only — no --force or --uninstall-previous (those wipe apps like Chrome).
    $tokens = @(
        '--all',
        '--include-unknown',
        '--include-pinned',
        '--scope', $Scope,
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity',
        '-h'
    )
    if ($Source) {
        $tokens += @('--source', $Source)
    }
    return $tokens
}

function ConvertTo-WingetVersion {
    param([string]$Version)
    $clean = ($Version -replace '[^\d\.]', '')
    if (-not $clean) { return [version]'0.0' }
    try { return [version]$clean } catch { return [version]'0.0' }
}

function Get-WingetPackageVersion {
    param(
        [ValidateSet('machine', 'user')]
        [string]$Scope,
        [string]$Id
    )

    $output = Invoke-WingetOutput @(
        'list', '--id', $Id, '--scope', $Scope,
        '--accept-source-agreements', '--disable-interactivity'
    )
    $escapedId = [regex]::Escape($Id)
    $pattern = '^(?<name>.+?)\s+' + $escapedId + '\s+(?<ver>\S+)'
    foreach ($line in $output) {
        if ($line -match $pattern) {
            return $matches['ver']
        }
    }
    return $null
}

function Get-WingetPerPackageArgTokens {
    param(
        [Parameter(Mandatory = $true)]
        $Package
    )

    # Match by installed display name — --id alone fails for some MSI entries (e.g. PowerShell 7.5.3.0-x64).
    $tokens = @(
        'upgrade',
        '--exact',
        '--name', $Package.Name,
        '--include-unknown',
        '--include-pinned',
        '--scope', $Package.Scope,
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity',
        '-h'
    )
    if ($Package.Source) {
        $tokens += @('--source', $Package.Source)
    }
    return $tokens
}

function Get-WingetUninstallArgTokens {
    param(
        [Parameter(Mandatory = $true)]
        $Package
    )

    return @(
        'uninstall',
        '--exact',
        '--name', $Package.Name,
        '--scope', $Package.Scope,
        '--disable-interactivity',
        '-h'
    )
}

function Repair-WingetPackagesBeforeUpgrade {
    param([array]$Packages)

    $notes = [System.Collections.Generic.List[string]]::new()
    foreach ($pkg in $Packages) {
        if ($pkg.Id -ne 'Microsoft.PowerShell' -or $pkg.Scope -ne 'machine') { continue }

        $userVersion = Get-WingetPackageVersion -Scope user -Id 'Microsoft.PowerShell'
        $targetVersion = ConvertTo-WingetVersion $pkg.Available
        $userOk = $false
        if ($userVersion) {
            $userOk = (ConvertTo-WingetVersion $userVersion) -ge $targetVersion
        }

        $uninstallArgs = Get-WingetUninstallArgTokens -Package $pkg
        Invoke-WingetCommand -WingetArgs $uninstallArgs | Out-Null

        if ($userOk) {
            $notes.Add("PowerShell: removed stale machine $($pkg.Name); kept user PowerShell $userVersion") | Out-Null
            continue
        }

        Invoke-WingetCommand -WingetArgs @(
            'install', '--id', 'Microsoft.PowerShell', '--scope', 'machine',
            '--accept-package-agreements', '--accept-source-agreements',
            '--disable-interactivity', '-h'
        ) | Out-Null
        $notes.Add('PowerShell: removed stale machine copy and installed latest machine-wide') | Out-Null
    }

    return @($notes)
}

function Get-WingetUpgradeList {
    param(
        [ValidateSet('machine', 'user')]
        [string]$Scope = 'machine'
    )

    if (-not (Test-WingetAvailable)) { return @() }

    $output = Invoke-WingetOutput @(
        'upgrade',
        '--include-unknown',
        '--include-pinned',
        '--scope', $Scope,
        '--accept-source-agreements',
        '--disable-interactivity'
    )

    $packages = [System.Collections.Generic.List[object]]::new()
    $seen = @{}

    foreach ($line in $output) {
        if ($line -notmatch '\S') { continue }
        if ($line -match '^[\s\\|/\-\.]+$') { continue }
        if ($line -match '^(Windows Package Manager|Copyright|No installed package|The following packages)') { continue }
        if ($line -match '^(Name\s+Id|----+)') { continue }
        if ($line -match '^\d+ upgrades? available') { continue }

        if ($line -match '^(?<name>.+?)\s+(?<id>[A-Za-z0-9][\w\.\-]*\.[\w\.\-]+)\s+(?<ver>\S+)\s+(?<avail>\S+)\s+(?<src>\S+)\s*$') {
            $id = $matches['id']
            $key = "$Scope|$id"
            if ($seen.ContainsKey($key)) { continue }
            $seen[$key] = $true
            $packages.Add([PSCustomObject]@{
                Name      = $matches['name'].Trim()
                Id        = $id
                Version   = $matches['ver']
                Available = $matches['avail']
                Scope     = $Scope
                Source    = $matches['src']
                Manager   = 'winget'
            }) | Out-Null
        }
    }

    $filtered = @($packages | Where-Object { -not (Test-ProtectedAppPackage -Id $_.Id -Name $_.Name) })
    return $filtered
}

function Get-WingetSources {
    $output = Invoke-WingetOutput @('source', 'list')
    $sources = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $output) {
        if ($line -match '^(Name\s+Argument|----+)') { continue }
        if ($line -match '^(msstore|winget|winget-font)\b') {
            $name = ($line -split '\s+', 2)[0]
            if ($name -and -not $sources.Contains($name)) {
                $sources.Add($name) | Out-Null
            }
        }
    }
    if ($sources.Count -eq 0) {
        return @('winget', 'msstore', 'winget-font')
    }
    return @($sources)
}

function Format-WingetUpgradeSummary {
    param(
        [array]$Packages,
        [string]$ScopeLabel
    )

    if (-not $Packages -or $Packages.Count -eq 0) {
        return "$ScopeLabel`n  (no updates available)"
    }

    $lines = foreach ($p in $Packages) {
        $src = if ($p.Source) { " [$($p.Source)]" } else { '' }
        "  - $($p.Name)  [$($p.Version) -> $($p.Available)]$src"
    }
    return "$ScopeLabel ($($Packages.Count))`n$($lines -join "`n")"
}

function New-WingetUpgradeBatch {
    param(
        [array]$Packages,
        [string]$Title,
        [string]$LogFile,
        [ValidateSet('machine', 'user')]
        [string]$Scope
    )

    $batchPath = Join-Path $env:TEMP ("winget-upgrade-{0:yyyyMMddHHmmss}.bat" -f (Get-Date))
    $wingetExe = Format-WingetQuotedPath
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('@echo off') | Out-Null
    $lines.Add('setlocal EnableDelayedExpansion') | Out-Null
    $lines.Add("title $Title") | Out-Null
    $lines.Add('color 0B') | Out-Null
    $lines.Add('echo.') | Out-Null
    $lines.Add('echo  ========================================') | Out-Null
    $lines.Add("echo   $Title") | Out-Null
    $lines.Add('echo  ========================================') | Out-Null
    $lines.Add('echo  Sources: winget + Microsoft Store + fonts') | Out-Null
    $lines.Add('echo  Nilesoft Shell: skipped (not updated, not touched)') | Out-Null
    $lines.Add('echo  Mode: in-place upgrade only (keeps extensions, shortcuts, settings)') | Out-Null
    $lines.Add(('echo Log: {0}' -f $LogFile)) | Out-Null
    $lines.Add('echo.') | Out-Null
    $lines.Add(('echo === {0} ===' -f $Title) + (' >> "' + $LogFile + '"')) | Out-Null

    $logAppend = ' >> "' + $LogFile + '"'

    $psRepair = @($Packages | Where-Object { $_.Id -eq 'Microsoft.PowerShell' -and $_.Scope -eq 'machine' })
    if ($psRepair.Count -gt 0) {
        $lines.Add('echo.') | Out-Null
        $lines.Add('echo [Step 0] Repair stale machine PowerShell (installer technology mismatch)...') | Out-Null
        foreach ($pkg in $psRepair) {
            $uninstallArgs = Join-WingetArgsForCmd (Get-WingetUninstallArgTokens -Package $pkg)
            $lines.Add(('{0} {1}' -f $wingetExe, $uninstallArgs) + $logAppend + ' 2>&1') | Out-Null
            $lines.Add('echo          Removed stale machine copy if present') | Out-Null
        }
    }

    $lines.Add('echo.') | Out-Null
    $lines.Add('echo [Step 1] Bulk upgrade — ALL sources combined (except Nilesoft)...') | Out-Null
    $bulkAll = Join-WingetArgsForCmd (Get-WingetUpgradeArgTokens -Scope $Scope)
    $lines.Add(('{0} {1}' -f $wingetExe, $bulkAll) + $logAppend + ' 2>&1') | Out-Null

    $sourceLabels = @{
        'winget'      = 'Winget community catalog'
        'msstore'     = 'Microsoft Store'
        'winget-font' = 'Fonts'
    }
    $step = 2
    foreach ($src in (Get-WingetSources)) {
        $label = if ($sourceLabels.ContainsKey($src)) { $sourceLabels[$src] } else { $src }
        $lines.Add('echo.') | Out-Null
        $lines.Add(('echo [Step {0}] Bulk upgrade — {1}...' -f $step, $label)) | Out-Null
        $bulkSrc = Join-WingetArgsForCmd (Get-WingetUpgradeArgTokens -Scope $Scope -Source $src)
        $lines.Add(('{0} {1}' -f $wingetExe, $bulkSrc) + $logAppend + ' 2>&1') | Out-Null
        $step++
    }

    $lines.Add('echo.') | Out-Null
    $lines.Add('echo [Step {0}] Per-app targeted upgrades (nothing skipped)...' -f $step) | Out-Null

    $total = $Packages.Count
    $index = 0
    foreach ($pkg in $Packages) {
        $index++
        $safeName = $pkg.Name -replace '"', "'"
        $srcTag = if ($pkg.Source) { " [$($pkg.Source)]" } else { '' }
        $lines.Add('echo.') | Out-Null
        $lines.Add(('echo [{0}/{1}] Updating: {2}{3}' -f $index, $total, $safeName, $srcTag)) | Out-Null
        $lines.Add(('echo          {0} -^> {1}' -f $pkg.Version, $pkg.Available)) | Out-Null
        if ($pkg.Id -eq 'Microsoft.PowerShell' -and $pkg.Scope -eq 'machine') {
            $lines.Add('echo          Skipped — repaired in Step 0 (winget cannot in-place upgrade this MSI)') | Out-Null
            continue
        }
        $perArgs = Join-WingetArgsForCmd (Get-WingetPerPackageArgTokens -Package $pkg)
        $lines.Add(('{0} {1}' -f $wingetExe, $perArgs) + $logAppend + ' 2>&1') | Out-Null
        $lines.Add('if errorlevel 1 (echo          WARNING: retry or manual check) else (echo          OK)') | Out-Null
    }

    $lines.Add('echo.') | Out-Null
    $lines.Add('echo  All winget update passes completed.') | Out-Null
    $lines.Add('echo  Window closes in 10 seconds...') | Out-Null
    $lines.Add('timeout /t 10 /nobreak >nul') | Out-Null
    $lines.Add('exit /b 0') | Out-Null

    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($batchPath, $lines, $utf8)
    return $batchPath
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ChocolateyAvailable {
    return $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
}

function Get-ChocoUpgradeList {
    if (-not (Test-ChocolateyAvailable)) { return @() }

    $output = cmd.exe /c 'choco outdated --limit-output --ignore-pinned 2>&1'
    if ($null -eq $output) { return @() }
    $lines = if ($output -is [string]) { @($output) } else { @($output | ForEach-Object { $_.ToString() }) }

    $packages = [System.Collections.Generic.List[object]]::new()
    foreach ($line in $lines) {
        if ($line -notmatch '\|') { continue }
        if ($line -match '^(Chocolatey v|Outdated|Enjoy|https?://)') { continue }
        $parts = $line -split '\|'
        if ($parts.Count -lt 3) { continue }
        $packages.Add([PSCustomObject]@{
            Name      = $parts[0]
            Id        = $parts[0]
            Version   = $parts[1]
            Available = $parts[2]
            Scope     = 'machine'
            Source    = 'chocolatey'
            Manager   = 'chocolatey'
        }) | Out-Null
    }
    $filtered = @($packages | Where-Object { -not (Test-ProtectedAppPackage -Name $_.Name) })
    return $filtered
}

function Format-ChocoUpgradeSummary {
    param([array]$Packages)

    if (-not $Packages -or $Packages.Count -eq 0) {
        return "Chocolatey`n  (no updates available)"
    }
    $lines = foreach ($p in $Packages) {
        "  - $($p.Name)  [$($p.Version) -> $($p.Available)]"
    }
    return "Chocolatey ($($Packages.Count))`n$($lines -join "`n")"
}

function New-ChocoUpgradeBatch {
    param(
        [array]$Packages,
        [string]$LogFile
    )

    $batchPath = Join-Path $env:TEMP ("choco-upgrade-{0:yyyyMMddHHmmss}.bat" -f (Get-Date))
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('@echo off') | Out-Null
    $lines.Add('title System Maintenance - Chocolatey Updates') | Out-Null
    $lines.Add('color 0E') | Out-Null
    $lines.Add('echo.') | Out-Null
    $lines.Add('echo  ========================================') | Out-Null
    $lines.Add('echo   Chocolatey - Update ALL Packages') | Out-Null
    $lines.Add('echo  ========================================') | Out-Null
    $lines.Add(('echo Log: {0}' -f $LogFile)) | Out-Null
    $lines.Add('echo.') | Out-Null

    $logAppend = ' >> "' + $LogFile + '"'
    $lines.Add('echo [Step 0] Outdated packages:') | Out-Null
    $lines.Add('choco outdated' + $logAppend + ' 2>&1') | Out-Null
    $lines.Add('echo.') | Out-Null
    $lines.Add('echo [Step 1] Upgrade ALL except nilesoft-shell (Nilesoft not touched)...') | Out-Null
    $lines.Add('choco upgrade all -y --exclude="nilesoft-shell"' + $logAppend + ' 2>&1') | Out-Null

    if ($Packages.Count -gt 0) {
        $lines.Add('echo.') | Out-Null
        $lines.Add('echo [Step 2] Per-package upgrades...') | Out-Null
        $i = 0
        foreach ($pkg in $Packages) {
            $i++
            $safeName = $pkg.Name -replace '"', "'"
            $lines.Add(('echo [{0}/{1}] {2} ({3} -^> {4})' -f $i, $Packages.Count, $safeName, $pkg.Version, $pkg.Available)) | Out-Null
            $lines.Add(('choco upgrade {0} -y' -f $pkg.Name) + $logAppend + ' 2>&1') | Out-Null
        }
    }

    $lines.Add('echo.') | Out-Null
    $lines.Add('echo  Chocolatey updates completed.') | Out-Null
    $lines.Add('timeout /t 10 /nobreak >nul') | Out-Null
    $lines.Add('exit /b 0') | Out-Null

    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($batchPath, $lines, $utf8)
    return $batchPath
}

function Start-ChocoUpgradeSession {
    param([switch]$Silent)

    if (-not (Test-ChocolateyAvailable)) {
        return [PSCustomObject]@{
            Manager  = 'chocolatey'
            Skipped  = $true
            Packages = @()
            ExitCode = 0
            Message  = 'Chocolatey not installed'
        }
    }

    $packages = Get-ChocoUpgradeList
    $logFile = Join-Path $env:TEMP ("choco-{0:yyyyMMddHHmmss}.log" -f (Get-Date))
    $wantElevation = -not (Test-IsAdministrator)

    if ($Silent) {
        $cmdLine = "choco upgrade all -y --exclude=`"nilesoft-shell`" >> `"$logFile`" 2>&1"
        $startParams = @{
            FilePath     = 'cmd.exe'
            ArgumentList = '/c', $cmdLine
            Wait         = $true
            PassThru     = $true
            WindowStyle  = 'Hidden'
        }
        if ($wantElevation) { $startParams['Verb'] = 'RunAs' }
        $proc = Start-Process @startParams
        return [PSCustomObject]@{
            Manager  = 'chocolatey'
            Skipped  = $false
            Packages = $packages
            ExitCode = if ($proc) { $proc.ExitCode } else { 1 }
            LogFile  = $logFile
        }
    }

    $batchPath = New-ChocoUpgradeBatch -Packages $packages -LogFile $logFile
    $startParams = @{
        FilePath     = 'cmd.exe'
        ArgumentList = '/c', "`"$batchPath`""
        Wait         = $true
        PassThru     = $true
        WindowStyle  = 'Normal'
    }
    if ($wantElevation) { $startParams['Verb'] = 'RunAs' }
    $proc = Start-Process @startParams
    try { Remove-Item $batchPath -Force -ErrorAction SilentlyContinue } catch { }

    return [PSCustomObject]@{
        Manager  = 'chocolatey'
        Skipped  = $false
        Packages = $packages
        ExitCode = if ($proc) { $proc.ExitCode } else { 1 }
        LogFile  = $logFile
    }
}

function Get-ComprehensiveUpgradeScan {
    $machine = Get-WingetUpgradeList -Scope machine
    $user = Get-WingetUpgradeList -Scope user
    $choco = Get-ChocoUpgradeList

    return [PSCustomObject]@{
        WingetMachine = $machine
        WingetUser    = $user
        Chocolatey    = $choco
        TotalCount    = $machine.Count + $user.Count + $choco.Count
    }
}

function Format-ComprehensiveUpgradeScan {
    param($Scan)

    return @(
        '=== WINGET (all sources: winget + Microsoft Store + fonts) ==='
        ''
        (Format-WingetUpgradeSummary -Packages $Scan.WingetMachine -ScopeLabel 'Administrator (machine-wide)')
        ''
        (Format-WingetUpgradeSummary -Packages $Scan.WingetUser -ScopeLabel 'User (per-user)')
        ''
        '=== CHOCOLATEY ==='
        ''
        (Format-ChocoUpgradeSummary -Packages $Scan.Chocolatey)
    ) -join "`n"
}

function Get-RemainingUpgradeScan {
    return Get-ComprehensiveUpgradeScan
}

function Start-WingetUpgradeSession {
    param(
        [ValidateSet('machine', 'user')]
        [string]$Scope,
        [switch]$Elevate,
        [switch]$Silent
    )

    $scopeLabel = if ($Scope -eq 'machine') { 'Administrator (machine-wide)' } else { 'User (per-user)' }
    $wantElevation = $Elevate -and -not (Test-IsAdministrator)
    $packages = Get-WingetUpgradeList -Scope $Scope
    $repairNotes = @()
    if ($packages.Count -gt 0) {
        $repairNotes = Repair-WingetPackagesBeforeUpgrade -Packages $packages
        $packages = Get-WingetUpgradeList -Scope $Scope
    }
    $logFile = Join-Path $env:TEMP ("winget-$Scope-{0:yyyyMMddHHmmss}.log" -f (Get-Date))

    if ($Silent) {
        if ($packages.Count -eq 0) {
            $cmdLine = (Join-WingetCommandLine -Tokens (Get-WingetUpgradeArgTokens -Scope $Scope)) + " >> `"$logFile`" 2>&1"
            $startParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', $cmdLine
                Wait         = $true
                PassThru     = $true
                WindowStyle  = 'Hidden'
            }
            if ($wantElevation) { $startParams['Verb'] = 'RunAs' }
            $proc = Start-Process @startParams
            return [PSCustomObject]@{
                Scope      = $Scope
                ExitCode   = if ($proc) { $proc.ExitCode } else { 0 }
                Packages   = @()
                Upgraded   = $false
                LogFile    = $logFile
                ScopeLabel = $scopeLabel
                Skipped    = $true
            }
        }

        $cmdLine = (Join-WingetCommandLine -Tokens (Get-WingetUpgradeArgTokens -Scope $Scope)) + " >> `"$logFile`" 2>&1"
        $startParams = @{
            FilePath     = 'cmd.exe'
            ArgumentList = '/c', $cmdLine
            Wait         = $true
            PassThru     = $true
            WindowStyle  = 'Hidden'
        }
        if ($wantElevation) { $startParams['Verb'] = 'RunAs' }
        $proc = Start-Process @startParams

        foreach ($pkg in $packages) {
            $perCmd = (Join-WingetCommandLine -Tokens (Get-WingetPerPackageArgTokens -Package $pkg)) + " >> `"$logFile`" 2>&1"
            $perParams = @{
                FilePath     = 'cmd.exe'
                ArgumentList = '/c', $perCmd
                Wait         = $true
                WindowStyle  = 'Hidden'
            }
            if ($wantElevation) { $perParams['Verb'] = 'RunAs' }
            Start-Process @perParams | Out-Null
        }

        $output = if (Test-Path $logFile) { Get-Content $logFile -Raw -ErrorAction SilentlyContinue } else { '' }
        $remaining = Get-WingetUpgradeList -Scope $Scope

        return [PSCustomObject]@{
            Scope      = $Scope
            ExitCode   = if ($proc) { $proc.ExitCode } else { 1 }
            Packages   = $packages
            Remaining  = $remaining
            Upgraded   = $output -match 'Successfully installed|successfully upgraded|Downloading|upgraded'
            LogFile    = $logFile
            ScopeLabel = $scopeLabel
            Skipped    = $false
        }
    }

    $title = "System Maintenance - Winget ($scopeLabel)"
    $batchPath = New-WingetUpgradeBatch -Packages $packages -Title $title -LogFile $logFile -Scope $Scope
    $startParams = @{
        FilePath     = 'cmd.exe'
        ArgumentList = '/c', "`"$batchPath`""
        Wait         = $true
        PassThru     = $true
        WindowStyle  = 'Normal'
    }
    if ($wantElevation) { $startParams['Verb'] = 'RunAs' }
    $proc = Start-Process @startParams

    try { Remove-Item $batchPath -Force -ErrorAction SilentlyContinue } catch { }

    $output = if (Test-Path $logFile) { Get-Content $logFile -Raw -ErrorAction SilentlyContinue } else { '' }
    $remaining = Get-WingetUpgradeList -Scope $Scope

    return [PSCustomObject]@{
        Scope      = $Scope
        ExitCode   = if ($proc) { $proc.ExitCode } else { 1 }
        Packages   = $packages
        Remaining  = $remaining
        Upgraded   = $output -match 'Successfully installed|successfully upgraded|Downloading|upgraded'
        LogFile    = $logFile
        ScopeLabel = $scopeLabel
        Skipped    = ($packages.Count -eq 0)
    }
}
