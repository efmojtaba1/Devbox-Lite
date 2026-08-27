#!/bin/bash
# DevBox Lite - Build image

set -e

# ==========================================
# 🚀 Ensure Docker Daemon is Running
# ==========================================
start_docker_daemon() {
    local method="$1"

    case "$method" in
        service)
            echo "  [1/4] Trying 'service docker start'..."
            sudo service docker start 2>&1
            ;;
        systemctl)
            echo "  [2/4] Trying 'systemctl start docker'..."
            sudo systemctl start docker 2>&1
            ;;
        dockerd)
            echo "  [3/4] Trying 'dockerd' directly..."
            sudo dockerd --iptables=false --bridge=none >/dev/null 2>&1 &
            sleep 3
            ;;
        dockerd-verbose)
            echo "  [4/4] Trying 'dockerd' with verbose output..."
            sudo dockerd --iptables=false --bridge=none 2>&1 &
            sleep 5
            ;;
    esac
}

if ! docker info >/dev/null 2>&1; then
    echo "⚠️  Docker daemon is not running. Attempting to start Docker service..."

    # Try multiple startup methods in sequence
    local started=false

    for method in service systemctl dockerd dockerd-verbose; do
        echo ""
        start_docker_daemon "$method"

        # Check if Docker is now running
        local waited=0
        while [ $waited -lt 15 ]; do
            if docker info >/dev/null 2>&1; then
                started=true
                break 2
            fi
            sleep 1
            waited=$((waited + 1))
        done
    done

    # Final verification check
    if [ "$started" != "true" ] && ! docker info >/dev/null 2>&1; then
        echo ""
        echo "❌ Error: Could not start Docker daemon."
        echo ""
        echo "Debug information:"
        echo "  Docker binary: $(which docker 2>/dev/null || echo 'not found')"
        echo "  Dockerd binary: $(which dockerd 2>/dev/null || echo 'not found')"
        echo "  Docker socket: $(ls -la /var/run/docker.sock 2>/dev/null || echo 'not found')"
        echo ""
        echo "  Service status:"
        sudo service docker status 2>&1 | head -10 || true
        echo ""
        echo "  systemd running:"
        systemctl is-system-running 2>&1 || true
        echo ""
        echo "  User groups:"
        groups 2>&1 || true
        echo ""
        echo "  WSL version:"
        uname -r 2>&1 || true
        echo ""
        echo "Try manually:"
        echo "  sudo service docker start"
        echo "  sudo dockerd --iptables=false --bridge=none"
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
