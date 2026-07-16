#!/bin/bash
# DevBox Lite - Stop container

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Stopping DevBox Lite"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" down

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ DevBox Lite container stopped."
else
    echo ""
    echo "✗ Failed to stop DevBox Lite container."
    exit 1
fi
