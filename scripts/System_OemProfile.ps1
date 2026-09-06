# Detect PC brand / capabilities so System Maintenance only runs what applies.
# Works on any Windows laptop/desktop: Alienware, Dell, ASUS, Lenovo, HP, MSI,
# Acer, Microsoft Surface, Samsung, Gigabyte, Razer, Framework, generic OEM, etc.
# Dot-source to load Get-SmOemProfile; run with -File -Print for console output.
param(
    [switch]$Print,
    [switch]$AsJson
)

function Test-SmPathOrApp {
    param([string[]]$Paths, [string[]]$AppxPatterns)

    foreach ($p in $Paths) {
        if ($p -and (Test-Path -LiteralPath $p)) { return $true }
    }
    foreach ($pat in $AppxPatterns) {
        if ($null -ne (Get-AppxPackage -Name $pat -ErrorAction SilentlyContinue | Select-Object -First 1)) {
            return $true
        }
    }
    return $false
}

function Get-SmOemProfile {
    $cs = $null
    $base = $null
    $bios = $null
    try { $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { }
    try { $base = Get-CimInstance -ClassName Win32_BaseBoard -ErrorAction Stop } catch { }
    try { $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop } catch { }

    $manufacturer = [string]($(if ($cs -and $cs.Manufacturer) { $cs.Manufacturer } else { 'Unknown' })).Trim()
    $model = [string]($(if ($cs -and $cs.Model) { $cs.Model } else { 'Unknown' })).Trim()
    $board = [string]($(if ($base -and $base.Product) { $base.Product } else { '' })).Trim()
    $biosVendor = [string]($(if ($bios -and $bios.Manufacturer) { $bios.Manufacturer } else { '' })).Trim()

    $family = 'Generic'
    $blob = "$manufacturer $model $board $biosVendor"

    if ($blob -match 'Alienware') {
        $family = 'Alienware'
    } elseif ($manufacturer -match 'Dell' -or $blob -match '\bInspiron\b|\bLatitude\b|\bPrecision\b|\bXPS\b|\bOptiPlex\b') {
        $family = 'Dell'
    } elseif ($manufacturer -match 'ASUS|AsusTek' -or $blob -match '\bTUF\b|\bROG\b|\bVivobook\b|\bZenbook\b|\bStrix\b') {
        $family = 'ASUS'
    } elseif ($manufacturer -match 'Lenovo' -or $blob -match '\bThinkPad\b|\bIdeaPad\b|\bLegion\b|\bYoga\b') {
        $family = 'Lenovo'
    } elseif ($manufacturer -match 'HP|Hewlett' -or $blob -match '\bPavilion\b|\bOMEN\b|\bEliteBook\b|\bProBook\b|\bSpectre\b') {
        $family = 'HP'
    } elseif ($manufacturer -match 'Microsoft' -or $blob -match '\bSurface\b') {
        $family = 'Microsoft'
    } elseif ($manufacturer -match 'Acer' -or $blob -match '\bPredator\b|\bNitro\b|\bAspire\b|\bSwift\b') {
        $family = 'Acer'
    } elseif ($manufacturer -match 'MSI' -or $blob -match '\bStealth\b|\bRaider\b|\bKatana\b') {
        $family = 'MSI'
    } elseif ($manufacturer -match 'Samsung') {
        $family = 'Samsung'
    } elseif ($manufacturer -match 'Gigabyte|AORUS') {
        $family = 'Gigabyte'
    } elseif ($manufacturer -match 'Razer') {
        $family = 'Razer'
    } elseif ($manufacturer -match 'Framework') {
        $family = 'Framework'
    } elseif ($manufacturer -match 'Toshiba|Dynabook') {
        $family = 'Dynabook'
    } elseif ($manufacturer -match 'Fujitsu') {
        $family = 'Fujitsu'
    } elseif ($manufacturer -match 'Huawei') {
        $family = 'Huawei'
    } elseif ($manufacturer -match 'Xiaomi|Redmi') {
        $family = 'Xiaomi'
    } elseif ($manufacturer -match 'LG Electronics|\bLG\b') {
        $family = 'LG'
    } elseif ($manufacturer -match 'Sony') {
        $family = 'Sony'
    } elseif ($manufacturer -match 'Apple') {
        $family = 'Apple'
    } elseif ($manufacturer -match 'System manufacturer|To Be Filled|Default string|OEM' -or $model -match 'To Be Filled|Default string') {
        $family = 'Generic'
    }

    $gpus = @()
    try { $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction SilentlyContinue) } catch { }
    $gpuNames = @($gpus | ForEach-Object { [string]$_.Name } | Where-Object { $_ })

    $hasNvidia = ($gpuNames | Where-Object { $_ -match 'NVIDIA' }).Count -gt 0
    if (-not $hasNvidia -and (Test-Path 'C:\Program Files\NVIDIA Corporation')) { $hasNvidia = $true }
    if (-not $hasNvidia -and (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { $hasNvidia = $true }

    $hasAmdGpu = ($gpuNames | Where-Object { $_ -match 'AMD|Radeon' }).Count -gt 0
    $hasIntelGpu = ($gpuNames | Where-Object { $_ -match 'Intel' }).Count -gt 0

    $awccPath = Join-Path $env:LOCALAPPDATA 'Alienware\Alienware Command Center'
    $hasAwcc = (Test-Path -LiteralPath $awccPath) -or
        $null -ne (Get-Process -Name 'AWCC*','Alienware*' -ErrorAction SilentlyContinue | Select-Object -First 1)

    $hasMyAsus = Test-SmPathOrApp -Paths @(
        'C:\Program Files\ASUS', 'C:\Program Files (x86)\ASUS'
    ) -AppxPatterns @('*MyASUS*', '*ArmouryCrate*', '*ASUSTeK*')

    $hasLenovoVantage = Test-SmPathOrApp -Paths @(
        'C:\Program Files (x86)\Lenovo', 'C:\Program Files\Lenovo'
    ) -AppxPatterns @('*LenovoVantage*', '*LenovoUtility*', '*LenovoCompanion*')

    $hasHpSupport = Test-SmPathOrApp -Paths @(
        'C:\Program Files (x86)\HP', 'C:\Program Files\HP',
        'C:\Program Files (x86)\Hewlett-Packard'
    ) -AppxPatterns @('*HPSupport*', '*HPPCHardware*', '*HPSystem*')

    $hasDellSupportAssist = Test-SmPathOrApp -Paths @(
        'C:\Program Files\Dell', 'C:\Program Files (x86)\Dell',
        'C:\Program Files\Dell Technologies'
    ) -AppxPatterns @('*SupportAssist*', '*Dell*Update*', '*DellCommand*')

    $hasMsiCenter = Test-SmPathOrApp -Paths @(
        'C:\Program Files (x86)\MSI', 'C:\Program Files\MSI',
        'C:\Program Files (x86)\MSI Center'
    ) -AppxPatterns @('*MSICenter*', '*MSI*Dragon*')

    $hasAcerCare = Test-SmPathOrApp -Paths @(
        'C:\Program Files\Acer', 'C:\Program Files (x86)\Acer'
    ) -AppxPatterns @('*Acer*', '*Predator*Sense*')

    $oemCareNote = switch ($family) {
        'Alienware' { 'AWCC overlay/Welcome guards apply; leave SupportAssist alone unless you repair it yourself' }
        'Dell'      { 'Dell SupportAssist / Dell Update left alone' }
        'ASUS'      { 'MyASUS / Armoury Crate left alone; no Alienware steps' }
        'Lenovo'    { 'Lenovo Vantage / Legion Toolkit left alone' }
        'HP'        { 'HP Support Assistant / OMEN Gaming Hub left alone' }
        'MSI'       { 'MSI Center left alone' }
        'Acer'      { 'Acer Care / Predator Sense left alone' }
        'Microsoft' { 'Surface apps left alone' }
        default     { 'OEM care apps are never uninstalled or reconfigured by this toolkit' }
    }

    [pscustomobject]@{
        Manufacturer          = $manufacturer
        Model                 = $model
        Board                 = $board
        BiosVendor            = $biosVendor
        Family                = $family
        IsAlienware           = ($family -eq 'Alienware')
        IsAsus                = ($family -eq 'ASUS')
        IsDell                = ($family -eq 'Dell')
        IsLenovo              = ($family -eq 'Lenovo')
        IsHp                  = ($family -eq 'HP')
        GpuNames              = $gpuNames
        HasNvidia             = [bool]$hasNvidia
        HasAmdGpu             = [bool]$hasAmdGpu
        HasIntelGpu           = [bool]$hasIntelGpu
        HasAwcc               = [bool]$hasAwcc
        HasMyAsus             = [bool]$hasMyAsus
        HasLenovoVantage      = [bool]$hasLenovoVantage
        HasHpSupport          = [bool]$hasHpSupport
        HasDellSupportAssist  = [bool]$hasDellSupportAssist
        HasMsiCenter          = [bool]$hasMsiCenter
        HasAcerCare           = [bool]$hasAcerCare
        ApplyAwccGuards       = [bool]($family -eq 'Alienware' -or $hasAwcc)
        ApplyNvidiaMenu       = [bool]$hasNvidia
        ShowNvidiaDesktopMenu = [bool]$hasNvidia
        OemCareNote           = $oemCareNote
        FormFactorHint        = $(if ($cs -and $cs.PCSystemType -eq 2) { 'Mobile/Laptop' } elseif ($cs -and $cs.PCSystemType -eq 1) { 'Desktop' } else { 'Unknown' })
    }
}

$isDotSourced = ($MyInvocation.InvocationName -eq '.') -or
    ($MyInvocation.Line -match '^\s*\.\s+')

if ($isDotSourced) {
    return
}

$profile = Get-SmOemProfile

if ($AsJson) {
    $profile | ConvertTo-Json -Compress -Depth 4
    return
}

if ($Print) {
    Write-Host ("  PC       : {0} {1}" -f $profile.Manufacturer, $profile.Model)
    Write-Host ("  Profile  : {0} ({1})" -f $profile.Family, $profile.FormFactorHint)
    $gpuLine = if ($profile.GpuNames.Count -gt 0) { ($profile.GpuNames -join '; ') } else { 'none reported' }
    Write-Host ("  GPU      : {0}" -f $gpuLine)
    Write-Host ("  NVIDIA   : {0}" -f ($(if ($profile.ShowNvidiaDesktopMenu) { 'yes - menu + duplicate hide' } else { 'no - NVIDIA menu omitted' })))
    Write-Host ("  AWCC     : {0}" -f ($(if ($profile.ApplyAwccGuards) { 'yes - Alienware overlay guards' } else { 'skip' })))
    Write-Host ("  OEM note : {0}" -f $profile.OemCareNote)
}
