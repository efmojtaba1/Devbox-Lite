#!/usr/bin/env bash
set -e

# ── Colors & Constants ───────────────────────────────────────
GREEN='\033[0;32m'
NC='\033[0m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'

# ── Dynamic Path Resolution (WSL2 & Windows Compatible) ──────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "/workspace" ]; then
    WORKSPACE="/workspace"
elif [ -d "$(pwd)/workspace" ]; then
    WORKSPACE="$(pwd)/workspace"
else
    WORKSPACE="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

if [ -d "/example-data" ]; then
    EXAMPLE_DATA="/example-data"
elif [ -d "$WORKSPACE/example-data" ]; then
    EXAMPLE_DATA="$WORKSPACE/example-data"
elif [ -d "$(pwd)/example-data" ]; then
    EXAMPLE_DATA="$(pwd)/example-data"
else
    EXAMPLE_DATA="$SCRIPT_DIR/../example-data"
fi

echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       DevBox Lite — New Project       ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
echo ""

# ── Check Real Network Status (Fix for WSL2/Docker) ──────────
is_online() {
    curl -fsI --connect-timeout 3 https://repo.packagist.org >/dev/null 2>&1 \
    || curl -fsI --connect-timeout 3 https://registry.npmjs.org >/dev/null 2>&1
}

HAS_INTERNET=false
if is_online; then
    HAS_INTERNET=true
fi

ensure_container_running() {
    local name="$1"
    local kind="$2"

    if docker ps --format '{{.Names}}' | grep -q "^$name$"; then
        echo "  [skip] $kind is already running"
        return 0
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^$name$"; then
        echo "  [start] $kind exists, starting..."
        if docker start "$name" >/dev/null 2>&1; then
            echo "  [ok] $kind is running"
            sleep 3
            return 0
        fi
        echo "  [fix] $kind failed to start, recreating..."
        docker rm -f "$name" >/dev/null 2>&1 || true
    fi

    echo "  [create] $kind not found, creating..."
    if [ -x "$SCRIPT_DIR/db-manager.sh" ]; then
        "$SCRIPT_DIR/db-manager.sh" create "$kind"
        sleep 4
    else
        echo "  [warn] db-manager.sh not available; cannot create $kind"
        return 1
    fi
}

# ── 1. Input Project Name ───────────────────────────────────
read -rp "Project name: " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}[error] Project name cannot be empty.${NC}"
    exit 1
fi

project_dir="$WORKSPACE/$PROJECT_NAME"
if [ -d "$project_dir" ]; then
    echo -e "${RED}[error] Directory $project_dir already exists.${NC}"
    exit 1
fi

# ── 2. Select Framework ─────────────────────────────────────
echo ""
echo "Select framework:"
echo "  1) laravel"
echo "  2) next-js"
echo "  3) python"
echo "  4) react"
read -rp "  → Choose [1-4]: " FW_CHOICE

case "$FW_CHOICE" in
    1) TEMPLATE="laravel" ;;
    2) TEMPLATE="next-js" ;;
    3) TEMPLATE="python" ;;
    4) TEMPLATE="react" ;;
    *) echo -e "${RED}[error] Invalid framework selection.${NC}"; exit 1 ;;
esac

# ── 3. Framework Specific Interactive Options ────────────────
STARTER_KIT="None"
DB_CHOICE="SQLite"
TESTING="Pest"
DARK_MODE="yes"
ENABLE_API="no"

TS_FLAG="--ts"
TW_FLAG="--tailwind"
AR_FLAG="--app"

if [ "$HAS_INTERNET" = "false" ]; then
    echo -e "\n${YELLOW}[notice] Network is offline. Interactive options are skipped.${NC}"
    echo -e "${YELLOW}         Project will be created using the pre-cached baseline template.${NC}"
    if [ "$TEMPLATE" = "next-js" ]; then
        echo -e "${CYAN}         (Template includes: TypeScript, Tailwind CSS, App Router)${NC}"
    elif [ "$TEMPLATE" = "laravel" ]; then
        echo -e "${CYAN}         (Template includes: Standard baseline structure)${NC}"
    fi
