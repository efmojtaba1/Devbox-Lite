#!/bin/bash
# DevBox Lite - Rebuild image (no cache)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Rebuilding DevBox (no cache)"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" build --no-cache

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Rebuild completed successfully."
else
    echo ""
    echo "✗ Rebuild failed."
    exit 1
fi
