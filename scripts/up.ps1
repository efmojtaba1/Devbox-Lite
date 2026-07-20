. "$PSScriptRoot/common.ps1"

Show-Header "Starting DevBox Lite"

docker compose `
    -f $ComposeFile `
    up -d

Test-Result "DevBox Lite container started." "Failed to start DevBox Lite container."

# Check if example templates are initialized (wait for container to be ready)
Write-Host ""
$initialized = $false
for ($i = 1; $i -le 5; $i++) {
    Start-Sleep -Seconds 3
    docker exec $ContainerName bash -c "test -d /example-data/laravel" 2>$null
    if ($LASTEXITCODE -eq 0) { $initialized = $true; break }
}
if (-not $initialized) {
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
