param(
    [Parameter(Mandatory = $true)]
    [string]$ImagePath,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

function Show-LockScreenMessage {
    param(
        [string]$Message,
        [System.Windows.Forms.MessageBoxIcon]$Icon = 'Information'
    )

    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        'Set as lock screen',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    ) | Out-Null
}

function Wait-WindowsRuntimeOperation {
    param(
        [Parameter(Mandatory = $true)]$Operation,
        [Parameter(Mandatory = $true)][Type]$ResultType
    )

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq 'AsTask' -and
            $_.IsGenericMethod -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
        } |
        Select-Object -First 1

    if (-not $method) { throw 'Windows Runtime task converter was not found.' }
    $task = $method.MakeGenericMethod($ResultType).Invoke($null, @($Operation))
    $task.GetAwaiter().GetResult()
}

function Wait-WindowsRuntimeAction {
    param([Parameter(Mandatory = $true)]$Action)

    $method = [System.WindowsRuntimeSystemExtensions].GetMethods() |
        Where-Object {
            $_.Name -eq 'AsTask' -and
            -not $_.IsGenericMethod -and
            $_.GetParameters().Count -eq 1 -and
            $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
        } |
        Select-Object -First 1

    if (-not $method) { throw 'Windows Runtime action converter was not found.' }
    $task = $method.Invoke($null, @($Action))
    $task.GetAwaiter().GetResult()
}

try {
    $resolved = (Resolve-Path -LiteralPath $ImagePath).Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw 'The selected image file does not exist.'
    }

    $allowedExtensions = @(
        '.avci', '.avcs', '.avif', '.avifs', '.bmp', '.dib', '.gif',
        '.heic', '.heics', '.heif', '.heifs', '.hif', '.jfif', '.jpe',
        '.jpeg', '.jpg', '.png', '.tif', '.tiff', '.wdp'
    )
    $extension = [IO.Path]::GetExtension($resolved).ToLowerInvariant()
    if ($extension -notin $allowedExtensions) {
        throw "Unsupported image type: $extension"
    }

    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime] | Out-Null

    $storageFile = Wait-WindowsRuntimeOperation `
        -Operation ([Windows.Storage.StorageFile]::GetFileFromPathAsync($resolved)) `
        -ResultType ([Windows.Storage.StorageFile])

    if ($ValidateOnly) {
        Write-Output "OK: $($storageFile.Path)"
        exit 0
    }

    Wait-WindowsRuntimeAction `
        -Action ([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($storageFile))

    # Success is silent; only failures are worth interrupting the user for.
    exit 0
} catch {
    if ($ValidateOnly) {
        Write-Error $_.Exception.Message
    } else {
        Show-LockScreenMessage `
            -Message "Windows could not set this image as the lock screen.`n`n$($_.Exception.Message)" `
            -Icon 'Warning'
    }
    exit 1
}
