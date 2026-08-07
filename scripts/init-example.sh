#!/bin/bash
# DevBox Lite - Initialize example templates in Docker volume
# Runs INSIDE the container. Copies source from /example (host mount)
# to /example-data (Docker volume) and installs dependencies there.
# Usage: devbox run /scripts/init-example.sh

set -euo pipefail

SRC="/example"
DST="/example-data"

echo ""
echo "========================================="
echo "Initializing example templates"
echo "========================================="
echo ""

is_online() {
    curl -fsI --connect-timeout 3 https://repo.packagist.org >/dev/null 2>&1 \
    || curl -fsI --connect-timeout 3 https://registry.npmjs.org >/dev/null 2>&1
}

if is_online; then
    echo "  [network] Internet connection detected (Online Mode)."
    PNPM_ARGS="install"
    COMPOSER_ARGS="install --no-interaction --no-scripts --prefer-dist"
    PIP_ARGS="install"
else
    echo "  [network] No internet connection (Offline Mode)."
    PNPM_ARGS="install --offline --frozen-lockfile"
    COMPOSER_ARGS="install --no-interaction --no-scripts"
    PIP_ARGS="install --find-links=/root/.cache/pip/wheels"
fi

# 1. Copy source files from host mount to Docker volume
for tmpl in laravel next-js python react; do
    if [ -d "$SRC/$tmpl" ]; then
        echo "[$tmpl] Copying source files..."
        mkdir -p "$DST/$tmpl"
        rm -rf "$DST/$tmpl"
mkdir -p "$DST/$tmpl"

tar \
  --exclude="$tmpl/node_modules" \
  --exclude="$tmpl/vendor" \
  --exclude="$tmpl/venv" \
  --exclude="$tmpl/.next" \
  --exclude="$tmpl/dist" \
  --exclude="$tmpl/build" \
  -C "$SRC" -cf - "$tmpl" \
| tar -C "$DST" -xf -
        echo "[$tmpl] Source copied."
    fi
done

echo ""
echo "Installing dependencies into baseline volume..."

# 2. Laravel Setup & Vendor Initialization
if [ -d "$DST/laravel" ]; then

    # ---------- Composer ----------
    if [ ! -d "$DST/laravel/vendor" ] && [ -f "$DST/laravel/composer.json" ]; then
        echo "[laravel] Building vendor directory (composer install)..."
        (
            cd "$DST/laravel"
            composer $COMPOSER_ARGS
        ) && \
        echo "[laravel] [ok] vendor created successfully." || \
        echo "[laravel] [warn] composer install failed."
    else
        echo "[laravel] [skip] vendor already present."
    fi

    # ---------- PNPM ----------
    if [ -f "$DST/laravel/package.json" ]; then

        # Baseline نباید node_modules آماده را از سورس نگه دارد
        if [ -d "$DST/laravel/node_modules" ]; then
            echo "[laravel] Removing copied node_modules..."
            rm -rf "$DST/laravel/node_modules"
        fi

        echo "[laravel] Building fresh node_modules (pnpm install)..."

        (
            cd "$DST/laravel"
            pnpm $PNPM_ARGS
        ) && \
        echo "[laravel] [ok] node_modules created successfully." || \
        echo "[laravel] [warn] pnpm install failed."
    fi

    # ---------- Laravel .env ----------
    if [ -f "$DST/laravel/.env.example" ] && [ ! -f "$DST/laravel/.env" ]; then
        cp "$DST/laravel/.env.example" "$DST/laravel/.env"
        (
            cd "$DST/laravel"
            php artisan key:generate --force >/dev/null 2>&1
        ) || true
    fi

fi

# 3. Next.js Setup
if [ -d "$DST/next-js" ] && [ ! -d "$DST/next-js/node_modules" ] && [ -f "$DST/next-js/package.json" ]; then
    echo "[next-js] Building node_modules directory (pnpm install)..."
    (cd "$DST/next-js" && pnpm $PNPM_ARGS) && \
        echo "[next-js] [ok]" || echo "[next-js] [warn] failed"
fi

# 4. Python Setup
if [ -d "$DST/python" ] && [ ! -d "$DST/python/venv" ]; then
    echo "[python] Creating venv + installing packages..."
    (cd "$DST/python" && python3 -m venv venv && \
        . venv/bin/activate && \
        ([ -f requirements.txt ] && pip $PIP_ARGS -r requirements.txt || \
        pip $PIP_ARGS flask)) && \
            echo "[python] [ok]" || echo "[python] [warn] failed"
fi

# 5. React Setup
if [ -d "$DST/react" ] && [ ! -d "$DST/react/node_modules" ] && [ -f "$DST/react/package.json" ]; then
    echo "[react] Building node_modules directory (pnpm install)..."
    (cd "$DST/react" && pnpm $PNPM_ARGS) && \
        echo "[react] [ok]" || echo "[react] [warn] failed"
fi

echo ""
echo "========================================="
echo "Example templates initialized successfully!"
echo "========================================="
