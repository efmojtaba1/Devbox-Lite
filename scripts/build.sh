#!/bin/bash
# DevBox Lite - Build image

set -e

# ==========================================
# 🚀 Ensure Docker Daemon is Running
# ==========================================
if ! docker info >/dev/null 2>&1; then
    echo "⚠️  Docker daemon is not running. Attempting to start Docker service..."

    # Try starting Docker using service command (WSL / native Linux)
    echo "  Trying 'service docker start'..."
    sudo service docker start 2>&1 || {
        echo "  service docker start failed."
        echo "  Trying 'sudo dockerd' as fallback..."
        sudo dockerd >&2 &
        sleep 2
    }

    # Wait up to 30 seconds for Docker daemon to respond
    COUNTER=0
    until docker info >/dev/null 2>&1 || [ $COUNTER -eq 30 ]; do
        echo "Waiting for Docker daemon to initialize... ($((30 - COUNTER))s)"
        sleep 1
        COUNTER=$((COUNTER + 1))
    done

    # Final verification check
    if ! docker info >/dev/null 2>&1; then
        echo ""
        echo "❌ Error: Could not connect to Docker daemon."
        echo "Please ensure Docker is installed and running (or start Docker Desktop on Windows)."
        echo ""
        echo "Debug info:"
        echo "  Docker binary: $(which docker 2>/dev/null || echo 'not found')"
        echo "  Dockerd binary: $(which dockerd 2>/dev/null || echo 'not found')"
        echo "  Docker socket: $(ls -la /var/run/docker.sock 2>/dev/null || echo 'not found')"
        echo "  Service status:"
        service docker status 2>&1 | head -5 || true
        exit 1
    fi
    echo "✅ Docker daemon started successfully!"
fi

# ==========================================
# 🏗️ Rest of your build script operations...
# ==========================================

source "$(dirname "$0")/common.sh"

Show-Header "Building DevBox"

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
    1) APT_MIRROR="http://mirror.arvancloud.ir/ubuntu" ;;
    2) APT_MIRROR="http://ir.archive.ubuntu.com/ubuntu" ;;
    3) APT_MIRROR="" ;;
    4) read -r -p "Enter mirror URL: " APT_MIRROR ;;
    *) APT_MIRROR="http://mirror.arvancloud.ir/ubuntu" ;;
esac

if [ -n "$APT_MIRROR" ]; then
    echo ""
    echo "Using APT mirror: $APT_MIRROR"
else
    echo ""
    echo "Using default Ubuntu mirrors"
fi

PIP_MIRROR=""
echo "Using pip mirror: Default PyPI (pypi.org) - fastest from Iran"
echo ""

# Build with mirror args
BUILD_ARGS=""
if [ -n "$APT_MIRROR" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg APT_MIRROR=$APT_MIRROR"
fi

# Copy example templates into build context (Dockerfile needs them)
echo "Copying example templates to build context..."
mkdir -p "$BUILD_CONTEXT/example"
shopt -s dotglob
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
shopt -u dotglob

# تشخیص ریشه‌ای موتور بیلد: Buildx (تایمر/پروگرس زنده) در برابر Legacy
if docker buildx version >/dev/null 2>&1; then
    echo "🚀 Using Docker BuildKit with buildx..."
    docker buildx build $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT" --load
else
    echo "⚠️ Docker buildx not found. Falling back to legacy build..."
    echo "💡 Tip: For progress bar and faster builds, run: sudo apt install docker-buildx"
    DOCKER_BUILDKIT=0 docker build $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT"
fi

Test-Result "Build completed successfully." "Build failed."

# Cleanup copied example from build context
rm -rf "$BUILD_CONTEXT/example" 2>/dev/null

# Start container and initialize example templates
echo ""
Show-Header "Initializing Example Templates"

if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" up -d 2>/dev/null
else
    docker-compose -f "$COMPOSE_FILE" up -d 2>/dev/null
fi

sleep 5
docker exec "$CONTAINER_NAME" bash -c "/scripts/init-example.sh" || \
    echo "[warn] init-example failed. Run 'devbox init-example' manually."
