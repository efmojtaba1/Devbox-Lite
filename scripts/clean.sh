#!/bin/bash
# DevBox Lite - Clean image and containers

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "Cleaning DevBox"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" down
docker rmi devbox-lite 2>/dev/null

echo ""
echo "✓ DevBox cleaned."
