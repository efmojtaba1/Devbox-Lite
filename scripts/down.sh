#!/bin/bash
# DevBox Lite - Stop all containers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Stopping DevBox Lite"
echo "========================================="
echo ""

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

# ۲. توقف کانتینر اصلی
echo ""
docker compose -f "$COMPOSE_FILE" down

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ DevBox Lite stopped."
else
    echo ""
    echo "✗ Failed to stop DevBox Lite."
    exit 1
fi
