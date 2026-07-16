#!/bin/bash
# DevBox Lite - Build image

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Building DevBox"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" build

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build completed successfully."
else
    echo ""
    echo "✗ Build failed."
    exit 1
fi
