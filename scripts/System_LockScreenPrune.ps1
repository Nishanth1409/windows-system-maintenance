# Prune stale wallpaper backup copies so only the currently-applied image is kept.
#
# The "Lock Screen Wallpaper" Windhawk mod stages a fresh timestamped copy
# (lockscreen_YYYYMMDD_HHMMSS.jpg) into C:\ProgramData\WindhawkLockScreen on every
# boot, unlock, and sign-in. Those copies are byte-identical to the active
# lockscreen.jpg and are only needed for the moment the mod hands the file to the
# Windows lock-screen API, so they pile up (they had grown to 285 files / 1.55 GB).
#
# This keeps the active image plus the single newest timestamped copy (a safety
# buffer in case the mod is mid-apply) and deletes the rest. It also trims Windows'
# own desktop-wallpaper cache copies the same way. It never touches your original
# picture files - only disposable cached duplicates.
param(
    [int]$KeepNewest = 1,
    [switch]$Silent
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Log {
    param([string]$Message, [string]$Color = 'Gray')
    if (-not $Silent) { Write-Host $Message -ForegroundColor $Color }
}

function Invoke-PruneSet {
    param(
        [string]$Directory,
        [string]$Filter,
        [int]$Keep,
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Directory)) { return [pscustomobject]@{ Deleted = 0; FreedBytes = 0 } }

    $items = Get-ChildItem -LiteralPath $Directory -Filter $Filter -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if (-not $items) { return [pscustomobject]@{ Deleted = 0; FreedBytes = 0 } }

    $toDelete = $items | Select-Object -Skip $Keep
    $freed = ($toDelete | Measure-Object Length -Sum).Sum
    $count = 0
    foreach ($f in $toDelete) {
        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path -LiteralPath $f.FullName)) { $count++ }
    }

    if ($count -gt 0) {
        Write-Log ("  {0}: removed {1} old copies, freed {2:N2} MB" -f $Label, $count, ($freed / 1MB)) 'Green'
    } else {
        Write-Log "  ${Label}: nothing to prune" 'DarkGray'
    }
    return [pscustomobject]@{ Deleted = $count; FreedBytes = $freed }
}

Write-Log '=== Wallpaper backup prune ===' 'Cyan'

$totalDeleted = 0
$totalFreed = 0

# 1) Lock screen staged copies (Windhawk mod).
$lockDir = Join-Path $env:ProgramData 'WindhawkLockScreen'
$r = Invoke-PruneSet -Directory $lockDir -Filter 'lockscreen_*.*' -Keep $KeepNewest -Label 'Lock screen backups'
$totalDeleted += $r.Deleted; $totalFreed += $r.FreedBytes

# 2) Desktop wallpaper cache copies that Windows keeps as it changes wallpapers.
$themeCache = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Themes\CachedFiles'
$r = Invoke-PruneSet -Directory $themeCache -Filter 'CachedImage_*.jpg' -Keep $KeepNewest -Label 'Desktop wallpaper cache'
$totalDeleted += $r.Deleted; $totalFreed += $r.FreedBytes

Write-Log ("Done. Removed {0} disposable copies, freed {1:N2} MB." -f $totalDeleted, ($totalFreed / 1MB)) 'Green'
