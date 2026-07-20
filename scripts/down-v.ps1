. "$PSScriptRoot/common.ps1"

Show-Header "Stopping DevBox (with volumes)"

Write-Host "⚠ This will remove ALL named volumes including:"
Write-Host "  - bruno-collections (API collections)"
Write-Host "  - bruno-config (Bruno settings)"
Write-Host "  - pnpm-store"
Write-Host "  - node_modules/vendor/venv caches"
Write-Host ""

# ۱. توقف تمام کانتینرهای devbox- (به جز کانتینر اصلی)
$dbContainers = docker ps -a --format '{{.Names}}' | Where-Object { $_ -match '^devbox-' -and $_ -ne $ContainerName }

if ($dbContainers) {
    foreach ($container in $dbContainers) {
        Write-Host "Stopping $container..."
        docker stop $container 2>$null
        docker rm $container 2>$null
    }
}

# ۲. توقف کانتینر اصلی + حذف volume ها
docker compose `
    -f $ComposeFile `
    down -v

Test-Result "DevBox stopped and volumes removed." "Failed to stop DevBox."
