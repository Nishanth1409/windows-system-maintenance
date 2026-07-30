# Single source of truth for the File Explorer view / sort / group profile.
#
# Cleanup scripts dot-source this file and call Restore-ExplorerViewProfile so
# that clearing caches or temp data can never change how folders look or sort.
#
#   Normal folders : Extra large icons, sort Date modified (desc), group Date modified
#   This PC        : Tiles, sort Name (asc), group Type

$script:ExplorerBagsRoot = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags'
$script:ExplorerAdvancedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$script:ExplorerDetailsKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Modules\GlobalSettings\DetailsContainer'

# Filesystem folder templates only. Virtual namespaces (Recycle Bin, Control
# Panel, Network) are deliberately left alone.
$script:ExplorerFolderTypes = @(
    '{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}', # Generic
    '{7D49D726-3C21-4F05-99AA-FDC2C9474656}', # Documents
    '{B3690E58-E961-423B-B687-386EBFD83239}', # Pictures
    '{94D6DDCC-4A68-4175-A374-BD584A510B78}', # Music
    '{5FA96407-7E77-483C-AC93-691D05850DE8}', # Videos
    '{885A186E-A440-4ADA-812B-DB871B942259}'  # Downloads
)

$script:ThisPcKeys = @(
    (Join-Path $script:ExplorerBagsRoot '1\Shell\{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}'),
    (Join-Path $script:ExplorerBagsRoot '1\ComDlg\{5C4F28B5-F869-4E84-8E60-F11DB97C5CC7}')
)

# Sort column blobs: FMTID {B725F130-47EF-101A-A5F1-02608C9EEBAC},
# PID 14 = Date modified, PID 10 = Name. Last dword is the direction.
$script:SortDateModifiedDesc = [byte[]](
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x30, 0xF1, 0x25, 0xB7,
    0xEF, 0x47, 0x1A, 0x10, 0xA5, 0xF1, 0x02, 0x60,
    0x8C, 0x9E, 0xEB, 0xAC, 0x0E, 0x00, 0x00, 0x00,
    0xFF, 0xFF, 0xFF, 0xFF
)
$script:SortNameAsc = [byte[]](
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x30, 0xF1, 0x25, 0xB7,
    0xEF, 0x47, 0x1A, 0x10, 0xA5, 0xF1, 0x02, 0x60,
    0x8C, 0x9E, 0xEB, 0xAC, 0x0A, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00
)

$script:NormalFolderView = [ordered]@{
    'Mode'              = 1
    'LogicalViewMode'   = 3
    'IconSize'          = 256
    'Vid'               = '{137E7700-3573-11CF-AE69-08002B2E1262}'
    'Rev'               = 0
    'FFlags'            = 1226833937
    'GroupView'         = [uint32]::MaxValue
    'GroupByKey:FMTID'  = '{B725F130-47EF-101A-A5F1-02608C9EEBAC}'
    'GroupByKey:PID'    = 14
    'GroupByDirection'  = [uint32]::MaxValue
    'Sort'              = $script:SortDateModifiedDesc
}

$script:ThisPcSharedView = [ordered]@{
    'Mode'              = 6
    'LogicalViewMode'   = 2
    'IconSize'          = 48
    'GroupView'         = [uint32]::MaxValue
    'GroupByKey:FMTID'  = '{B725F130-47EF-101A-A5F1-02608C9EEBAC}'
    'GroupByKey:PID'    = 4
    'GroupByDirection'  = 1
    'Sort'              = $script:SortNameAsc
}

$script:ThisPcShellOnlyView = [ordered]@{
    'Vid'    = '{65F125E5-7BE1-4810-BA9D-D271C8432CE3}'
    'Rev'    = 0
    'FFlags' = 1226833921
}

$script:ThisPcComDlgOnlyView = [ordered]@{
    'FFlags' = 1
}

# Show options that belong to the same "how Explorer looks" promise.
$script:ExplorerAdvancedView = [ordered]@{
    'Hidden'          = 1   # show hidden items
    'HideFileExt'     = 0   # show file extensions
    'AutoCheckSelect' = 1   # item check boxes
    'UseCompactMode'  = 1   # compact view
}

# Details pane visible.
$script:ExplorerDetailsContainer = [byte[]](0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00)

function ConvertTo-ExplorerDword {
    param($Value)
    if ($null -eq $Value) { return $null }
    return [uint32]([int64]$Value -band 0xFFFFFFFFL)
}

