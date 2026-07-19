. "$PSScriptRoot/common.ps1"

Show-Header "Opening Bruno"

# Check if container is running
$running = docker ps --format '{{.Names}}' 2>$null | Where-Object { $_ -eq $ContainerName }
if (-not $running) {
    Show-Error "DevBox container is not running. Start it first with: .\scripts\up.ps1"
    exit 1
}

docker exec -d $ContainerName bash -c "/usr/local/bin/start-bruno"
Write-Host ""
Write-Host "Bruno is starting in the background..." -ForegroundColor Green
Write-Host "Access at: http://localhost:6080" -ForegroundColor Cyan
Write-Host ""
