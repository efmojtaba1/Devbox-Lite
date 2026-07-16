#!/bin/bash
# DevBox Lite - Check status

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

echo ""
echo "========================================="
echo "DevBox Lite Status"
echo "========================================="
echo ""

docker compose -f "$COMPOSE_FILE" ps
