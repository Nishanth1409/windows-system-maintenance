# Full health check — scripts, files, registry menu, winget, smoke tests
. (Join-Path (Split-Path $PSScriptRoot -Parent) '_Root.ps1')
$toolsDir = $SMTools
$fail = 0

function Invoke-CheckScript {
    param([string]$ScriptPath)
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath
    ) -Wait -PassThru -WindowStyle Hidden
    return $proc.ExitCode
}

if ((Invoke-CheckScript (Join-Path $toolsDir '_ValidateScripts.ps1')) -ne 0) { $fail++ }
if ((Invoke-CheckScript (Join-Path $toolsDir '_AuditMenu.ps1')) -ne 0) { $fail++ }

if ($fail -gt 0) {
    Write-Host "=== FINAL CHECK FAILED ($fail) ===" -ForegroundColor Red
    exit 1
}

Write-Host '=== FINAL CHECK PASSED — System Maintenance is ready ===' -ForegroundColor Green
exit 0
