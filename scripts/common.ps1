$ScriptDir = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $ScriptDir "docker/compose/docker-compose.yml"
$ContainerName = "devbox-lite"
$ImageName = "devbox-lite"

# Load .env file if exists
$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.+)$") {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
}

# Auto-detect WSL2 if WORKSPACE_PATH not set
if (-not $env:WORKSPACE_PATH) {
    $isWsl = (uname -r 2>$null) -match "microsoft"
    if ($isWsl) {
        $env:WORKSPACE_PATH = $PWD.Path -replace '\\', '/'
    }
}

function Show-Header {
    param([string]$Title)

    Write-Host ""
    Write-Host "========================================="
    Write-Host $Title
    Write-Host "========================================="
    Write-Host ""
}

function Show-Success {
    param([string]$Message)

    Write-Host ""
    Write-Host "✓ $Message"
}

function Show-Error {
    param([string]$Message)

    Write-Host ""
    Write-Host "✗ $Message"
}

function Test-Result {
    param(
        [string]$SuccessMessage,
        [string]$ErrorMessage
    )

    if ($LASTEXITCODE -eq 0) {
        Show-Success $SuccessMessage
    }
    else {
        Show-Error $ErrorMessage
        exit $LASTEXITCODE
    }
}
