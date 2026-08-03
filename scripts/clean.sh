#!/bin/bash
# DevBox Lite - Clean image and containers

source "$(dirname "$0")/common.sh"

Show-Header "Cleaning DevBox"

# Stop and remove database containers
db_containers=$(docker ps -a --format '{{.Names}}' | grep -E '^devbox-' | grep -v "^${CONTAINER_NAME}$" || true)
if [ -n "$db_containers" ]; then
    for container in $db_containers; do
        echo "  Stopping $container..."
        docker stop "$container" 2>/dev/null
        docker rm "$container" 2>/dev/null
    done
fi

docker compose -f "$COMPOSE_FILE" down 2>/dev/null
docker rmi "$IMAGE_NAME" 2>/dev/null

Show-Success "DevBox cleaned."
