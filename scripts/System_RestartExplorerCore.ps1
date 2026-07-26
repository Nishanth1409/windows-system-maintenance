function Restart-ExplorerSafe {
    param(
        [int]$WaitSeconds = 8,
        [scriptblock]$BeforeRestart = $null
    )

    . (Join-Path $PSScriptRoot 'System_AwccOverlayGuard.ps1')

    $explorerExe = Join-Path $env:SystemRoot 'explorer.exe'

    return Invoke-WithAwccOverlaySuppressed -Action {
        Get-Process -Name explorer -ErrorAction SilentlyContinue | ForEach-Object {
            try { $_.CloseMainWindow() | Out-Null } catch { }
        }
        Start-Sleep -Seconds 2

        if ($BeforeRestart) {
            try { & $BeforeRestart } catch { }
        }

        $pingCount = [Math]::Max($WaitSeconds + 1, 6)
        $cmdLine = "taskkill /f /im explorer.exe >nul 2>&1 & ping 127.0.0.1 -n $pingCount >nul & start `"`" `"$explorerExe`""

        $cmdJob = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmdLine -WindowStyle Hidden -PassThru -ErrorAction SilentlyContinue
        if ($cmdJob) {
            $cmdJob.WaitForExit(60000) | Out-Null
            if (-not $cmdJob.HasExited) {
                try { $cmdJob.Kill() } catch { }
            }
        }

        Start-Sleep -Seconds 3

        if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds $WaitSeconds
            Start-Process -FilePath $explorerExe -ErrorAction SilentlyContinue
        }

        Start-Sleep -Seconds 1
        return $null -ne (Get-Process -Name explorer -ErrorAction SilentlyContinue)
    }
}
