. "$PSScriptRoot/common.ps1"

Show-Header "Stopping DevBox"

Write-Host "⚠ Note: Bruno collections are stored in a Docker named volume."
Write-Host "  Do NOT use 'docker compose down -v' as it will remove volumes."
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

# ۲. توقف کانتینر اصلی
docker compose `
    -f $ComposeFile `
    down

Test-Result "DevBox stopped." "Failed to stop DevBox."
