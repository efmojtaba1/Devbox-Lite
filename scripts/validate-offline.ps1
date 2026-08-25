[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host "[ERROR] $Message"
    exit 1
}

try {
    Write-Host '  [validate] Checking Windows version...'
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $caption = [string]$os.Caption
    $supported = (($caption -match 'Windows 10') -and ($build -ge 19045)) -or
                 (($caption -match 'Windows 11') -and ($build -ge 22631))

    if (-not $supported) {
        Fail "Unsupported Windows version: $caption build $build. Required: Windows 10 22H2 build 19045+, or Windows 11 23H2 build 22631+."
    }

    Write-Host '  [validate] Checking 64-bit Windows...'
    if (-not [Environment]::Is64BitOperatingSystem) {
        Fail 'A 64-bit Windows installation is required.'
    }

    Write-Host '  [validate] Checking physical memory...'
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    if ($ram -lt 8GB) {
        $ramGb = [math]::Round($ram / 1GB, 1)
        Fail "At least 8 GB of RAM is required. Detected: ${ramGb} GB."
    }

    Write-Host '  [validate] Checking hardware virtualization...'
    $virt = Get-CimInstance Win32_Processor |
        Select-Object -First 1 -ExpandProperty VirtualizationFirmwareEnabled -ErrorAction SilentlyContinue

    if ($virt -eq $false) {
        Fail 'Hardware virtualization is disabled in BIOS/UEFI. Enable Intel VT-x or AMD-V/SVM and run setup again.'
    }

    if ($null -eq $virt) {
        Write-Host '  [WARN] Firmware virtualization state could not be detected. Continuing.'
    }

    $required = @(
        @{ Path = (Join-Path $PackageRoot 'offline-deps\wsl.x64.msi'); Name = 'WSL MSI' },
        @{ Path = (Join-Path $PackageRoot 'offline-deps\ubuntu-24.04.4-wsl-amd64.wsl'); Name = 'Ubuntu 24.04 WSL package' },
        @{ Path = (Join-Path $PackageRoot 'offline-deps\Docker Desktop Installer.exe'); Name = 'Docker Desktop installer' },
        @{ Path = (Join-Path $PackageRoot 'image.tar'); Name = 'DevBox Docker image' },
        @{ Path = (Join-Path $PackageRoot 'scripts\manage-wsl-features.ps1'); Name = 'manage-wsl-features.ps1' }
    )

    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
            Fail "Required offline package file was not found: $($item.Name)`n        $($item.Path)"
        }
    }

    Write-Host '  [OK] Windows prerequisites passed.'
    Write-Host '  [OK] Required offline package files found.'
    exit 0
}
catch {
    Write-Host "[ERROR] Validation failed: $($_.Exception.Message)"
    exit 1
}