else
    if [ "$TEMPLATE" = "laravel" ]; then
        echo ""
        echo "┌─ Laravel Options ─────────────────────┐"
        echo ""
        echo "Starter kit:"
        echo "  1) None (bare Laravel)"
        echo "  2) Breeze + Blade"
        echo "  3) Breeze + React"
        echo "  4) Breeze + Vue"
        echo "  5) Jetstream + Livewire"
        echo "  6) Jetstream + Inertia"
        read -rp "  → Choose [1-6]: " SK_CHOICE

        case "$SK_CHOICE" in
            1) STARTER_KIT="None" ;;
            2) STARTER_KIT="Breeze + Blade" ;;
            3) STARTER_KIT="Breeze + React" ;;
            4) STARTER_KIT="Breeze + Vue" ;;
            5) STARTER_KIT="Jetstream + Livewire" ;;
            6) STARTER_KIT="Jetstream + Inertia" ;;
            *) STARTER_KIT="None" ;;
        esac

        echo ""
        echo "Database:"
        echo "  1) SQLite (recommended for dev)"
        echo "  2) MySQL"
        echo "  3) PostgreSQL"
        echo "  4) None"
        read -rp "  → Choose [1-4]: " DB_SEL

        case "$DB_SEL" in
            1) DB_CHOICE="SQLite" ;;
            2) DB_CHOICE="MySQL" ;;
            3) DB_CHOICE="PostgreSQL" ;;
            4) DB_CHOICE="None" ;;
            *) DB_CHOICE="SQLite" ;;
        esac

        echo ""
        echo "Testing:"
        echo "  1) Pest (recommended)"
        echo "  2) PHPUnit"
        read -rp "  → Choose [1-2]: " TEST_SEL
        case "$TEST_SEL" in
            1) TESTING="Pest" ;;
            2) TESTING="PHPUnit" ;;
            *) TESTING="Pest" ;;
        esac

        read -rp "  Dark mode? [Y/n]: " DARK_INPUT
        if [[ "$DARK_INPUT" =~ ^[Nn]$ ]]; then
            DARK_MODE="no"
        else
            DARK_MODE="yes"
        fi

        read -rp "  API routes? [y/N]: " API_INPUT
        if [[ "$API_INPUT" =~ ^[Yy]$ ]]; then
            ENABLE_API="yes"
        else
            ENABLE_API="no"
        fi
        echo "└────────────────────────────────────────┘"

    elif [ "$TEMPLATE" = "next-js" ]; then
        echo ""
        echo "┌─ Next.js Options ─────────────────────┐"
        read -rp "  Use TypeScript? [Y/n]: " TS_INPUT
        if [[ "$TS_INPUT" =~ ^[Nn]$ ]]; then TS_FLAG="--no-ts"; else TS_FLAG="--ts"; fi

        read -rp "  Use Tailwind CSS? [Y/n]: " TW_INPUT
        if [[ "$TW_INPUT" =~ ^[Nn]$ ]]; then TW_FLAG="--no-tailwind"; else TW_FLAG="--tailwind"; fi

        read -rp "  Use App Router? [Y/n]: " AR_INPUT
        if [[ "$AR_INPUT" =~ ^[Nn]$ ]]; then AR_FLAG="--no-app"; else AR_FLAG="--app"; fi
        echo "└────────────────────────────────────────┘"
    fi
fi

# ── Summary & Confirmation ──────────────────────────────────
echo ""
echo "── Summary ──"
echo "  Name:     $PROJECT_NAME"
echo "  Template: $TEMPLATE"
if [ "$TEMPLATE" = "laravel" ] && [ "$HAS_INTERNET" = "true" ]; then
    echo "  Starter:  $STARTER_KIT"
    echo "  Database: $DB_CHOICE"
    echo "  Testing:  $TESTING"
    echo "  Dark:     $DARK_MODE"
    echo "  API:      $ENABLE_API"
elif [ "$TEMPLATE" = "next-js" ] && [ "$HAS_INTERNET" = "true" ]; then
    echo "  TypeScript: $([ "$TS_FLAG" = "--ts" ] && echo "Yes" || echo "No")"
    echo "  Tailwind:   $([ "$TW_FLAG" = "--tailwind" ] && echo "Yes" || echo "No")"
    echo "  App Router: $([ "$AR_FLAG" = "--app" ] && echo "Yes" || echo "No")"
fi
echo ""
read -rp "  Create this project? [Y/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "========================================="
echo "Creating: $PROJECT_NAME ($TEMPLATE)"
echo "========================================="

# ── Fix Git Ownership (پیش از ساخت پروژه اعمال می‌شود) ──────
git config --global --add safe.directory "$project_dir" 2>/dev/null || true
git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true
git config --global --add safe.directory '*' 2>/dev/null || true

# ── Step 1: Copy Source (Offline-First System) ──────────────
example_dir="$EXAMPLE_DATA/$TEMPLATE"
IS_OFFLINE=false

