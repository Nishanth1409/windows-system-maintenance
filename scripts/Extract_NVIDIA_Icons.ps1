New-Item -ItemType Directory -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'icons') -Force | Out-Null
Add-Type -AssemblyName System.Drawing

function Save-ExeIcon {
    param([string]$Exe, [string]$Out)
    if (-not (Test-Path $Exe)) {
        Write-Host "SKIP missing: $Exe"
        return $false
    }
    $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Exe)
    $fs = [System.IO.File]::Create($Out)
    $icon.Save($fs)
    $fs.Close()
    Write-Host "Saved: $Out"
    return $true
}

$iconsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'icons'

Save-ExeIcon `
    -Exe 'C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA App.exe' `
    -Out (Join-Path $iconsRoot 'nvidia_app.ico')

$cp = (Get-AppxPackage 'NVIDIACorp.NVIDIAControlPanel').InstallLocation
if ($cp) {
    Save-ExeIcon `
        -Exe (Join-Path $cp 'nvcplui.exe') `
        -Out (Join-Path $iconsRoot 'nvidia_controlpanel.ico')
}
