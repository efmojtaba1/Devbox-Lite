param(
    [string]$Tool = ""
)

. "$PSScriptRoot/common.ps1"

switch ($Tool) {
    "bruno" {
        Show-Header "Opening Bruno"
        docker exec -d $ContainerName bash -c "/usr/local/bin/start-bruno"
        Write-Host ""
        Write-Host "Bruno is starting in the background..." -ForegroundColor Green
        Write-Host "Access at: http://localhost:6081" -ForegroundColor Cyan
        Write-Host ""
    }
    "postman" {
        Show-Header "Opening Postman"
        docker exec -d $ContainerName bash -c "/usr/local/bin/start-postman"
        Write-Host ""
        Write-Host "Postman is starting in the background..." -ForegroundColor Green
        Write-Host "Access at: http://localhost:6080" -ForegroundColor Cyan
        Write-Host ""
    }
    default {
        Show-Header "API Testing Tools"
        Write-Host "  1) Bruno - Lightweight, fast" -ForegroundColor Cyan
        Write-Host "  2) Postman - Advanced features" -ForegroundColor Cyan
        Write-Host ""
        $choice = Read-Host "Select tool (1-2)"
        switch ($choice) {
            "1" {
                Show-Header "Opening Bruno"
                docker exec -d $ContainerName bash -c "/usr/local/bin/start-bruno"
                Write-Host ""
                Write-Host "Bruno is starting in the background..." -ForegroundColor Green
                Write-Host "Access at: http://localhost:6081" -ForegroundColor Cyan
                Write-Host ""
            }
            "2" {
                Show-Header "Opening Postman"
                docker exec -d $ContainerName bash -c "/usr/local/bin/start-postman"
                Write-Host ""
                Write-Host "Postman is starting in the background..." -ForegroundColor Green
                Write-Host "Access at: http://localhost:6080" -ForegroundColor Cyan
                Write-Host ""
            }
            default {
                Write-Host "Invalid choice." -ForegroundColor Red
            }
        }
    }
}
