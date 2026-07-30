# Fix slow File Explorer + reapply the saved view profile
# (does NOT wipe caches or shell bags)
param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
. "$PSScriptRoot\System_RestartExplorerCore.ps1"
. "$PSScriptRoot\System_ExplorerViewProfile.ps1"

$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$advancedKey = "$explorerKey\Advanced"
$applied = [System.Collections.Generic.List[string]]::new()

function Set-RegDword {
    param([string]$Path, [string]$Name, [int]$Value, [string]$Label)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    if ($Label) { $applied.Add($Label) | Out-Null }
}

# Speed tweaks — SeparateProcess OFF (saves RAM; one process is faster on laptops)
Set-RegDword $advancedKey 'LaunchTo' 1 'Open to This PC'
Set-RegDword $explorerKey 'ShowRecent' 0 'Hide recent folders'
Set-RegDword $explorerKey 'ShowFrequent' 0 'Hide frequent folders'
Set-RegDword $advancedKey 'SeparateProcess' 0 'Single Explorer process (faster, less RAM)'
Set-RegDword $advancedKey 'DisableThumbsDBOnNetworkFolders' 1 'Faster network folders'
Set-RegDword $advancedKey 'Start_TrackDocs' 0 'No recent-doc tracking'
Set-RegDword $advancedKey 'ShowCloudFilesInQuickAccess' 0 'Hide cloud in Quick Access'
Set-RegDword $advancedKey 'FolderContentsInfoTip' 0 'Less folder hover work'

# Reapply the saved view profile — never delete Shell Bags (that slows every
# folder open and loses per-folder sort/group choices).
$rewritten = Set-ExplorerViewProfile -Backup
$applied.Add('Folders: Extra large icons, Date modified (newest first), grouped by Date modified') | Out-Null
$applied.Add('This PC: Tiles, Name (A-Z), grouped by Type') | Out-Null
$applied.Add("Existing folder views refreshed: $rewritten") | Out-Null

$ok = Restart-ExplorerSafe -WaitSeconds 8

if (-not $Silent) {
    $summary = ($applied | Select-Object -Unique | ForEach-Object { "  - $_" }) -join "`n"
    $msg = if ($ok) {
        "File Explorer optimized.`n`n$summary`n`nNo caches were deleted.`n`n(Alienware overlay was suppressed during restart.)"
    } else {
        'Settings saved. Run Task Manager → File → Run new task → explorer.exe'
    }
    [System.Windows.Forms.MessageBox]::Show($msg, 'System Maintenance', 'OK', 'Information') | Out-Null
}

return $ok
