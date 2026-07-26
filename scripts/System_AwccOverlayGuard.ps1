# Prevent Alienware Command Center overlay from opening during Explorer restart.
# AWCC uses AutoRun + OnBoardScreen; killing explorer triggers overlay/onboarding popups.

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

function Set-AwccOnboardingComplete {
    $userPath = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center\Common\UserSetting.json'
    if (-not (Test-Path $userPath)) { return }

    try {
        $user = Get-Content $userPath -Raw | ConvertFrom-Json
        if ($user.OnBoardScreen -eq 'True') {
            $user.OnBoardScreen = 'False'
            $user | ConvertTo-Json | Set-Content $userPath -Encoding UTF8
        }
    } catch { }
}

function Invoke-WithAwccOverlaySuppressed {
    param([scriptblock]$Action)

    $orchPath = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center\Core\OrchestratorSettings.json'
    $orchBackup = $null
    $hadAutoRun = $false

    Set-AwccOnboardingComplete
    Close-AwccOverlayWindows

    if (Test-Path $orchPath) {
        try {
            $orch = Get-Content $orchPath -Raw | ConvertFrom-Json
            if ($orch.AutoRun) {
                $hadAutoRun = $true
                $orchBackup = Get-Content $orchPath -Raw
                $orch.AutoRun = $false
                ($orch | ConvertTo-Json -Compress) | Set-Content $orchPath -Encoding UTF8 -NoNewline
            }
        } catch { }
    }

    try {
        if ($Action) { return & $Action }
    } finally {
        Close-AwccOverlayWindows
        Start-Sleep -Milliseconds 500
        Close-AwccOverlayWindows

        if ($hadAutoRun -and $orchBackup) {
            try {
                Set-Content $orchPath $orchBackup -Encoding UTF8 -NoNewline
            } catch { }
        }
    }
}
