. "$PSScriptRoot/common.ps1"

Show-Header "Stopping DevBox"

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
