#!/bin/bash
# DevBox Lite - Start container

source "$(dirname "$0")/common.sh"

Show-Header "Starting DevBox Lite"

docker compose -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    Show-Success "DevBox Lite container started."

    # Check if example templates are initialized
    sleep 3
    if ! docker exec "$CONTAINER_NAME" bash -c "test -d /example-data/laravel" 2>/dev/null; then
        echo ""
        echo "Example templates not found. Initializing..."
        docker exec "$CONTAINER_NAME" bash -c "/scripts/init-example.sh" 2>/dev/null || \
            echo "[warn] init-example failed. Run 'devbox init-example' manually."
    fi

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
