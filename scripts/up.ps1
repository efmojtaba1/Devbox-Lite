. "$PSScriptRoot/common.ps1"

Show-Header "Starting DevBox Lite"

docker compose `
    -f $ComposeFile `
    up -d

Test-Result "DevBox Lite container started." "Failed to start DevBox Lite container."

# Check if example templates are initialized
Start-Sleep -Seconds 3
$check = docker exec $ContainerName bash -c "test -d /example-data/laravel" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Example templates not found. Initializing..."
    docker exec $ContainerName bash -c "/scripts/init-example.sh" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[warn] init-example failed. Run 'devbox init-example' manually." -ForegroundColor Yellow
    }
}

$workspacePath = Join-Path $PSScriptRoot "..\workspace"

Write-Host ""
Write-Host "========================================="
Write-Host "DevBox Lite is ready!"
Write-Host "========================================="
Write-Host ""
Write-Host "Main container: $ContainerName"
Write-Host "Workspace: $workspacePath"
Write-Host ""
Write-Host "Use 'shell' to enter the container."
Write-Host "Use 'setup-deps' to configure database services."
