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

# Copy source files from host mount to Docker volume (fast per-file, slow for many files)
for tmpl in laravel next-js python react; do
    if [ -d "$SRC/$tmpl" ]; then
        echo "[$tmpl] Copying source files..."
        mkdir -p "$DST/$tmpl"
        # Use tar for faster bulk copy (avoids per-file overhead)
        tar -C "$SRC" -cf - "$tmpl" | tar -C "$DST" -xf - 2>/dev/null
        echo "[$tmpl] Source copied."
    fi
done

echo ""
echo "Installing dependencies..."

# Laravel
if [ -d "$DST/laravel" ] && [ ! -d "$DST/laravel/vendor" ]; then
    echo "[laravel] composer install..."
    (cd "$DST/laravel" && composer install --no-interaction 2>/dev/null) && \
        echo "[laravel] [ok]" || echo "[laravel] [warn] failed"
fi
if [ -d "$DST/laravel" ] && [ ! -d "$DST/laravel/node_modules" ] && [ -f "$DST/laravel/package.json" ]; then
    echo "[laravel] pnpm install..."
    (cd "$DST/laravel" && pnpm install 2>/dev/null) && \
        echo "[laravel] [ok]" || echo "[laravel] [warn] failed"
fi
if [ -d "$DST/laravel" ] && [ -f "$DST/laravel/.env.example" ] && [ ! -f "$DST/laravel/.env" ]; then
    cp "$DST/laravel/.env.example" "$DST/laravel/.env"
    (cd "$DST/laravel" && php artisan key:generate --force 2>/dev/null) || true
fi

# Next.js
if [ -d "$DST/next-js" ] && [ ! -d "$DST/next-js/node_modules" ] && [ -f "$DST/next-js/package.json" ]; then
    echo "[next-js] pnpm install..."
    (cd "$DST/next-js" && pnpm install 2>/dev/null) && \
        echo "[next-js] [ok]" || echo "[next-js] [warn] failed"
fi

# Python
if [ -d "$DST/python" ] && [ ! -d "$DST/python/venv" ]; then
    echo "[python] venv + pip install..."
    (cd "$DST/python" && python3 -m venv --without-pip venv 2>/dev/null && \
        . venv/bin/activate && \
        curl -sS https://bootstrap.pypa.io/get-pip.py | python3 2>/dev/null && \
        [ -f requirements.txt ] && pip install -r requirements.txt 2>/dev/null || \
        pip install flask 2>/dev/null) && \
        echo "[python] [ok]" || echo "[python] [warn] failed"
fi

# React
if [ -d "$DST/react" ] && [ ! -d "$DST/react/node_modules" ] && [ -f "$DST/react/package.json" ]; then
    echo "[react] pnpm install..."
    (cd "$DST/react" && pnpm install 2>/dev/null) && \
        echo "[react] [ok]" || echo "[react] [warn] failed"
fi

echo ""
echo "========================================="
echo "Example templates initialized!"
echo "========================================="
