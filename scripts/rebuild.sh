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
echo "  1) Iran Mirror (ir.archive.ubuntu.com) [default]"
echo "  2) ArvanCloud Mirror (mirror.arvancloud.ir)"
echo "  3) Default Ubuntu Mirrors"
echo "  4) Custom URL"
echo ""
read -r -p "Enter choice (1-4) [1]: " mirror_choice

case "${mirror_choice:-1}" in
    1) APT_MIRROR="http://ir.archive.ubuntu.com/ubuntu" ;;
    2) APT_MIRROR="https://mirror.arvancloud.ir/ubuntu" ;;
    3) APT_MIRROR="" ;;
    4)
        read -r -p "Enter mirror URL: " APT_MIRROR
        ;;
    *) APT_MIRROR="http://ir.archive.ubuntu.com/ubuntu" ;;
esac

if [ -n "$APT_MIRROR" ]; then
    echo ""
    echo "Using APT mirror: $APT_MIRROR"
else
    echo ""
    echo "Using default Ubuntu mirrors"
fi

echo ""

# Pip mirror selection
echo "========================================="
echo "Select Pip Mirror:"
echo "========================================="
echo "  1) Aliyun Mirror (mirrors.aliyun.com) [default]"
echo "  2) Tsinghua Mirror (pypi.tuna.tsinghua.edu.cn)"
echo "  3) Default PyPI"
echo "  4) Custom URL"
echo ""
read -r -p "Enter choice (1-4) [1]: " pip_choice

case "${pip_choice:-1}" in
    1) PIP_MIRROR="https://mirrors.aliyun.com/pypi/simple/" ;;
    2) PIP_MIRROR="https://pypi.tuna.tsinghua.edu.cn/simple/" ;;
    3) PIP_MIRROR="" ;;
    4)
        read -r -p "Enter mirror URL: " PIP_MIRROR
        ;;
    *) PIP_MIRROR="https://mirrors.aliyun.com/pypi/simple/" ;;
esac

if [ -n "$PIP_MIRROR" ]; then
    echo ""
    echo "Using pip mirror: $PIP_MIRROR"
else
    echo ""
    echo "Using default PyPI"
fi

echo ""

# Build with mirror args
BUILD_ARGS=""
if [ -n "$APT_MIRROR" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg APT_MIRROR=$APT_MIRROR"
fi
if [ -n "$PIP_MIRROR" ]; then
    BUILD_ARGS="$BUILD_ARGS --build-arg PIP_MIRROR=$PIP_MIRROR"
fi

docker build --no-cache $BUILD_ARGS -t "$IMAGE_NAME" -f "$DOCKER_FILE" "$BUILD_CONTEXT"

Test-Result "Rebuild completed successfully." "Rebuild failed."
