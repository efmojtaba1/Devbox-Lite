#!/bin/bash
# DevBox Lite - Check status

source "$(dirname "$0")/common.sh"

Show-Header "DevBox Lite Status"

docker compose -f "$COMPOSE_FILE" ps
