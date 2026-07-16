#!/bin/bash
# DevBox Lite - Start container

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Starting DevBox Lite"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ DevBox Lite container started."
    echo ""
    echo "========================================="
    echo "DevBox Lite is ready!"
    echo "========================================="
    echo ""
    echo "Use './scripts/shell' to enter the container."
    echo "Use './scripts/setup-deps' to configure database services."
else
    echo ""
    echo "✗ Failed to start DevBox Lite container."
    exit 1
fi