if [ -d "$example_dir" ] && ([ "$HAS_INTERNET" = "false" ] || [ "$TEMPLATE" != "next-js" ]); then
    echo "[offline] Copying baseline from template ($example_dir)..."
    mkdir -p "$project_dir"

    (
        cd "$example_dir"
        tar --exclude='./.next' --exclude='./__pycache__' -cf - .
    ) | tar -C "$project_dir" -xf -

    IS_OFFLINE=true
    echo "[ok] Offline source copied."
else
    echo -e "${YELLOW}[online] Creating fresh project via online CLI tools...${NC}"
    mkdir -p "$project_dir"
    case "$TEMPLATE" in
        laravel) composer create-project laravel/laravel "$project_dir" --prefer-dist --no-interaction ;;
        next-js) pnpm create next-app "$project_dir" $TS_FLAG $TW_FLAG --eslint$AR_FLAG --src-dir --import-alias "@/*" --use-pnpm ;;
        react)   pnpm create vite "$project_dir" --template react-ts ;;
        python)  python3 -m venv "$project_dir/venv" ;;
    esac
fi

# ── Step 2: Install Base Dependencies (Offline First) ───────
echo ""
echo "Installing dependencies..."

if [ -f "$project_dir/composer.json" ] && [ ! -d "$project_dir/vendor" ]; then
    echo "[install] composer install..."
    if [ "$HAS_INTERNET" = "true" ]; then
        (cd "$project_dir" && composer install --prefer-offline --no-audit --no-interaction 2>/dev/null) || true
    else
        echo -e "${YELLOW}[offline] Skipping composer install. Network unavailable.${NC}"
    fi
fi

if [ -f "$project_dir/package.json" ] && [ ! -d "$project_dir/node_modules" ]; then
    echo "[install] pnpm install..."

    if [ "$HAS_INTERNET" = "false" ]; then
        echo "[offline] Installing from pnpm cache..."
        (
            cd "$project_dir"
            pnpm install --offline --frozen-lockfile
        ) || {
            echo -e "${RED}[error] Offline pnpm install failed.${NC}"
            exit 1
        }
    else
        (
            cd "$project_dir"
            pnpm install --prefer-offline --no-interactive
        ) || {
            echo -e "${RED}[error] pnpm install failed.${NC}"
            exit 1
        }
    fi
fi

if [ "$TEMPLATE" = "python" ]; then
    if [ ! -d "$project_dir/venv" ]; then
        echo "[install] creating python venv..."
        python3 -m venv "$project_dir/venv"
    fi
    if [ -f "$project_dir/requirements.txt" ]; then
        echo "[install] pip install..."
        "$project_dir/venv/bin/pip" install --no-index --find-links=/root/.cache/pip -r "$project_dir/requirements.txt" 2>/dev/null || "$project_dir/venv/bin/pip" install -r "$project_dir/requirements.txt" 2>/dev/null || true
    fi
fi

# ── Step 3: Framework Specific Configuration ────────────────

