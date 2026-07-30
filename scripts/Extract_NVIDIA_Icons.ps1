# Build icons\nvidia_app.ico and icons\nvidia_controlpanel.ico from the installed
# NVIDIA executables.
#
# ExtractAssociatedIcon only ever returns the 32x32 16-colour frame, which turned
# NVIDIA green (#76B900) into the VGA palette's olive and dropped the logo to a
# muddy smear in the menu. PrivateExtractIcons asks for a specific size instead,
# so the real 32-bit frames come through and every shell size is stored.

Add-Type -AssemblyName System.Drawing

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class SMIconExtract {
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int PrivateExtractIconsW(
        string lpszFile, int nIconIndex, int cxIcon, int cyIcon,
        IntPtr[] phicon, IntPtr[] piconid, int nIcons, int flags);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
'@ -ErrorAction SilentlyContinue

$iconSizes = @(16, 20, 24, 32, 40, 48, 64, 96, 128, 256)

function Get-ExeIconBitmap {
    param([string]$Exe, [int]$Size)

    $handles = New-Object IntPtr[] 1
    $ids = New-Object IntPtr[] 1
    $count = [SMIconExtract]::PrivateExtractIconsW($Exe, 0, $Size, $Size, $handles, $ids, 1, 0)
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
        [SMIconExtract]::DestroyIcon($handles[0]) | Out-Null
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

    # BITMAPINFOHEADER — height is doubled to cover the XOR image plus AND mask.
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

    # Alpha carries transparency, so the AND mask stays empty (padded to 4 bytes).
    $maskBytes = [int][math]::Ceiling($width / 8.0)
    $maskStride = $maskBytes + ((4 - ($maskBytes % 4)) % 4)
    $maskRow = New-Object byte[] $maskStride
    for ($y = 0; $y -lt $height; $y++) {
        $writer.Write($maskRow, 0, $maskRow.Length)
    }

    $writer.Flush()
    $bytes = $stream.ToArray()
    $writer.Dispose()
    $stream.Dispose()
    # Comma keeps the array intact; a bare return unrolls it into Object[] and the
    # BinaryWriter then picks its single-byte overload.
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

function Save-ExeIcon {
    param([string]$Exe, [string]$Out)

    if (-not (Test-Path -LiteralPath $Exe)) {
        Write-Host "SKIP missing: $Exe"
        return $false
    }

    $frames = New-Object System.Collections.Generic.List[object]
    foreach ($size in $iconSizes) {
        $bitmap = Get-ExeIconBitmap -Exe $Exe -Size $size
        if (-not $bitmap) { continue }
        # 256 is stored PNG-compressed, the sizes below it as DIB, matching what
        # Windows itself ships in shell32/imageres.
        $bytes = if ($size -ge 256) { Get-IconPngFrame -Bitmap $bitmap } else { Get-IconDibFrame -Bitmap $bitmap }
        $frames.Add([PSCustomObject]@{ Size = $size; Bytes = $bytes })
        $bitmap.Dispose()
    }

    if ($frames.Count -eq 0) {
        Write-Host "SKIP no icon found: $Exe"
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

$iconsRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'icons'
New-Item -ItemType Directory -Path $iconsRoot -Force | Out-Null

Save-ExeIcon `
    -Exe 'C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA App.exe' `
    -Out (Join-Path $iconsRoot 'nvidia_app.ico') | Out-Null

$cp = (Get-AppxPackage 'NVIDIACorp.NVIDIAControlPanel').InstallLocation
if ($cp) {
    Save-ExeIcon `
        -Exe (Join-Path $cp 'nvcplui.exe') `
        -Out (Join-Path $iconsRoot 'nvidia_controlpanel.ico') | Out-Null
}
