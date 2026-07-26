param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('App', 'ControlPanel')]
    [string]$Target
)

$nvidiaAppExe = 'C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA App.exe'
if (-not (Test-Path $nvidiaAppExe)) {
    $nvidiaAppExe = 'C:\Program Files\NVIDIA Corporation\NVIDIA App\CEF\NVIDIA App.exe'
}

function Start-NvidiaShellApp {
    param(
        [string]$DisplayName,
        [string]$AppId,
        [string]$FallbackExe
    )

    if ($AppId) {
        Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$AppId"
        return
    }

    $entry = Get-StartApps | Where-Object { $_.Name -eq $DisplayName } | Select-Object -First 1
    if ($entry -and $entry.AppID) {
        Start-Process explorer.exe -ArgumentList "shell:AppsFolder\$($entry.AppID)"
        return
    }

    if ($FallbackExe -and (Test-Path $FallbackExe)) {
        # CEF writes debug.log to the working directory — never launch from Desktop
        $workDir = Split-Path $FallbackExe -Parent
        Start-Process $FallbackExe -WorkingDirectory $workDir
    }
}

if ($Target -eq 'App') {
    Start-NvidiaShellApp -DisplayName 'NVIDIA App' -AppId 'com.nvidia.nvapp' -FallbackExe $nvidiaAppExe
} else {
    Start-NvidiaShellApp -DisplayName 'NVIDIA Control Panel' -AppId 'NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel' -FallbackExe $nvidiaAppExe
}