if [ "$TEMPLATE" = "laravel" ]; then
    echo ""
    echo "[configure] Applying Laravel options..."

    [ ! -f "$project_dir/.env" ] && [ -f "$project_dir/.env.example" ] && cp "$project_dir/.env.example" "$project_dir/.env"

    if [ "$HAS_INTERNET" = "true" ] && ([ "$DB_CHOICE" = "MySQL" ] || [ "$DB_CHOICE" = "PostgreSQL" ]); then
        echo "  [db] Ensuring database service is running..."

        if [ "$DB_CHOICE" = "MySQL" ]; then
            ensure_container_running devbox-mysql mysql
        elif [ "$DB_CHOICE" = "PostgreSQL" ]; then
            ensure_container_running devbox-postgres postgres
        fi

        if [ -f "$project_dir/.env" ] && grep -q '^REDIS_HOST=' "$project_dir/.env" 2>/dev/null; then
            echo "  [db] Ensuring Redis service is available..."
            ensure_container_running devbox-redis redis
        fi
    fi

    if [ -f "$project_dir/.env" ]; then
        case "$DB_CHOICE" in
            "MySQL")
                MYSQL_HOST="devbox-mysql"
                getent hosts devbox-mysql >/dev/null 2>&1 || MYSQL_HOST="127.0.0.1"
                sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=mysql/" "$project_dir/.env"
                sed -i "s/^DB_HOST=.*/DB_HOST=${MYSQL_HOST}/" "$project_dir/.env"
                sed -i "s/^# DB_HOST=.*/DB_HOST=${MYSQL_HOST}/" "$project_dir/.env"
                sed -i 's/^DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
                sed -i 's/^# DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
                sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$project_dir/.env"
                sed -i 's/^DB_USERNAME=.*/DB_USERNAME=devbox/' "$project_dir/.env"
                sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=devbox_pass/' "$project_dir/.env"

                mysql -h "$MYSQL_HOST" -u devbox -pdevbox_pass -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT_NAME}\`;" 2>/dev/null || true
                ;;
            "PostgreSQL")
                PG_HOST="devbox-postgres"
                getent hosts devbox-postgres >/dev/null 2>&1 || PG_HOST="127.0.0.1"
                sed -i "s/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/" "$project_dir/.env"
                sed -i "s/^DB_HOST=.*/DB_HOST=${PG_HOST}/" "$project_dir/.env"
                sed -i "s/^# DB_HOST=.*/DB_HOST=${PG_HOST}/" "$project_dir/.env"
                sed -i 's/^DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
                sed -i 's/^# DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
                sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$project_dir/.env"
                sed -i 's/^DB_USERNAME=.*/DB_USERNAME=devbox/' "$project_dir/.env"
                sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=devbox_pass/' "$project_dir/.env"

                PGPASSWORD=devbox_pass psql -h "$PG_HOST" -U devbox -c "CREATE DATABASE ${PROJECT_NAME};" 2>/dev/null || true
                ;;
            "SQLite")
                sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' "$project_dir/.env"
                sed -i 's/^DB_DATABASE=.*/# DB_DATABASE=/' "$project_dir/.env"
                mkdir -p "$project_dir/database"
                touch "$project_dir/database/database.sqlite" 2>/dev/null || true
                ;;
        esac
    fi

    if [ -f "$project_dir/.env" ]; then
        (cd "$project_dir" && php artisan key:generate --no-interaction 2>/dev/null) || true
    fi

    mkdir -p "$project_dir/resources/js"
    cat << 'EOF' > "$project_dir/resources/js/bootstrap.js"
import axios from 'axios';
window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
EOF

    if [ "$HAS_INTERNET" = "true" ] && [ "$STARTER_KIT" != "None" ]; then
        echo "  [starter] Configuring $STARTER_KIT..."
        case "$STARTER_KIT" in
            "Breeze + Blade")
                (
                    cd "$project_dir"
                    composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                    php artisan breeze:install blade --no-interaction $([ "$DARK_MODE" = "yes" ] && echo "--dark") 2>/dev/null || true
                )
                ;;
            "Breeze + React")
                (
                    cd "$project_dir"
                    composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                    php artisan breeze:install react --no-interaction $([ "$DARK_MODE" = "yes" ] && echo "--dark") 2>/dev/null || true
                )
                ;;
            "Breeze + Vue")
                (
                    cd "$project_dir"
                    composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                    php artisan breeze:install vue --no-interaction $([ "$DARK_MODE" = "yes" ] && echo "--dark") 2>/dev/null || true
                )
                ;;
            "Jetstream + Livewire")
                (
                    cd "$project_dir"
                    composer require laravel/jetstream --prefer-offline --no-interaction 2>/dev/null || true
                    php artisan jetstream:install livewire --no-interaction 2>/dev/null || true
                )
                ;;
            "Jetstream + Inertia")
                (
                    cd "$project_dir"
                    composer require laravel/jetstream --prefer-offline --no-interaction 2>/dev/null || true
                    php artisan jetstream:install inertia --no-interaction 2>/dev/null || true
                )
                ;;
        esac
    fi

    if [ "$HAS_INTERNET" = "true" ] && [ "$TESTING" = "Pest" ]; then
        (
            cd "$project_dir"
            composer require pestphp/pest pestphp/pest-plugin-laravel --dev --prefer-offline --no-interaction 2>/dev/null || true
            ./vendor/bin/pest --init 2>/dev/null || php artisan pest:install --no-interaction 2>/dev/null || true
        )
    fi

    if [ "$HAS_INTERNET" = "true" ] && [ "$ENABLE_API" = "yes" ]; then
        echo "  [api] Setting up API routes..."
        (
            cd "$project_dir"
            composer require laravel/sanctum --prefer-offline --no-interaction 2>/dev/null || true
            php artisan install:api --no-interaction 2>/dev/null || true
        )
    fi

    if [ "$DB_CHOICE" != "None" ] && [ "$HAS_INTERNET" = "true" ]; then
        echo "  [db] Running initial migrations..."
        (cd "$project_dir" && php artisan migrate --force 2>/dev/null) || echo -e "  ${YELLOW}[notice] Database migration skipped or failed.${NC}"
    fi

    echo "  [build] Compiling frontend assets..."
    (
        cd "$project_dir"

        if [ "$HAS_INTERNET" = "false" ]; then
            echo "  [offline] Preparing frontend build..."

            find resources \
                -type f \
                \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) \
                -exec sed -i 's|@import url(.*fonts\.bunny\.net.*);||g; s|@import '\''@fontsource-variable/figtree'\'';||g; s|@import "@fontsource-variable/figtree";||g' {} + \
                2>/dev/null || true

            find resources \
                -type f \
                \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) \
                -exec sed -i '/fonts\.bunny\.net/d' {} + \
                2>/dev/null || true

            if [ ! -d "node_modules" ]; then
                echo "  [offline] Installing dependencies from pnpm cache..."
                pnpm install --offline --frozen-lockfile
            fi
        else
            echo "  [online] Installing frontend dependencies..."
            pnpm install --prefer-offline --no-interactive
        fi

        if pnpm run build; then
            echo "  [ok] Frontend assets built successfully."
        else
            echo -e "${RED}[error] Frontend build failed.${NC}"
            exit 1
        fi
    )
    echo "[ok] Laravel project initialized successfully."
fi

if [ "$TEMPLATE" != "laravel" ]; then
    if [ -f "$project_dir/.env.example" ] && [ ! -f "$project_dir/.env" ]; then
        cp "$project_dir/.env.example" "$project_dir/.env"
    fi

    if [ -f "$project_dir/package.json" ]; then
        echo "  [build] Preparing frontend project..."
        (
            cd "$project_dir"

            if [ "$TEMPLATE" = "next-js" ] && [ "$HAS_INTERNET" = "false" ]; then
                echo "  [offline] Preparing Next.js layout for offline build..."
                LAYOUT_FILE=""
                if [ -f "src/app/layout.tsx" ]; then
                    LAYOUT_FILE="src/app/layout.tsx"
                elif [ -f "app/layout.tsx" ]; then
                    LAYOUT_FILE="app/layout.tsx"
                fi

                if [ -n "$LAYOUT_FILE" ]; then
                    sed -i '/from "next\/font\/google"/d; /from '\''next\/font\/google'\''/d' "$LAYOUT_FILE"
                    sed -i '/const .* = Geist({/,/\});/d' "$LAYOUT_FILE"
                    sed -i '/const .* = Geist_Mono({/,/\});/d' "$LAYOUT_FILE"
                    sed -i 's/\${.*\.variable}//g' "$LAYOUT_FILE"
                    sed -i 's/geistSans\.variable//g' "$LAYOUT_FILE"
                    sed -i 's/geistMono\.variable//g' "$LAYOUT_FILE"
                fi
            fi

            if [ ! -d "node_modules" ]; then
                if [ "$HAS_INTERNET" = "false" ]; then
                    pnpm install --offline --frozen-lockfile
                else
                    pnpm install --prefer-offline --no-interactive
                fi
            fi

            if grep -q "\"build\"" package.json; then
                if pnpm run build; then
                    echo "  [ok] Frontend assets built successfully."
                else
                    echo -e "${RED}[error] Frontend build failed.${NC}"
                    exit 1
                fi
            fi
        )
    fi
fi

# ── Step 4: Start runtime dependencies for the created project ─────────────
if [ -f "$SCRIPT_DIR/setup-deps.sh" ]; then
    echo ""
    echo "[setup] Ensuring runtime dependencies for $TEMPLATE are started..."
    if ! bash "$SCRIPT_DIR/setup-deps.sh" "$project_dir" "$TEMPLATE"; then
        echo -e "${YELLOW}[warn] setup-deps did not complete successfully for $TEMPLATE. Run './scripts/setup-deps.sh \"$project_dir\" \"$TEMPLATE\"' manually if needed.${NC}"
    fi
fi

# ── Step 5: Final Message ────────────────────────────────────
echo ""
echo "========================================="
echo -e "${GREEN}  Project ready: $PROJECT_NAME${NC}"
echo "========================================="
echo ""
echo "  cd $project_dir"
echo ""
case "$TEMPLATE" in
    laravel)       echo "  serve" ;;
    next-js|react) echo "  pnpm dev" ;;
    python)        echo "  source venv/bin/activate && python main.py" ;;
esac
echo ""
