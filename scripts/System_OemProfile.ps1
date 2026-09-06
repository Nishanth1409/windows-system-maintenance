# Detect PC brand / capabilities so System Maintenance only runs what applies.
# Dot-source to load Get-SmOemProfile; run with -File -Print for console output.
param(
    [switch]$Print,
    [switch]$AsJson
)

function Get-SmOemProfile {
    $cs = $null
    $base = $null
    try { $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { }
    try { $base = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop } catch { }

    $manufacturer = [string]($(if ($cs -and $cs.Manufacturer) { $cs.Manufacturer } else { 'Unknown' })).Trim()
    $model = [string]($(if ($cs -and $cs.Model) { $cs.Model } else { 'Unknown' })).Trim()
    $board = [string]($(if ($base -and $base.Product) { $base.Product } else { '' })).Trim()

    $family = 'Generic'
    $blob = "$manufacturer $model $board"
    if ($blob -match 'Alienware') {
        $family = 'Alienware'
    } elseif ($manufacturer -match 'Dell') {
        $family = 'Dell'
    } elseif ($manufacturer -match 'ASUS|AsusTek' -or $blob -match '\bTUF\b|\bROG\b|\bVivobook\b|\bZenbook\b') {
        $family = 'ASUS'
    } elseif ($manufacturer -match 'Lenovo') {
        $family = 'Lenovo'
    } elseif ($manufacturer -match 'HP|Hewlett') {
        $family = 'HP'
    } elseif ($manufacturer -match 'Microsoft') {
        $family = 'Microsoft'
    } elseif ($manufacturer -match 'Acer') {
        $family = 'Acer'
    } elseif ($manufacturer -match 'MSI') {
        $family = 'MSI'
    }

    $awccPath = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center'
    $hasAwcc = (Test-Path -LiteralPath $awccPath) -or
        $null -ne (Get-Process -Name 'AWCC*','Alienware*' -ErrorAction SilentlyContinue | Select-Object -First 1)

    $hasNvidia = $false
    try {
        $gpus = Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue
        if ($gpus | Where-Object { $_.Name -match 'NVIDIA' }) { $hasNvidia = $true }
    } catch { }
    if (-not $hasNvidia -and (Test-Path 'C:\Program Files\NVIDIA Corporation')) { $hasNvidia = $true }
    if (-not $hasNvidia -and (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { $hasNvidia = $true }

    $hasMyAsus = $null -ne (Get-AppxPackage -Name '*ASUS*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'MyASUS|Armoury|ASUS' } | Select-Object -First 1)
    if (-not $hasMyAsus) {
        $hasMyAsus = (Test-Path 'C:\Program Files (x86)\ASUS') -or (Test-Path 'C:\Program Files\ASUS')
    }

    [pscustomobject]@{
        Manufacturer     = $manufacturer
        Model            = $model
        Board            = $board
        Family           = $family
        IsAlienware      = ($family -eq 'Alienware')
        IsAsus           = ($family -eq 'ASUS')
        HasAwcc          = [bool]$hasAwcc
        HasNvidia        = [bool]$hasNvidia
        HasMyAsus        = [bool]$hasMyAsus
        ApplyAwccGuards  = [bool]($family -eq 'Alienware' -or $hasAwcc)
        ApplyNvidiaMenu  = [bool]$hasNvidia
    }
}

$isDotSourced = ($MyInvocation.InvocationName -eq '.') -or
    ($MyInvocation.Line -match '^\s*\.\s+')

if ($isDotSourced) {
    return
}

$profile = Get-SmOemProfile

if ($AsJson) {
    $profile | ConvertTo-Json -Compress
    return
}

if ($Print) {
    Write-Host ("  PC       : {0} {1}" -f $profile.Manufacturer, $profile.Model)
    Write-Host ("  Profile  : {0}" -f $profile.Family)
    Write-Host ("  NVIDIA   : {0}" -f ($(if ($profile.HasNvidia) { 'yes - duplicate desktop menu will be hidden' } else { 'no' })))
    Write-Host ("  AWCC     : {0}" -f ($(if ($profile.ApplyAwccGuards) { 'yes - Alienware overlay guards active' } else { 'skip - not Alienware' })))
    if ($profile.IsAsus) {
        Write-Host '  ASUS     : detected - MyASUS/Armoury left alone; no Alienware steps'
    }
}
