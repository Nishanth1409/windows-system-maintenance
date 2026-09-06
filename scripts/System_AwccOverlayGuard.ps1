# Prevent Alienware Command Center overlay / Welcome wizard from opening when
# Explorer is restarted. AWCC listens for shell restarts when AutoRun is on.
#
# IMPORTANT (verified on AWCC with UIA A/B, Aug 2026):
#   OnBoardScreen = "True"  → Welcome wizard is NOT shown (completed)
#   OnBoardScreen = "False" → Welcome wizard IS shown
# The property name reads like a "show this screen" flag, but AWCC treats True as
# completed. An earlier revision of this guard wrote False and caused Welcome to
# appear on every open.

function Close-AwccOverlayWindows {
    Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -like 'AWCCOverlay*' -or
        $_.MainWindowTitle -match 'Alienware.*Overlay|Overlay.*performance|Command Center Overlay'
    } | ForEach-Object {
        try {
            if ($_.MainWindowHandle -ne [IntPtr]::Zero) {
                $_.CloseMainWindow() | Out-Null
            }
        } catch { }
    }

    Start-Sleep -Milliseconds 400

    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like 'AWCCOverlay*' } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Write-AwccJsonNoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Object,
        [int]$Depth = 6
    )

    $json = $Object | ConvertTo-Json -Depth $Depth
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, ($json + "`r`n"), $utf8)
}

function Set-AwccOnboardingComplete {
    # Main Welcome wizard (dark "Welcome!" card). True = completed on this build.
    $userPath = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center\Common\UserSetting.json'
    if (Test-Path -LiteralPath $userPath) {
        try {
            $user = Get-Content -LiteralPath $userPath -Raw | ConvertFrom-Json
            $needWrite = $false
            if ($user.OnBoardScreen -ne 'True') {
                $user.OnBoardScreen = 'True'
                $needWrite = $true
            }
            if ($user.PSObject.Properties.Name -contains 'ShowPrivacyScreen' -and $user.ShowPrivacyScreen -ne 'False') {
                $user.ShowPrivacyScreen = 'False'
                $needWrite = $true
            }
            if ($needWrite) {
                Write-AwccJsonNoBom -Path $userPath -Object ([pscustomobject]@{
                    UserConsent       = [string]($(if ($user.UserConsent) { $user.UserConsent } else { 'True' }))
                    ShowPrivacyScreen = 'False'
                    OnBoardScreen     = 'True'
                })
            }
        } catch { }
    }

    # Per-area tours left at ReadyToLaunch keep re-prompting tooltips after launch.
    $onboardDir = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center\Onboarding'
    if (Test-Path -LiteralPath $onboardDir) {
        Get-ChildItem -LiteralPath $onboardDir -Filter 'OnboardingStatus_*.json' -File -ErrorAction SilentlyContinue |
            ForEach-Object {
                try {
                    $o = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
                    $changed = $false
                    foreach ($area in @($o.UIAreaData)) {
                        if ($area.OnboardingFlowState -eq 'ReadyToLaunch') {
                            $area.OnboardingFlowState = 'Completed'
                            $changed = $true
                        }
                    }
                    if ($changed) {
                        Write-AwccJsonNoBom -Path $_.FullName -Object $o
                    }
                } catch { }
            }
    }
}

function Invoke-WithAwccOverlaySuppressed {
    param([scriptblock]$Action)

    # Non-Alienware PCs (ASUS TUF, etc.): no AWCC folder — run Action as-is.
    $awccRoot = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center'
    if (-not (Test-Path -LiteralPath $awccRoot)) {
        if ($Action) { return & $Action }
        return
    }

    $orchPath = Join-Path $awccRoot 'Core\OrchestratorSettings.json'
    $orchBackup = $null
    $hadAutoRun = $false

    Set-AwccOnboardingComplete
    Close-AwccOverlayWindows

    if (Test-Path -LiteralPath $orchPath) {
        try {
            $orch = Get-Content -LiteralPath $orchPath -Raw | ConvertFrom-Json
            if ($orch.AutoRun) {
                $hadAutoRun = $true
                $orchBackup = Get-Content -LiteralPath $orchPath -Raw
                $orch.AutoRun = $false
                Write-AwccJsonNoBom -Path $orchPath -Object $orch -Depth 4
            }
        } catch { }
    }

    try {
        if ($Action) { return & $Action }
    }
    finally {
        Close-AwccOverlayWindows
        Start-Sleep -Milliseconds 500
        Close-AwccOverlayWindows

        if ($hadAutoRun -and $orchBackup) {
            try {
                $utf8 = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($orchPath, $orchBackup, $utf8)
            } catch { }
        }

        # Re-assert completed flag; AWCC can rewrite UserSetting while its UI is up.
        Set-AwccOnboardingComplete
    }
}
