#!/bin/bash
# DevBox Lite - Stop all containers and remove volumes

source "$(dirname "$0")/common.sh"

Show-Header "Stopping DevBox Lite (with volumes)"

# ۱. توقف و حذف تمام کانتینرهای devbox- (به جز کانتینر اصلی)
echo "Stopping database containers..."
db_containers=$(docker ps -a --format '{{.Names}}' | grep -E '^devbox-' | grep -v '^devbox-lite$' || true)

if [ -n "$db_containers" ]; then
    for container in $db_containers; do
        echo "  Stopping $container..."
        docker stop "$container" 2>/dev/null
        docker rm "$container" 2>/dev/null
    done
fi

# ۲. توقف کانتینر اصلی + حذف volume ها
echo ""
docker compose -f "$COMPOSE_FILE" down -v

if [ $? -eq 0 ]; then
    Show-Success "DevBox Lite stopped and volumes removed."
else
    Show-Error "Failed to stop DevBox Lite."
    exit 1
fi
