#!/bin/bash
# DevBox Lite - Install dependencies in example templates
# Runs INSIDE the container. Installs into /prebuilt/example/ (mounted from host).
# After this, example/ contains complete projects ready for offline copy.
# Usage: devbox setup-example

set -euo pipefail

EXAMPLE_DIR="/example-data"

echo ""
echo "========================================="
echo "Installing dependencies in example templates"
echo "========================================="
echo ""

# Laravel
if [ -d "$EXAMPLE_DIR/laravel" ] && [ -f "$EXAMPLE_DIR/laravel/composer.json" ]; then
    echo "[laravel] Installing dependencies..."
    if [ -d "$EXAMPLE_DIR/laravel/vendor" ]; then
        echo "[laravel] [skip] vendor already present"
    else
        (cd "$EXAMPLE_DIR/laravel" && composer install --no-interaction 2>/dev/null) && \
            echo "[laravel] [ok] composer install" || \
            echo "[laravel] [warn] composer install failed"
    fi
    if [ -d "$EXAMPLE_DIR/laravel/node_modules" ]; then
        echo "[laravel] [skip] node_modules already present"
    elif [ -f "$EXAMPLE_DIR/laravel/package.json" ]; then
        (cd "$EXAMPLE_DIR/laravel" && pnpm install 2>/dev/null) && \
            echo "[laravel] [ok] pnpm install" || \
            echo "[laravel] [warn] pnpm install failed"
    fi
    if [ -f "$EXAMPLE_DIR/laravel/.env.example" ] && [ ! -f "$EXAMPLE_DIR/laravel/.env" ]; then
        cp "$EXAMPLE_DIR/laravel/.env.example" "$EXAMPLE_DIR/laravel/.env"
    fi
    if [ -f "$EXAMPLE_DIR/laravel/artisan" ]; then
        (cd "$EXAMPLE_DIR/laravel" && php artisan key:generate --force 2>/dev/null) || true
    fi
    echo ""
else
    echo "[laravel] NOT FOUND or missing composer.json — skipping"
    echo ""
fi

# Next.js
if [ -d "$EXAMPLE_DIR/next-js" ] && [ -f "$EXAMPLE_DIR/next-js/package.json" ]; then
    echo "[next-js] Installing dependencies..."
    if [ -d "$EXAMPLE_DIR/next-js/node_modules" ]; then
        echo "[next-js] [skip] node_modules already present"
    else
        (cd "$EXAMPLE_DIR/next-js" && pnpm install 2>/dev/null) && \
            echo "[next-js] [ok] pnpm install" || \
            echo "[next-js] [warn] pnpm install failed"
    fi
    echo ""
else
    echo "[next-js] NOT FOUND or missing package.json — skipping"
    echo ""
fi

# Python
if [ -d "$EXAMPLE_DIR/python" ] && [ -f "$EXAMPLE_DIR/python/requirements.txt" ]; then
    echo "[python] Installing dependencies..."
    if [ -d "$EXAMPLE_DIR/python/venv" ]; then
        echo "[python] [skip] venv already present"
    else
        (cd "$EXAMPLE_DIR/python" && python3 -m venv venv 2>/dev/null && \
            . venv/bin/activate && pip install -r requirements.txt 2>/dev/null) && \
            echo "[python] [ok] venv + pip install" || \
            echo "[python] [warn] setup failed"
    fi
    echo ""
else
    echo "[python] NOT FOUND or missing requirements.txt — skipping"
    echo ""
fi

# React
if [ -d "$EXAMPLE_DIR/react" ] && [ -f "$EXAMPLE_DIR/react/package.json" ]; then
    echo "[react] Installing dependencies..."
    if [ -d "$EXAMPLE_DIR/react/node_modules" ]; then
        echo "[react] [skip] node_modules already present"
    else
        (cd "$EXAMPLE_DIR/react" && pnpm install 2>/dev/null) && \
            echo "[react] [ok] pnpm install" || \
            echo "[react] [warn] pnpm install failed"
    fi
    echo ""
else
    echo "[react] NOT FOUND or missing package.json — skipping"
    echo ""
fi

echo "========================================="
echo "Done! Templates are ready for offline use."
echo "========================================="
