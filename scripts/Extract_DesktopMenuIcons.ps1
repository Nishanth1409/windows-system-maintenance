# Extract high-quality multi-size .ico files for every custom desktop-menu item.
# Same technique as Extract_NVIDIA_Icons.ps1: PrivateExtractIcons (not
# ExtractAssociatedIcon) so dll resource colours stay true under Nilesoft Shell.
#
# Outputs under icons\:
#   menu_apps.ico, menu_maintenance.ico, menu_power.ico,
#   menu_restart.ico, menu_sleep.ico, menu_shutdown.ico

Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SMMenuIconExtract {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int PrivateExtractIconsW(
        string lpszFile, int nIconIndex, int cxIcon, int cyIcon,
        IntPtr[] phicon, IntPtr[] piconid, int nIcons, int flags);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
'@ -ErrorAction SilentlyContinue

$iconSizes = @(16, 20, 24, 32, 40, 48, 64, 96, 128, 256)

function Get-DllIconBitmap {
    param([string]$Dll, [int]$Index, [int]$Size)

    $handles = New-Object IntPtr[] 1
    $ids = New-Object IntPtr[] 1
    $count = [SMMenuIconExtract]::PrivateExtractIconsW($Dll, $Index, $Size, $Size, $handles, $ids, 1, 0)
    if ($count -le 0 -or $handles[0] -eq [IntPtr]::Zero) { return $null }

    try {
        $icon = [System.Drawing.Icon]::FromHandle($handles[0])
        $source = $icon.ToBitmap()
        $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.DrawImage($source, 0, 0, $Size, $Size)
        $graphics.Dispose()
        $source.Dispose()
        $icon.Dispose()
        return $bitmap
    } finally {
        [SMMenuIconExtract]::DestroyIcon($handles[0]) | Out-Null
    }
}

function Get-IconDibFrame {
    param([System.Drawing.Bitmap]$Bitmap)

    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $rect = New-Object System.Drawing.Rectangle 0, 0, $width, $height
    $locked = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pixels = New-Object byte[] ($locked.Stride * $height)
    [System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $pixels, 0, $pixels.Length)
    $stride = $locked.Stride
    $Bitmap.UnlockBits($locked)

    $stream = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter $stream

    $writer.Write([uint32]40)
    $writer.Write([int32]$width)
    $writer.Write([int32]($height * 2))
    $writer.Write([uint16]1)
    $writer.Write([uint16]32)
    $writer.Write([uint32]0)
    $writer.Write([uint32]0)
    $writer.Write([int32]0)
    $writer.Write([int32]0)
    $writer.Write([uint32]0)
    $writer.Write([uint32]0)

    for ($y = $height - 1; $y -ge 0; $y--) {
        $writer.Write($pixels, $y * $stride, $width * 4)
    }

    $maskRow = [Math]::Ceiling($width / 32.0) * 4
    $mask = New-Object byte[] ($maskRow * $height)
    $writer.Write($mask)
    $bytes = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    return , $bytes
}

function Get-IconPngFrame {
    param([System.Drawing.Bitmap]$Bitmap)
    $stream = New-Object System.IO.MemoryStream
    $Bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $stream.Dispose()
    return , $bytes
}

function Save-DllIcon {
    param(
        [string]$Dll,
        [int]$Index,
        [string]$Out
    )

    if (-not (Test-Path -LiteralPath $Dll)) {
        Write-Host "SKIP missing dll: $Dll"
        return $false
    }

    $frames = New-Object System.Collections.Generic.List[object]
    foreach ($size in $iconSizes) {
        $bitmap = Get-DllIconBitmap -Dll $Dll -Index $Index -Size $size
        if (-not $bitmap) { continue }
        $bytes = if ($size -ge 256) { Get-IconPngFrame -Bitmap $bitmap } else { Get-IconDibFrame -Bitmap $bitmap }
        $frames.Add([PSCustomObject]@{ Size = $size; Bytes = $bytes })
        $bitmap.Dispose()
    }

    if ($frames.Count -eq 0) {
        Write-Host "SKIP no icon: $Dll index $Index"
        return $false
    }

    $file = [System.IO.File]::Create($Out)
    $writer = New-Object System.IO.BinaryWriter $file
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$frames.Count)

    $offset = 6 + (16 * $frames.Count)
    foreach ($frame in $frames) {
        $dimension = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$frame.Bytes.Length)
        $writer.Write([uint32]$offset)
        $offset += $frame.Bytes.Length
    }
    foreach ($frame in $frames) {
        $writer.Write([byte[]]$frame.Bytes, 0, $frame.Bytes.Length)
    }

    $writer.Flush()
    $writer.Dispose()
    $file.Dispose()

    $sizeList = ($frames | ForEach-Object { $_.Size }) -join ', '
    Write-Host "Saved: $Out ($sizeList)"
    return $true
}

$sys32 = Join-Path $env:SystemRoot 'System32'
$imageres = Join-Path $sys32 'imageres.dll'
$shell32 = Join-Path $sys32 'shell32.dll'

$iconsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'icons'
New-Item -ItemType Directory -Path $iconsRoot -Force | Out-Null

# Indices match Add_Desktop_Menu.reg (negative = resource ID).
$jobs = @(
    @{ Name = 'menu_apps.ico';         Dll = $imageres; Index = -123 }
    @{ Name = 'menu_maintenance.ico';  Dll = $imageres; Index = -140 }
    @{ Name = 'menu_power.ico';        Dll = $imageres; Index = -109 }
    @{ Name = 'menu_restart.ico';      Dll = $shell32;  Index = 238 }
    @{ Name = 'menu_sleep.ico';        Dll = $imageres; Index = -101 }
    @{ Name = 'menu_shutdown.ico';     Dll = $shell32;  Index = 27 }
)

foreach ($job in $jobs) {
    Save-DllIcon -Dll $job.Dll -Index $job.Index -Out (Join-Path $iconsRoot $job.Name) | Out-Null
}
