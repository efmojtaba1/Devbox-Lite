#!/bin/bash
# DevBox Lite - Build image

source "$(dirname "$0")/common.sh"

Show-Header "Building DevBox"

docker compose -f "$COMPOSE_FILE" build

Test-Result "Build completed successfully." "Build failed."
