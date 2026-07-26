# Fix slow File Explorer + Extra large icons (does NOT wipe caches or shell bags)
param([switch]$Silent)

Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
. "$PSScriptRoot\System_RestartExplorerCore.ps1"

$explorerKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
$advancedKey = "$explorerKey\Advanced"
$applied = [System.Collections.Generic.List[string]]::new()

function Set-RegDword {
    param([string]$Path, [string]$Name, [int]$Value, [string]$Label)
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force
    if ($Label) { $applied.Add($Label) | Out-Null }
}

function Set-ExtraLargeIconsAllFolders {
    $shell = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'
    New-Item -Path $shell -Force | Out-Null
    Set-ItemProperty -Path $shell -Name 'Mode' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $shell -Name 'LogicalViewMode' -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $shell -Name 'IconSize' -Value 256 -Type DWord -Force
    Set-ItemProperty -Path $shell -Name 'Rev' -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $shell -Name 'FFlags' -Value 1098814045 -Type DWord -Force
    Set-ItemProperty -Path $shell -Name 'Vid' -Value '{137E7700-3573-101A-9153-08002B903E09}' -Type String -Force
    $applied.Add('Default view: Extra large icons') | Out-Null
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

# Set icon default only — do NOT delete Shell Bags (that slows every folder open)
Set-ExtraLargeIconsAllFolders

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
