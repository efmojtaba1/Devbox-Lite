#!/bin/bash
# DevBox Lite - Start container

source "$(dirname "$0")/common.sh"

Show-Header "Starting DevBox Lite"

docker compose -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    Show-Success "DevBox Lite container started."
    echo ""
    echo "========================================="
    echo "DevBox Lite is ready!"
    echo "========================================="
    echo ""
    echo "Use './scripts/shell' to enter the container."
    echo "Use './scripts/setup-deps' to configure database services."
else
    Show-Error "Failed to start DevBox Lite container."
    exit 1
fi
