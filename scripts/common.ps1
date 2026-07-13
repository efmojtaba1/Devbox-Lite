$ComposeFile = "docker/compose/docker-compose.yml"
$ContainerName = "devbox-lite"
$ImageName = "devbox-lite"

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
