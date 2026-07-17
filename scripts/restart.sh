#!/bin/bash
# DevBox Lite - Restart container

source "$(dirname "$0")/common.sh"

Show-Header "Restarting DevBox Lite"

docker compose -f "$COMPOSE_FILE" restart

Test-Result "DevBox Lite container restarted." "Failed to restart DevBox Lite container."
