[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

    if ($wsl.State -eq 'Enabled' -and $vmp.State -eq 'Enabled') {
        Write-Host '  [OK] WSL and Virtual Machine Platform are already enabled.'
        exit 0
    }

    Write-Host '  Enabling Windows Subsystem for Linux...'
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to enable Windows Subsystem for Linux.'
        exit 1
    }

    Write-Host '  Enabling Virtual Machine Platform...'
    Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[ERROR] Failed to enable Virtual Machine Platform.'
        exit 1
    }

    Write-Host '  [OK] Required WSL2 Windows features were enabled.'
    Write-Host '  [INFO] A Windows restart is required.'
    exit 3010
}
catch {
    Write-Host "[ERROR] Failed to configure WSL2 Windows features: $($_.Exception.Message)"
    exit 1
}
