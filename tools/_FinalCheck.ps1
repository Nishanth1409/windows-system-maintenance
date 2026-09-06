# Runs _ValidateScripts + _AuditMenu. Exit 0 only if both pass.
. (Join-Path (Split-Path $PSScriptRoot -Parent) '_Root.ps1')
$fail = 0

function Invoke-Check([string]$Name) {
    $path = Join-Path $SMTools $Name
    $proc = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $path
    ) -Wait -PassThru -WindowStyle Hidden
    if ($proc.ExitCode -ne 0) { $script:fail++ }
}

Invoke-Check '_ValidateScripts.ps1'
Invoke-Check '_AuditMenu.ps1'

if ($fail -gt 0) {
    Write-Host "=== FINAL CHECK FAILED ($fail) ===" -ForegroundColor Red
    exit 1
}
Write-Host '=== FINAL CHECK PASSED ===' -ForegroundColor Green
exit 0
