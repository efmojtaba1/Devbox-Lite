. "$PSScriptRoot/common.ps1"

Show-Header "Cleaning DevBox"

# ۱. توقف و حذف کانتینرهای devbox-* (به جز کانتینر اصلی)
$dbContainers = docker ps -a --format '{{.Names}}' | Where-Object { $_ -match '^devbox-' -and $_ -ne $ContainerName }

if ($dbContainers) {
    foreach ($container in $dbContainers) {
        Write-Host "Stopping $container..."
        docker stop $container 2>$null
        docker rm $container 2>$null
    }
}

# ۲. توقف و حذف کانتینر اصلی
docker compose -f $ComposeFile down 2>$null

# ۳. حذف ایمیج DevBox
docker rmi $ImageName 2>$null

Show-Success "DevBox cleaned."