function Set-ExplorerViewValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    if ($Value -is [byte[]]) {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType Binary -Value $Value -Force | Out-Null
    } elseif ($Value -is [string]) {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType String -Value $Value -Force | Out-Null
    } else {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType DWord `
            -Value (ConvertTo-ExplorerDword $Value) -Force | Out-Null
    }
}

function Write-ExplorerViewValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )

    foreach ($name in $Values.Keys) {
        Set-ExplorerViewValue -Path $Path -Name $name -Value $Values[$name]
    }
}

function Test-ExplorerViewValues {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Values
    )

    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $actual = Get-ItemProperty -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $actual) { return $false }

    foreach ($name in $Values.Keys) {
        $property = $actual.PSObject.Properties[$name]
        if (-not $property) { return $false }

        $expected = $Values[$name]
        if ($expected -is [byte[]]) {
            $current = $property.Value -as [byte[]]
            if (-not $current -or $current.Length -ne $expected.Length) { return $false }
            for ($i = 0; $i -lt $expected.Length; $i++) {
                if ($current[$i] -ne $expected[$i]) { return $false }
            }
        } elseif ($expected -is [string]) {
            if ([string]$property.Value -ne $expected) { return $false }
        } else {
            if ((ConvertTo-ExplorerDword $property.Value) -ne (ConvertTo-ExplorerDword $expected)) { return $false }
        }
    }
    return $true
}

function Export-ExplorerViewBackup {
    param([string]$Destination)

    if (-not $Destination) {
        $logs = Join-Path (Split-Path $PSScriptRoot -Parent) 'logs'
        $Destination = Join-Path $logs ('explorer-view-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    & reg.exe export 'HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell' `
        (Join-Path $Destination 'ShellBags.reg') /y 2>$null | Out-Null
    & reg.exe export 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
        (Join-Path $Destination 'ExplorerAdvanced.reg') /y 2>$null | Out-Null
    return $Destination
}

function Test-ExplorerViewProfile {
    # Cheap drift check on the keys that define the profile. Per-folder bags are
    # only rewritten when one of these has actually changed.
    $allFolders = Join-Path $script:ExplorerBagsRoot 'AllFolders\Shell'
    if (-not (Test-ExplorerViewValues -Path $allFolders -Values $script:NormalFolderView)) { return $false }

    foreach ($key in $script:ThisPcKeys) {
        if (-not (Test-ExplorerViewValues -Path $key -Values $script:ThisPcSharedView)) { return $false }
    }
    if (-not (Test-ExplorerViewValues -Path $script:ThisPcKeys[0] -Values $script:ThisPcShellOnlyView)) { return $false }
    if (-not (Test-ExplorerViewValues -Path $script:ThisPcKeys[1] -Values $script:ThisPcComDlgOnlyView)) { return $false }

    if (-not (Test-ExplorerViewValues -Path $script:ExplorerAdvancedKey -Values $script:ExplorerAdvancedView)) { return $false }
    if (-not (Test-ExplorerViewValues -Path $script:ExplorerDetailsKey -Values @{ DetailsContainer = $script:ExplorerDetailsContainer })) { return $false }

    return $true
}

function Set-ExplorerViewProfile {
    param(
        [switch]$SkipExistingBags,
        [switch]$Backup
    )

    if ($Backup) { Export-ExplorerViewBackup | Out-Null }

    # Defaults inherited by folders that do not have a saved view yet.
    $allFolders = Join-Path $script:ExplorerBagsRoot 'AllFolders\Shell'
    Write-ExplorerViewValues -Path $allFolders -Values $script:NormalFolderView
    Set-ExplorerViewValue -Path $allFolders -Name 'FolderType' -Value 'NotSpecified'

    foreach ($container in @('Shell', 'ComDlg', 'ComDlgLegacy')) {
        foreach ($folderType in $script:ExplorerFolderTypes) {
            Write-ExplorerViewValues -Path (Join-Path $script:ExplorerBagsRoot "AllFolders\$container\$folderType") `
                -Values $script:NormalFolderView
        }
    }

    # Folders the user already opened keep their own saved bag, so those are
    # rewritten too. Bag 1 is This PC and must never get the folder profile.
    $updated = 0
    if (-not $SkipExistingBags) {
        Get-ChildItem $script:ExplorerBagsRoot -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -match '\\Bags\\1\\') { return }
            if ($script:ExplorerFolderTypes -contains $_.PSChildName) {
                Write-ExplorerViewValues -Path $_.PSPath -Values $script:NormalFolderView
                $updated++
            }
        }
    }

    foreach ($key in $script:ThisPcKeys) {
        Write-ExplorerViewValues -Path $key -Values $script:ThisPcSharedView
    }
    Write-ExplorerViewValues -Path $script:ThisPcKeys[0] -Values $script:ThisPcShellOnlyView
    Write-ExplorerViewValues -Path $script:ThisPcKeys[1] -Values $script:ThisPcComDlgOnlyView

    Write-ExplorerViewValues -Path $script:ExplorerAdvancedKey -Values $script:ExplorerAdvancedView
    Set-ExplorerViewValue -Path $script:ExplorerDetailsKey -Name 'DetailsContainer' `
        -Value $script:ExplorerDetailsContainer

    return $updated
}

function Restore-ExplorerViewProfile {
    # Guard used by cleanup scripts: rewrites the profile only if something
    # drifted, and never restarts Explorer on its own.
    param([switch]$PassThru)

    if (Test-ExplorerViewProfile) {
        if ($PassThru) { return $false }
        return
    }

    Set-ExplorerViewProfile -SkipExistingBags | Out-Null
    if ($PassThru) { return $true }
}
