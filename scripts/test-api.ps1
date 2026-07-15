. "$PSScriptRoot/common.ps1"

Show-Header "Opening Bruno"
docker exec -d $ContainerName bash -c "/usr/local/bin/start-bruno"
Write-Host ""
Write-Host "Bruno is starting in the background..." -ForegroundColor Green
Write-Host "Access at: http://localhost:6080" -ForegroundColor Cyan
Write-Host ""
