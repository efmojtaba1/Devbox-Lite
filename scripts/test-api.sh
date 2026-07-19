#!/bin/bash
# DevBox Lite - Start Bruno API testing client

set -euo pipefail

source "$(dirname "$0")/common.sh"

Show-Header "Opening Bruno API Client"

# Check if container is running
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    Show-Error "DevBox container is not running. Start it first with: ./scripts/up.sh"
    exit 1
fi

docker exec -d "$CONTAINER_NAME" bash -c "/usr/local/bin/start-bruno"

echo ""
echo "Bruno is starting in the background..."
echo "Access at: http://localhost:6080"
echo ""
