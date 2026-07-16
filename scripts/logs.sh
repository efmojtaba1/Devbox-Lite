#!/bin/bash
# DevBox Lite - View logs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

docker compose -f "$COMPOSE_FILE" logs -f devbox
