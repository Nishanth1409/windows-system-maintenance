# Nilesoft Shell draws the desktop context menu itself and replaces the icon of
# some items with its own built-in glyphs, which ignores the Icon values this
# toolkit writes to the registry. This installs shell\SystemMaintenance.nss into
# the Shell config, with the icon paths rewritten for wherever this toolkit
# lives, so the extracted icons survive.
#
# Does nothing when Nilesoft Shell is absent: plain Explorer already honours the
# registry icons.
param(
    [string]$Root,
    [switch]$RestartExplorer,
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'

if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
$Root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')

function Write-Step {
    param([string]$Message)
    if (-not $Silent) { Write-Host $Message }
}

function Restart-ExplorerIfRequested {
    if (-not $RestartExplorer) { return }
    . (Join-Path $PSScriptRoot 'System_RestartExplorerCore.ps1')
    Restart-ExplorerSafe -WaitSeconds 4 | Out-Null
}

function Get-NilesoftShellRoot {
    $uninstallHives = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($hive in $uninstallHives) {
        if (-not (Test-Path -LiteralPath $hive)) { continue }
        foreach ($key in (Get-ChildItem -LiteralPath $hive -ErrorAction SilentlyContinue)) {
            $props = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (-not $props -or $props.DisplayName -notlike '*Nilesoft Shell*') { continue }
            $location = $props.InstallLocation
            if ($location -and (Test-Path -LiteralPath (Join-Path $location 'shell.nss'))) {
                return (Resolve-Path -LiteralPath $location).Path.TrimEnd('\')
            }
        }
    }

    foreach ($candidate in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $candidate) { continue }
        $guess = Join-Path $candidate 'Nilesoft Shell'
        if (Test-Path -LiteralPath (Join-Path $guess 'shell.nss')) {
            return (Resolve-Path -LiteralPath $guess).Path.TrimEnd('\')
        }
    }

    return $null
}

$source = Join-Path $Root 'shell\SystemMaintenance.nss'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Missing Shell config source: $source"
}

$shellRoot = Get-NilesoftShellRoot
if (-not $shellRoot) {
    Write-Step 'Nilesoft Shell not installed - the registry icons are used as-is.'
    Restart-ExplorerIfRequested
    return
}

$identity = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $identity.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator rights are required to write to $shellRoot."
}

# Same placeholder convention as Add_Desktop_Menu.reg, so the checked-in file
# stays valid on a machine that really does install to C:\SystemMaintenance.
$placeholder = 'C:\SystemMaintenance'
$text = [System.IO.File]::ReadAllText($source).Replace($placeholder, $Root)
if ($Root -ne $placeholder -and $text.Contains($placeholder)) {
    throw "Some paths still point at $placeholder after rewrite."
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$changed = $false

$importsDir = Join-Path $shellRoot 'imports'
if (-not (Test-Path -LiteralPath $importsDir)) {
    New-Item -ItemType Directory -Path $importsDir -Force | Out-Null
}

$target = Join-Path $importsDir 'systemmaintenance.nss'
if (-not (Test-Path -LiteralPath $target) -or [System.IO.File]::ReadAllText($target) -ne $text) {
    [System.IO.File]::WriteAllText($target, $text, $utf8NoBom)
    $changed = $true
    Write-Step "Wrote icon overrides to $target"
}

# A Shell update rewrites shell.nss and drops third-party lines, so re-running
# this script is how the import comes back.
$configPath = Join-Path $shellRoot 'shell.nss'
$relativeImport = 'imports/systemmaintenance.nss'
$config = [System.IO.File]::ReadAllText($configPath)

if (-not $config.Contains($relativeImport)) {
    $backup = "$configPath.sm-backup"
    if (-not (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $configPath -Destination $backup
        Write-Step "Backed up the original config to $backup"
    }

    $importLine = "import '$relativeImport'"
    $anchor = "import 'imports/modify.nss'"
    if ($config.Contains($anchor)) {
        # Ours has to load with the other modify-items, before the new-items below.
        $config = $config.Replace($anchor, "$importLine`r`n$anchor")
    }
    else {
        $config = $config.TrimEnd() + "`r`n`r`n$importLine`r`n"
    }

    [System.IO.File]::WriteAllText($configPath, $config, $utf8NoBom)
    $changed = $true
    Write-Step "Added the import to $configPath"
}

if (-not $changed) {
    Write-Step 'Nilesoft Shell icon overrides already up to date.'
}

Restart-ExplorerIfRequested
