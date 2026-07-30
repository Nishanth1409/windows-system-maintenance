# Update All Apps - winget all sources/scopes + Chocolatey, then Spotify + Spicetify.
Add-Type -AssemblyName System.Windows.Forms

$base = $PSScriptRoot
. (Join-Path $base 'System_WingetHelpers.ps1')
. (Join-Path $base 'System_SpotifySpicetifyCore.ps1')

function Add-UpdateNote {
    param($Result, [string]$Label)

    if ($Result.Skipped -and $Result.Manager -eq 'chocolatey' -and $Result.Message) {
        $script:updateNotes.Add(($Label + ': ' + $Result.Message)) | Out-Null
        return
    }
    if ($Result.Skipped) {
        $script:updateNotes.Add(($Label + ': no updates in scan')) | Out-Null
        return
    }
    if ($Result.Packages -and $Result.Packages.Count -gt 0) {
        $names = ($Result.Packages | ForEach-Object { $_.Name }) -join ', '
        $script:updateNotes.Add(($Label + ': processed ' + $Result.Packages.Count + ' - ' + $names)) | Out-Null
    } elseif ($Result.ExitCode -eq 0) {
        $script:updateNotes.Add(($Label + ': completed')) | Out-Null
    } else {
        $script:updateNotes.Add(($Label + ': finished - exit code ' + $Result.ExitCode)) | Out-Null
    }
    if ($Result.Remaining -and $Result.Remaining.Count -gt 0) {
        $left = ($Result.Remaining | ForEach-Object { $_.Name }) -join ', '
        $script:updateNotes.Add(($Label + ': still pending - ' + $left)) | Out-Null
    }
}

function Test-UpdateProceed {
    param(
        [string]$PromptText,
        [int]$IconValue
    )
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $PromptText,
        $script:updateDialogTitle,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        $IconValue
    )
    return $answer -eq [System.Windows.Forms.DialogResult]::Yes
}

function Start-AppUpdateFlow {
    $script:updateNotes = New-Object System.Collections.Generic.List[string]
    $script:updateDialogTitle = 'System Maintenance - Update All Apps'

    if (-not (Test-WingetAvailable)) {
        [System.Windows.Forms.MessageBox]::Show(
            @"
WinGet was not found.

Repair App Installer in Microsoft Store, or in user PowerShell run:
  winget source reset --force
  winget source update

Direct path (if winget alias is broken):
  & "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe" list
"@,
            'System Maintenance',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }

    $scan = Get-ComprehensiveUpgradeScan
    $scanText = Format-ComprehensiveUpgradeScan -Scan $scan

    $coverageLines = @(
        'Update coverage:',
        '  - Winget: community + Microsoft Store + fonts',
        '  - Scopes: Administrator machine + User',
        '  - Mode: in-place upgrade only (extensions, shortcuts, settings kept)',
        '  - Nilesoft Shell: not updated, not touched by maintenance',
        '  - Chocolatey: all except nilesoft-shell',
        '  - Final step: Spotify official installer + Spicetify update and theme re-apply'
    )
    $coverageNote = $coverageLines -join [Environment]::NewLine

    $iconInfo = [int][System.Windows.Forms.MessageBoxIcon]::Information
    $iconQuestion = [int][System.Windows.Forms.MessageBoxIcon]::Question
    $shouldProceed = $false

    if ($scan.TotalCount -eq 0) {
        $promptText = $scanText + "`n`n" + $coverageNote + "`n`nNo updates found in scan.`n`nRun full update passes anyway?"
        $shouldProceed = Test-UpdateProceed -PromptText $promptText -IconValue $iconInfo
    }
    if ($scan.TotalCount -gt 0) {
        $promptText = $scanText + "`n`n" + $coverageNote + "`n`nStart updating?`n`nYou will see progress windows for each manager."
        $shouldProceed = Test-UpdateProceed -PromptText $promptText -IconValue $iconQuestion
    }
    if (-not $shouldProceed) { return }

    $adminScript = Join-Path $base 'System_WingetAdmin.ps1'
    if (Test-Path $adminScript) {
        $adminResult = & $adminScript -ShowProgress
        Add-UpdateNote -Result $adminResult -Label 'Winget Admin'
    }

    $userScript = Join-Path $base 'System_WingetUser.ps1'
    if (Test-Path $userScript) {
        $userResult = & $userScript -ShowProgress
        Add-UpdateNote -Result $userResult -Label 'Winget User'
    }

    $chocoResult = Start-ChocoUpgradeSession
    Add-UpdateNote -Result $chocoResult -Label 'Chocolatey'

    $after = Get-RemainingUpgradeScan
    $remainText = ''
    if ($after.TotalCount -gt 0) {
        $remainText = Format-ComprehensiveUpgradeScan -Scan $after
        $script:updateNotes.Add('After update - ' + $after.TotalCount + ' still listed - may need reboot or manual') | Out-Null
    } else {
        $script:updateNotes.Add('Verification: all scanned packages are up to date') | Out-Null
    }

    $hideScript = Join-Path $base 'System_HideNvidiaDesktopMenu.ps1'
    if (Test-Path $hideScript) {
        $nvHide = & $hideScript -Silent
        if ($nvHide.Removed.Count -gt 0) {
            $script:updateNotes.Add('NVIDIA menu: removed duplicate desktop entries') | Out-Null
        }
        if ($nvHide.StillPresent) {
            $script:updateNotes.Add('NVIDIA menu: duplicate entries may need Install_Menu.bat (admin)') | Out-Null
        }
    }

    $script:updateNotes.Add('Spotify + Spicetify: starting final update step') | Out-Null
    try {
        $spotifySpicetify = Invoke-SpotifySpicetifyFullUpdate -Silent
    } catch {
        $spotifySpicetify = [PSCustomObject]@{
            ExitCode = 1
            Notes    = @("Spotify + Spicetify: unexpected failure - $($_.Exception.Message)")
        }
    }
    foreach ($note in $spotifySpicetify.Notes) {
        $script:updateNotes.Add($note) | Out-Null
    }
    if ($spotifySpicetify.ExitCode -ne 0) {
        $script:updateNotes.Add('Spotify + Spicetify: finished with a warning; other app updates remain completed') | Out-Null
    }

    $body = ($script:updateNotes | ForEach-Object { '  - ' + $_ }) -join "`n"
    $remainBlock = ''
    if ($after.TotalCount -gt 0) {
        $remainBlock = "`n`nStill listed after update:`n" + $remainText
    }

    $msg = "App update flow finished.`n`n" + $body + "`n`nOrder: Winget Admin -> Winget User -> Chocolatey -> verify -> NVIDIA menu cleanup -> Spotify + Spicetify." + $remainBlock

    [System.Windows.Forms.MessageBox]::Show($msg, 'System Maintenance', 'OK', 'Information') | Out-Null
}

Start-AppUpdateFlow
