#!/bin/bash
# DevBox Lite - Rebuild image (no cache)

source "$(dirname "$0")/common.sh"

Show-Header "Rebuilding DevBox (no cache)"

docker compose -f "$COMPOSE_FILE" build --no-cache

Test-Result "Rebuild completed successfully." "Rebuild failed."
