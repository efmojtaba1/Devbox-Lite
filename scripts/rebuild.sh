#!/bin/bash
# DevBox Lite - Rebuild image (no cache)

source "$(dirname "$0")/common.sh"

Show-Header "Rebuilding DevBox (no cache)"

DOCKER_FILE="$PROJECT_ROOT/docker/app/Dockerfile"
BUILD_CONTEXT="$PROJECT_ROOT/docker/app"

docker build --no-cache -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT"

Test-Result "Rebuild completed successfully." "Rebuild failed."
