# Resolves (and builds on first use) the windowless launcher used by the
# scheduled-task guards. See tools\_SmRunHidden.cs for why the launcher exists.
function Resolve-HiddenLauncher {
    param(
        [string]$TargetRoot = (Split-Path $PSScriptRoot -Parent),
        [switch]$Force
    )

    $toolsDir = Join-Path $TargetRoot 'tools'
    $exePath = Join-Path $toolsDir 'SmRunHidden.exe'
    $srcPath = Join-Path $toolsDir '_SmRunHidden.cs'

    if ((Test-Path -LiteralPath $exePath) -and -not $Force) {
        # Rebuild when the source is newer, so edits to the launcher take effect.
        $exeTime = (Get-Item -LiteralPath $exePath).LastWriteTimeUtc
        $srcTime = if (Test-Path -LiteralPath $srcPath) { (Get-Item -LiteralPath $srcPath).LastWriteTimeUtc } else { [datetime]::MinValue }
        if ($exeTime -ge $srcTime) { return $exePath }
    }

    if (-not (Test-Path -LiteralPath $srcPath)) {
        throw "Missing $srcPath - cannot build the windowless launcher."
    }

    $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path -LiteralPath $csc)) {
        $csc = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
    }
    if (-not (Test-Path -LiteralPath $csc)) {
        throw 'csc.exe (.NET Framework 4 compiler) not found - cannot build the windowless launcher.'
    }

    if (-not (Test-Path -LiteralPath $toolsDir)) {
        New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    }

    # /target:winexe is the whole point: a GUI-subsystem binary never gets a console.
    $buildLog = & $csc /nologo /target:winexe /optimize+ /platform:anycpu `
        "/out:$exePath" $srcPath 2>&1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exePath)) {
        throw "Failed to build $exePath : $buildLog"
    }

    return $exePath
}
