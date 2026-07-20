#!/bin/bash
# DevBox Lite - Rebuild image (no cache)

source "$(dirname "$0")/common.sh"

Show-Header "Rebuilding DevBox (no cache)"

DOCKER_FILE="$PROJECT_ROOT/docker/app/Dockerfile"
BUILD_CONTEXT="$PROJECT_ROOT/docker/app"
PREBUILT_DIR="$PROJECT_ROOT/prebuilt/images"

# Load prebuilt base images if available
echo "Checking for prebuilt images..."
if [ -f "$PREBUILT_DIR/ubuntu-24.04.tar.gz" ]; then
    echo "  Loading ubuntu:24.04 from prebuilt..."
    docker load -i "$PREBUILT_DIR/ubuntu-24.04.tar.gz" 2>/dev/null && \
        echo "  [ok] ubuntu:24.04 loaded" || \
        echo "  [skip] ubuntu:24.04 already exists or load failed"
elif [ -f "$PREBUILT_DIR/ubuntu-24.04.tar" ]; then
    echo "  Loading ubuntu:24.04 from prebuilt..."
    docker load -i "$PREBUILT_DIR/ubuntu-24.04.tar" 2>/dev/null && \
        echo "  [ok] ubuntu:24.04 loaded" || \
        echo "  [skip] ubuntu:24.04 already exists or load failed"
else
    echo "  [info] No prebuilt ubuntu:24.04 found, will download"
fi
echo ""

# Mirror selection
echo "========================================="
echo "Select APT Mirror:"
echo "========================================="
echo "  1) ArvanCloud (mirror.arvancloud.ir) [default - fastest]"
echo "  2) Iran Official (ir.archive.ubuntu.com)"
echo "  3) Default Ubuntu Mirrors"
echo "  4) Custom URL"
echo ""
read -r -p "Enter choice (1-4) [1]: " mirror_choice

case "${mirror_choice:-1}" in
    1) APT_MIRROR="https://mirror.arvancloud.ir/ubuntu" ;;
    2) APT_MIRROR="http://ir.archive.ubuntu.com/ubuntu" ;;
    3) APT_MIRROR="" ;;
    4)
        read -r -p "Enter mirror URL: " APT_MIRROR
        ;;
    *) APT_MIRROR="https://mirror.arvancloud.ir/ubuntu" ;;
esac

if [ -n "$APT_MIRROR" ]; then
    echo ""
    echo "Using APT mirror: $APT_MIRROR"
else
    echo ""
    echo "Using default Ubuntu mirrors"
fi

# Auto-select best pip mirror (PyPI default is fastest from Iran)
PIP_MIRROR=""
echo "Using pip mirror: Default PyPI (pypi.org) - fastest from Iran"
echo ""

# Build with mirror args
BUILD_ARGS=""
if [ -n "$APT_MIRROR" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg APT_MIRROR=$APT_MIRROR"
fi

# Copy example templates into build context (Dockerfile needs them)
# Exclude dependency dirs (symlinks to Docker volumes, can't be copied)
echo "Copying example templates to build context..."
rm -rf "$BUILD_CONTEXT/example" 2>/dev/null
mkdir -p "$BUILD_CONTEXT/example"
for tmpl in laravel next-js python react; do
    if [ -d "$PROJECT_ROOT/example/$tmpl" ]; then
        mkdir -p "$BUILD_CONTEXT/example/$tmpl"
        for item in "$PROJECT_ROOT/example/$tmpl"/*; do
            name=$(basename "$item")
            case "$name" in
                node_modules|vendor|venv|.next|__pycache__) continue ;;
            esac
            cp -a "$item" "$BUILD_CONTEXT/example/$tmpl/" 2>/dev/null
        done
    fi
done

docker build --no-cache $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT"

Test-Result "Rebuild completed successfully." "Rebuild failed."

# Cleanup copied example from build context
rm -rf "$BUILD_CONTEXT/example" 2>/dev/null

# Start container and initialize example templates
echo ""
Show-Header "Initializing Example Templates"
docker compose -f "$COMPOSE_FILE" up -d 2>/dev/null
sleep 5
docker exec "$CONTAINER_NAME" bash -c "/scripts/init-example.sh" || \
    echo "[warn] init-example failed. Run 'devbox init-example' manually."
