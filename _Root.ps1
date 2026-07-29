# Shared root path — dot-source from scripts\ or tools\ subfolders
function Get-SMRoot {
    if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'GUIDE.md'))) {
        return $PSScriptRoot
    }
    if ($PSScriptRoot) {
        $parent = Split-Path $PSScriptRoot -Parent
        if (Test-Path (Join-Path $parent 'GUIDE.md')) { return $parent }
        # No fixed install path any more — the toolkit runs from wherever it sits.
        return $parent
    }
    throw 'Cannot resolve the System Maintenance root: $PSScriptRoot is empty.'
}

$script:SMRoot = Get-SMRoot
$script:SMScripts = Join-Path $SMRoot 'scripts'
$script:SMTools = Join-Path $SMRoot 'tools'
