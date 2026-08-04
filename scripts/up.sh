#!/bin/bash
# DevBox Lite - Start container

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true
source "$SCRIPT_DIR/common.sh"

# ۱. ابتدا بررسی متصل بودن به سرویس داکر
if ! docker info >/dev/null 2>&1; then
    echo "⚠️ Docker daemon is not running. Attempting to start service..."

    if command -v service >/dev/null 2>&1; then
        sudo service docker start

        # ۳ ثانیه مهلت برای آماده شدن سوکت داکر
        echo "Waiting for Docker daemon to initialize..."
        sleep 3
    fi

    # چک مجدد پس از چند ثانیه انتظار
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Error: Cannot connect to Docker daemon."
        echo "Please make sure Docker Desktop is running OR run: 'sudo service docker start'"
        exit 1
    fi
fi

# ۲. تشخیص خودکار نسخه Compose
if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    echo "❌ Error: Neither 'docker compose' nor 'docker-compose' was found."
    echo "Please install docker-compose-v2."
    exit 1
fi

Show-Header "Starting DevBox Lite"

# ۳. اجرای کانتینر با متغیر هوشمند Compose
$DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d

if [ $? -eq 0 ]; then
    Show-Success "DevBox Lite container started."

    # Check if example templates are initialized (wait for container to be ready)
    echo ""
    initialized=false
    for i in 1 2 3 4 5; do
        sleep 3
        if docker exec "$CONTAINER_NAME" bash -c "test -d /example-data/laravel" 2>/dev/null; then
            initialized=true
            break
        fi
    done
    if [ "$initialized" = false ]; then
        echo "Example templates not found. Initializing..."
        docker exec "$CONTAINER_NAME" bash -c "/scripts/init-example.sh" 2>/dev/null || \
            echo "[warn] init-example failed. Run 'devbox init-example' manually."
    fi

    echo ""
    echo "========================================="
    echo "DevBox Lite is ready!"
    echo "========================================="
    echo ""
    echo "Use './scripts/shell.sh' to enter the container."
    echo "Use './scripts/setup-deps.sh' to configure database services."
else
    Show-Error "Failed to start DevBox Lite container."
    exit 1
fi
