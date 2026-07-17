#!/bin/bash
# DevBox Lite - Build image

source "$(dirname "$0")/common.sh"

Show-Header "Building DevBox"

DOCKER_FILE="$PROJECT_ROOT/docker/app/Dockerfile"
BUILD_CONTEXT="$PROJECT_ROOT/docker/app"

docker build -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT"

Test-Result "Build completed successfully." "Build failed."
