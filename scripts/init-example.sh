#!/bin/bash
# DevBox Lite - Initialize example templates in Docker volume
# Runs INSIDE the container. Copies source from /example (host mount)
# to /example-data (Docker volume) and installs dependencies there.
# Only runs once — skips if /example-data already has content.
# Usage: devbox run /scripts/init-example.sh

set -euo pipefail

SRC="/example"
DST="/example-data"

echo ""
echo "========================================="
echo "Initializing example templates"
echo "========================================="
echo ""

# Check if already initialized
if [ -d "$DST/laravel" ] && [ -d "$DST/react" ]; then
    echo "[skip] Example templates already initialized."
    echo "To refresh, run: refresh-example"
    exit 0
fi

# Helper function to check internet connectivity
is_online() {
    ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1
}

if is_online; then
    echo "  [network] Internet connection detected (Online Mode)."
    PNPM_ARGS="install"
    COMPOSER_ARGS="install --no-interaction --no-scripts"
    PIP_ARGS="install"
else
    echo "  [network] No internet connection (Offline Mode)."
    PNPM_ARGS="install --offline --frozen-lockfile"
    COMPOSER_ARGS="install --no-interaction --prefer-offline --no-scripts"
    PIP_ARGS="install --find-links=/root/.cache/pip/wheels"
fi

# Copy source files from host mount to Docker volume
for tmpl in laravel next-js python react; do
    if [ -d "$SRC/$tmpl" ]; then
        echo "[$tmpl] Copying source files..."
        mkdir -p "$DST/$tmpl"
        tar -C "$SRC" -cf - "$tmpl" | tar -C "$DST" -xf - 2>/dev/null
        echo "[$tmpl] Source copied."
    fi
done

echo ""
echo "Installing dependencies..."

# Laravel
if [ -d "$DST/laravel" ] && [ ! -d "$DST/laravel/vendor" ]; then
    echo "[laravel] composer install..."
    (cd "$DST/laravel" && composer $COMPOSER_ARGS) && \
        echo "[laravel] [ok]" || echo "[laravel] [warn] failed"
fi
if [ -d "$DST/laravel" ] && [ ! -d "$DST/laravel/node_modules" ] && [ -f "$DST/laravel/package.json" ]; then
    echo "[laravel] pnpm install..."
    (cd "$DST/laravel" && pnpm $PNPM_ARGS) && \
        echo "[laravel] [ok]" || echo "[laravel] [warn] failed"
fi
if [ -d "$DST/laravel" ] && [ -f "$DST/laravel/.env.example" ] && [ ! -f "$DST/laravel/.env" ]; then
    cp "$DST/laravel/.env.example" "$DST/laravel/.env"
    (cd "$DST/laravel" && php artisan key:generate --force 2>/dev/null) || true
fi

# Next.js
if [ -d "$DST/next-js" ] && [ ! -d "$DST/next-js/node_modules" ] && [ -f "$DST/next-js/package.json" ]; then
    echo "[next-js] pnpm install..."
    (cd "$DST/next-js" && pnpm $PNPM_ARGS) && \
        echo "[next-js] [ok]" || echo "[next-js] [warn] failed"
fi

# Python
if [ -d "$DST/python" ] && [ ! -d "$DST/python/venv" ]; then
    echo "[python] venv + pip install..."
    (cd "$DST/python" && python3 -m venv venv && \
        . venv/bin/activate && \
        ([ -f requirements.txt ] && pip $PIP_ARGS -r requirements.txt || \
        pip $PIP_ARGS flask)) && \
            echo "[python] [ok]" || echo "[python] [warn] failed"
fi

# React
if [ -d "$DST/react" ] && [ ! -d "$DST/react/node_modules" ] && [ -f "$DST/react/package.json" ]; then
    echo "[react] pnpm install..."
    (cd "$DST/react" && pnpm $PNPM_ARGS) && \
        echo "[react] [ok]" || echo "[react] [warn] failed"
fi

echo ""
echo "========================================="
echo "Example templates initialized!"
echo "========================================="
