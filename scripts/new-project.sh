#!/usr/bin/env bash
set -euo pipefail

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

# ── Network Detection ───────────────────────────────────────
is_online() {
    curl -fsI --connect-timeout 3 https://repo.packagist.org >/dev/null 2>&1 \
        || curl -fsI --connect-timeout 3 https://registry.npmjs.org >/dev/null 2>&1
}

HAS_INTERNET=false
if is_online; then
    HAS_INTERNET=true
    echo -e "${GREEN}[network] Online mode detected.${NC}"
else
    echo -e "${YELLOW}[network] Offline mode detected.${NC}"
fi

# ── Helpers ──────────────────────────────────────────────────
ensure_container_running() {
    local name="$1"
    local kind="$2"

    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "  [skip] $kind is already running"
        return 0
    fi

    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
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
        echo -e "  ${YELLOW}[warn] db-manager.sh not available; cannot create $kind${NC}"
        return 1
    fi
}

run_pnpm_install() {
    local dir="$1"

    (
        cd "$dir"
        if [ "$HAS_INTERNET" = "true" ]; then
            pnpm install --prefer-offline --frozen-lockfile=false
        else
            pnpm install --offline --frozen-lockfile
        fi
    )
}

# Configure a fresh Laravel application's .env for DevBox runtime.
configure_laravel_database() {
    local project_dir="$1"
    local db_choice="$2"
    local project_name="$3"

    local db_name
    db_name="$(printf '%s' "$project_name" | sed 's/[^A-Za-z0-9_]/_/g')"
    [ -n "$db_name" ] || db_name="laravel"

    [ -f "$project_dir/.env" ] || return 0

    case "$db_choice" in
        MySQL)
            local mysql_host="devbox-mysql"
            getent hosts devbox-mysql >/dev/null 2>&1 || mysql_host="127.0.0.1"

            sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' "$project_dir/.env"
            sed -i "s|^DB_HOST=.*|DB_HOST=${mysql_host}|" "$project_dir/.env"
            sed -i "s|^# DB_HOST=.*|DB_HOST=${mysql_host}|" "$project_dir/.env"
            sed -i 's/^DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
            sed -i 's/^# DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
            sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${db_name}|" "$project_dir/.env"
            sed -i 's/^DB_USERNAME=.*/DB_USERNAME=devbox/' "$project_dir/.env"
            sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=devbox_pass/' "$project_dir/.env"

            mysql -h "$mysql_host" -u devbox -pdevbox_pass \
                -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\`;" 2>/dev/null || true
            ;;

        PostgreSQL)
            local pg_host="devbox-postgres"
            getent hosts devbox-postgres >/dev/null 2>&1 || pg_host="127.0.0.1"

            sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/' "$project_dir/.env"
            sed -i "s|^DB_HOST=.*|DB_HOST=${pg_host}|" "$project_dir/.env"
            sed -i "s|^# DB_HOST=.*|DB_HOST=${pg_host}|" "$project_dir/.env"
            sed -i 's/^DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
            sed -i 's/^# DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
            sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${db_name}|" "$project_dir/.env"
            sed -i 's/^DB_USERNAME=.*/DB_USERNAME=devbox/' "$project_dir/.env"
            sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=devbox_pass/' "$project_dir/.env"

            PGPASSWORD=devbox_pass psql -h "$pg_host" -U devbox \
                -tc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" 2>/dev/null \
                | grep -q 1 \
                || PGPASSWORD=devbox_pass psql -h "$pg_host" -U devbox \
                    -c "CREATE DATABASE \"${db_name}\";" 2>/dev/null || true
            ;;

        SQLite)
            sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' "$project_dir/.env"
            sed -i 's|^DB_DATABASE=.*|# DB_DATABASE=|' "$project_dir/.env"
            mkdir -p "$project_dir/database"
            touch "$project_dir/database/database.sqlite"
            ;;

        None)
            # Leave Laravel's existing database configuration untouched.
            ;;
    esac
}

# ── 1. Input Project Name ────────────────────────────────────
read -rp "Project name: " PROJECT_NAME

if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}[error] Project name cannot be empty.${NC}"
    exit 1
fi

if [[ ! "$PROJECT_NAME" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo -e "${RED}[error] Project name may contain only letters, numbers, dots, dashes, and underscores.${NC}"
    exit 1
fi

project_dir="$WORKSPACE/$PROJECT_NAME"

if [ -e "$project_dir" ]; then
    echo -e "${RED}[error] Path $project_dir already exists.${NC}"
    exit 1
fi

# ── 2. Select Framework ──────────────────────────────────────
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

# ── Defaults ─────────────────────────────────────────────────
STARTER_KIT="None"
LARAVEL_STARTER_FLAG=""
DB_CHOICE="SQLite"
LARAVEL_DATABASE_FLAG="--database=sqlite"
TESTING="Pest"
LARAVEL_TESTING_FLAG="--pest"
ENABLE_API="no"

TS_FLAG="--ts"
TW_FLAG="--tailwind"
AR_FLAG="--app"

if [ "$HAS_INTERNET" = "false" ]; then
    echo -e "\n${YELLOW}[notice] Network is offline. Interactive framework options are skipped.${NC}"
    echo -e "${YELLOW}         The cached baseline template will be used.${NC}"
else
    if [ "$TEMPLATE" = "laravel" ]; then
        echo ""
        echo "┌─ Laravel Options ─────────────────────┐"
        echo ""
        echo "Starter kit:"
        echo "  1) None (bare Laravel)"
        echo "  2) React"
        echo "  3) Vue"
        echo "  4) Svelte"
        echo "  5) Livewire"
        read -rp "  → Choose [1-5]: " SK_CHOICE

        case "$SK_CHOICE" in
            1)
                STARTER_KIT="None"
                LARAVEL_STARTER_FLAG=""
                ;;
            2)
                STARTER_KIT="React"
                LARAVEL_STARTER_FLAG="--react"
                ;;
            3)
                STARTER_KIT="Vue"
                LARAVEL_STARTER_FLAG="--vue"
                ;;
            4)
                STARTER_KIT="Svelte"
                LARAVEL_STARTER_FLAG="--svelte"
                ;;
            5)
                STARTER_KIT="Livewire"
                LARAVEL_STARTER_FLAG="--livewire"
                ;;
            *)
                STARTER_KIT="None"
                LARAVEL_STARTER_FLAG=""
                ;;
        esac

        echo ""
        echo "Database:"
        echo "  1) SQLite (recommended for dev)"
        echo "  2) MySQL"
        echo "  3) PostgreSQL"
        echo "  4) None"
        read -rp "  → Choose [1-4]: " DB_SEL

        case "$DB_SEL" in
            1)
                DB_CHOICE="SQLite"
                LARAVEL_DATABASE_FLAG="--database=sqlite"
                ;;
            2)
                DB_CHOICE="MySQL"
                LARAVEL_DATABASE_FLAG="--database=sqlite"
                ;;
            3)
                DB_CHOICE="PostgreSQL"
                LARAVEL_DATABASE_FLAG="--database=sqlite"
                ;;
            4)
                DB_CHOICE="None"
                LARAVEL_DATABASE_FLAG="--database=sqlite"
                ;;
            *)
                DB_CHOICE="SQLite"
                LARAVEL_DATABASE_FLAG="--database=sqlite"
                ;;
        esac

        echo ""
        echo "Testing:"
        echo "  1) Pest (recommended)"
        echo "  2) PHPUnit"
        read -rp "  → Choose [1-2]: " TEST_SEL

        case "$TEST_SEL" in
            1)
                TESTING="Pest"
                LARAVEL_TESTING_FLAG="--pest"
                ;;
            2)
                TESTING="PHPUnit"
                LARAVEL_TESTING_FLAG="--phpunit"
                ;;
            *)
                TESTING="Pest"
                LARAVEL_TESTING_FLAG="--pest"
                ;;
        esac

        echo ""
        echo "Theme:"
        echo "  Official Laravel Starter Kits include built-in light/dark mode."

        echo ""
        read -rp "  API routes? [y/N]: " API_INPUT
        if [[ "$API_INPUT" =~ ^[Yy]$ ]]; then
            ENABLE_API="yes"
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
    if [ "$STARTER_KIT" != "None" ]; then
        echo "  Theme:    built-in light/dark"
    fi
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

# ── Git Ownership ────────────────────────────────────────────
git config --global --add safe.directory "$project_dir" 2>/dev/null || true
git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true
git config --global --add safe.directory '*' 2>/dev/null || true

# ── Step 1: Create/Copy Project ──────────────────────────────
example_dir="$EXAMPLE_DATA/$TEMPLATE"

if [ "$HAS_INTERNET" = "false" ]; then
    if [ ! -d "$example_dir" ]; then
        echo -e "${RED}[error] Offline baseline template not found: $example_dir${NC}"
        exit 1
    fi

    echo "[source] Using cached baseline template ($example_dir)..."
    mkdir -p "$project_dir"

    (
        cd "$example_dir"
        tar --exclude='./.next' --exclude='./__pycache__' -cf - .
    ) | tar -C "$project_dir" -xf -

    echo "[ok] Baseline source copied successfully."
else
    case "$TEMPLATE" in
        laravel)
            echo -e "${CYAN}[source] Creating fresh Laravel project with the official Starter Kit installer...${NC}"

            # The official Laravel installer is responsible for scaffolding
            # React/Vue/Svelte/Livewire and their modern frontend stack.
            # We intentionally use --database=sqlite during the scaffold phase
            # so installer-time migrations never depend on DevBox's external DB.
            # The selected DevBox database is configured immediately afterward.
            laravel_args=(
                new
                "$project_dir"
                "$LARAVEL_DATABASE_FLAG"
                "$LARAVEL_TESTING_FLAG"
                "--no-node"
                "--no-interaction"
            )

            if [ -n "$LARAVEL_STARTER_FLAG" ]; then
                laravel_args+=("$LARAVEL_STARTER_FLAG")
            fi

            laravel "${laravel_args[@]}"
            ;;

        next-js)
            echo -e "${CYAN}[source] Creating fresh Next.js project...${NC}"
            pnpm create next-app "$project_dir" \
                "$TS_FLAG" "$TW_FLAG" --eslint "$AR_FLAG" \
                --src-dir --import-alias "@/*" --use-pnpm
            ;;

        react)
            echo -e "${CYAN}[source] Creating fresh React project...${NC}"
            pnpm create vite "$project_dir" --template react-ts
            ;;

        python)
            echo -e "${CYAN}[source] Creating Python project...${NC}"
            mkdir -p "$project_dir"
            python3 -m venv "$project_dir/venv"
            ;;
    esac
fi

# ── Step 2: Base Dependencies for Cached/Non-Laravel Projects ─
echo ""
echo "Installing dependencies..."

if [ -f "$project_dir/composer.json" ] && [ "$TEMPLATE" != "laravel" ] && [ ! -d "$project_dir/vendor" ]; then
    echo "[install] composer install..."
    if [ "$HAS_INTERNET" = "true" ]; then
        (cd "$project_dir" && composer install --prefer-offline --no-audit --no-interaction)
    else
        echo -e "${YELLOW}[offline] Skipping composer install. Network unavailable.${NC}"
    fi
fi

if [ -f "$project_dir/package.json" ] && [ "$TEMPLATE" != "laravel" ] && [ ! -d "$project_dir/node_modules" ]; then
    echo "[install] pnpm install..."
    if ! run_pnpm_install "$project_dir"; then
        echo -e "${RED}[error] pnpm install failed.${NC}"
        exit 1
    fi
fi

if [ "$TEMPLATE" = "python" ]; then
    if [ ! -d "$project_dir/venv" ]; then
        echo "[install] creating python venv..."
        python3 -m venv "$project_dir/venv"
    fi

    if [ -f "$project_dir/requirements.txt" ]; then
        echo "[install] pip install..."
        "$project_dir/venv/bin/pip" install --no-index --find-links=/root/.cache/pip -r "$project_dir/requirements.txt" 2>/dev/null \
            || "$project_dir/venv/bin/pip" install -r "$project_dir/requirements.txt" 2>/dev/null \
            || true
    fi
fi

# ── Step 3: Laravel Configuration ────────────────────────────
if [ "$TEMPLATE" = "laravel" ]; then
    echo ""
    echo "[configure] Applying Laravel options..."

    [ -f "$project_dir/.env" ] || [ ! -f "$project_dir/.env.example" ] || cp "$project_dir/.env.example" "$project_dir/.env"

    # Fresh Laravel projects created by the official installer already have
    # their Composer dependencies and starter-kit scaffold. Do not run a second
    # Composer install here; doing so only duplicates work and can alter the
    # installer-selected dependency graph.

    # ── Database / Redis Services ─────────────────────────────
    if [ "$DB_CHOICE" = "MySQL" ] || [ "$DB_CHOICE" = "PostgreSQL" ]; then
        echo "  [db] Ensuring database service is running..."

        if [ "$DB_CHOICE" = "MySQL" ]; then
            ensure_container_running devbox-mysql mysql
        else
            ensure_container_running devbox-postgres postgres
        fi

        if [ -f "$project_dir/.env" ] && grep -q '^REDIS_HOST=' "$project_dir/.env" 2>/dev/null; then
            echo "  [db] Ensuring Redis service is available..."
            ensure_container_running devbox-redis redis
        fi
    fi

    # ── Runtime .env Configuration ───────────────────────────
    configure_laravel_database "$project_dir" "$DB_CHOICE" "$PROJECT_NAME"

    if [ -f "$project_dir/.env" ]; then
        (cd "$project_dir" && php artisan key:generate --no-interaction)
    fi

    # ── API Routes ────────────────────────────────────────────
    if [ "$HAS_INTERNET" = "true" ] && [ "$ENABLE_API" = "yes" ]; then
        echo "  [api] Setting up API routes..."
        (
            cd "$project_dir"
            php artisan install:api --no-interaction
        )
    fi

    # ── Database Migrations ──────────────────────────────────
    if [ "$DB_CHOICE" != "None" ]; then
        echo "  [db] Running initial migrations..."
        (
            cd "$project_dir"
            php artisan migrate:fresh --force
        )

        echo "  [check] Verifying database schema..."
        (
            cd "$project_dir"
            php artisan migrate --force
        )
    fi

    # ── Frontend Dependencies / Build ─────────────────────────
    if [ -f "$project_dir/package.json" ]; then
        echo "  [build] Compiling frontend assets..."

        (
            cd "$project_dir"

            if [ "$HAS_INTERNET" = "false" ]; then
                echo "  [offline] Preparing frontend build..."

                # Cached offline projects may contain remote font imports.
                # Remove only those external font references; leave the starter
                # kit's Tailwind/Vite configuration untouched.
                if [ -d resources ]; then
                    find resources \
                        -type f \
                        \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) \
                        -exec sed -i \
                            's|@import url(.*fonts\.bunny\.net.*);||g; s|@import '\''@fontsource-variable/figtree'\'';||g; s|@import "@fontsource-variable/figtree";||g' \
                            {} + 2>/dev/null || true

                    find resources \
                        -type f \
                        \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) \
                        -exec sed -i '/fonts\.bunny\.net/d' {} + 2>/dev/null || true
                fi
            fi

            run_pnpm_install "$project_dir"

            if pnpm run build; then
                echo "  [ok] Frontend assets built successfully."
            else
                echo -e "${RED}[error] Frontend build failed.${NC}"
                exit 1
            fi
        )
    fi

    echo "[ok] Laravel project initialized successfully."
fi

# ── Step 4: Build Non-Laravel Frontends ───────────────────────
if [ "$TEMPLATE" != "laravel" ] && [ -f "$project_dir/package.json" ]; then
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
                sed -i '/const .* = Geist({/,/\);/d' "$LAYOUT_FILE"
                sed -i '/const .* = Geist_Mono({/,/\);/d' "$LAYOUT_FILE"
                sed -i 's/\${.*\.variable}//g' "$LAYOUT_FILE"
                sed -i 's/geistSans\.variable//g' "$LAYOUT_FILE"
                sed -i 's/geistMono\.variable//g' "$LAYOUT_FILE"
            fi
        fi

        if [ ! -d "node_modules" ]; then
            run_pnpm_install "$project_dir"
        fi

        if grep -q '"build"' package.json; then
            if pnpm run build; then
                echo "  [ok] Frontend assets built successfully."
            else
                echo -e "${RED}[error] Frontend build failed.${NC}"
                exit 1
            fi
        fi
    )
fi

# ── Step 5: Runtime Dependencies ─────────────────────────────
if [ -f "$SCRIPT_DIR/setup-deps.sh" ]; then
    echo ""
    echo "[setup] Ensuring runtime dependencies for $TEMPLATE are started..."
    if ! bash "$SCRIPT_DIR/setup-deps.sh" "$project_dir" "$TEMPLATE"; then
        echo -e "${YELLOW}[warn] setup-deps did not complete successfully for $TEMPLATE.${NC}"
    fi
fi

# ── Step 6: Final Message ────────────────────────────────────
echo ""
echo "========================================="
echo -e "${GREEN}  Project ready: $PROJECT_NAME${NC}"
echo "========================================="
echo ""
echo "  cd $project_dir"
echo ""

case "$TEMPLATE" in
    laravel)
        echo "  serve"
        ;;
    next-js|react)
        echo "  pnpm dev"
        ;;
    python)
        echo "  source venv/bin/activate && python main.py"
        ;;
esac

echo ""
