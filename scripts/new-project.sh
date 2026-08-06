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
HAS_INTERNET=true
# Use curl instead of ping for reliable network check in isolated environments
if ! curl -Is --connect-timeout 3 https://repo.packagist.org >/dev/null; then
    HAS_INTERNET=false
    echo -e "${YELLOW}[network] Offline mode detected. External downloads will be skipped.${NC}"
fi

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
fi

# ── Summary & Confirmation ──────────────────────────────────
echo ""
echo "── Summary ──"
echo "  Name:     $PROJECT_NAME"
echo "  Template: $TEMPLATE"
if [ "$TEMPLATE" = "laravel" ]; then
    echo "  Starter:  $STARTER_KIT"
    echo "  Database: $DB_CHOICE"
    echo "  Testing:  $TESTING"
    echo "  Dark:     $DARK_MODE"
    echo "  API:      $ENABLE_API"
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

# ── Step 1: Copy Source (Offline-First System) ──────────────
example_dir="$EXAMPLE_DATA/$TEMPLATE"
IS_OFFLINE=false

if [ -d "$example_dir" ]; then
    echo "[offline] Copying baseline from template ($example_dir)..."
    mkdir -p "$project_dir"
    shopt -s dotglob
    for item in "$example_dir"/*; do
        name=$(basename "$item")
        case "$name" in
            .next|__pycache__) continue ;;
        esac
        cp -a "$item" "$project_dir/" 2>/dev/null
    done
    shopt -u dotglob
    IS_OFFLINE=true
    echo "[ok] Offline source copied."
else
    echo -e "${YELLOW}[online] Template volume not found. Downloading via online fallback...${NC}"
    mkdir -p "$project_dir"
    case "$TEMPLATE" in
        laravel) composer create-project laravel/laravel "$project_dir" --prefer-dist --no-interaction ;;
        next-js) pnpm create next-app "$project_dir" --ts --tailwind --eslint --app --src-dir --import-alias "@/*" --use-pnpm ;;
        react)   pnpm create vite "$project_dir" --template react-ts ;;
        python)  python3 -m venv "$project_dir/venv" ;;
    esac
fi

# ── Fix Git Ownership ────────────────────────────────────────
git config --global --add safe.directory "$project_dir" 2>/dev/null || true
git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true

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
    (cd "$project_dir" && pnpm install --offline 2>/dev/null) || \
    (cd "$project_dir" && pnpm install --prefer-offline 2>/dev/null) || true
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

    # Auto-start/Create Databases
    if [ "$DB_CHOICE" = "MySQL" ] || [ "$DB_CHOICE" = "PostgreSQL" ]; then
        echo "  [db] Ensuring database service is running..."

        if [ "$DB_CHOICE" = "MySQL" ]; then
            if ! docker ps -a --format '{{.Names}}' | grep -q "^devbox-mysql$"; then
                echo "  [db] Container devbox-mysql not found. Creating it now..."
                "$SCRIPT_DIR/db-manager.sh" create mysql 2>/dev/null || true
                sleep 5
            elif ! docker ps --format '{{.Names}}' | grep -q "^devbox-mysql$"; then
                "$SCRIPT_DIR/db-manager.sh" start mysql 2>/dev/null || true
                sleep 4
            fi
        elif [ "$DB_CHOICE" = "PostgreSQL" ]; then
            if ! docker ps -a --format '{{.Names}}' | grep -q "^devbox-postgres$"; then
                echo "  [db] Container devbox-postgres not found. Creating it now..."
                "$SCRIPT_DIR/db-manager.sh" create postgres 2>/dev/null || true
                sleep 5
            elif ! docker ps --format '{{.Names}}' | grep -q "^devbox-postgres$"; then
                "$SCRIPT_DIR/db-manager.sh" start postgres 2>/dev/null || true
                sleep 4
            fi
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
                .*/DB_USERNAME=devbox/' "$project_dir/.env"
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
                sed -i 's/^DB_USERNAME=.*/DB_USERNAME=root/' "$project_dir/.env"
                sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=/' "$project_dir/.env"

                mysql -h "$MYSQL_HOST" -u root -e "CREATE DATABASE IF NOT EXISTS \`${PROJECT_NAME}\`;" 2>/dev/null || true
                PGPASSWORD=devbox_pass psql -h "$PG_HOST" -U devbox -c "CREATE DATABASE ${PROJECT_NAME};" 2>/dev/null || true
                ;;
            "SQLite")sed -i 's/^DB_USERNAME=
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

    if [ "$STARTER_KIT" != "None" ]; then
        echo "  [starter] Configuring $STARTER_KIT..."
        if [ "$HAS_INTERNET" = "false" ]; then
            echo -e "  ${YELLOW}[offline] Skipping $STARTER_KIT setup (No Internet).${NC}"
        else
            case "$STARTER_KIT" in
                "Breeze + Blade")
                    (
                        cd "$project_dir"
                        composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                        b_args="blade --no-interaction"
                        [ "$DARK_MODE" = "yes" ] && b_args="$b_args --dark"
                        php artisan breeze:install $b_args 2>/dev/null || true
                    )
                    ;;
                "Breeze + React")
                    (
                        cd "$project_dir"
                        composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                        b_args="react --no-interaction"
                        [ "$DARK_MODE" = "yes" ] && b_args="$b_args --dark"
                        php artisan breeze:install $b_args 2>/dev/null || true
                    )
                    ;;
                "Breeze + Vue")
                    (
                        cd "$project_dir"
                        composer require laravel/breeze --dev --prefer-offline --no-interaction 2>/dev/null || true
                        b_args="vue --no-interaction"
                        [ "$DARK_MODE" = "yes" ] && b_args="$b_args --dark"
                        php artisan breeze:install $b_args 2>/dev/null || true
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
    fi

if [ "$TESTING" = "Pest" ]; then
        (
            cd "$project_dir"
            if [ "$HAS_INTERNET" = "true" ]; then
                composer require pestphp/pest pestphp/pest-plugin-laravel --dev --prefer-offline --no-interaction 2>/dev/null || true
                ./vendor/bin/pest --init 2>/dev/null || php artisan pest:install --no-interaction 2>/dev/null || true
            else
                echo -e "  ${YELLOW}[offline] Skipping Pest setup (requires internet).${NC}"
            fi
        )
    fi

if [ "$ENABLE_API" = "yes" ]; then
        echo "  [api] Setting up API routes..."
        (
            cd "$project_dir"
            if [ "$HAS_INTERNET" = "true" ]; then
                composer require laravel/sanctum --prefer-offline --no-interaction 2>/dev/null || true
                php artisan install:api --no-interaction 2>/dev/null || true
            else
                echo -e "  ${YELLOW}[offline] Skipping API setup (requires internet).${NC}"
            fi
        )
    fi

    if [ ! -f "$project_dir/resources/js/bootstrap.js" ]; then
        cat << 'EOF' > "$project_dir/resources/js/bootstrap.js"
import axios from 'axios';
window.axios = axios;
window.axios.defaults.headers.common['X-Requested-With'] = 'XMLHttpRequest';
EOF
    fi

    if [ "$DB_CHOICE" != "None" ]; then
        echo "  [db] Running initial migrations..."
        (cd "$project_dir" && php artisan migrate --force 2>/dev/null) || echo -e "  ${YELLOW}[notice] Database migration skipped or failed.${NC}"
    fi

    echo "  [fix] Patching Tailwind v4 and PostCSS dependencies..."
    (
        cd "$project_dir"
        if [ "$HAS_INTERNET" = "true" ]; then
            pnpm add -D @tailwindcss/postcss --offline 2>/dev/null || true
        fi
        cat << 'EOF' > postcss.config.js
export default {
  plugins: {
    '@tailwindcss/postcss': {},
    autoprefixer: {},
  },
};
EOF
    )

    if [ -f "$project_dir/vite.config.js" ]; then
        node -e "
        const fs = require('fs');
        let content = fs.readFileSync('$project_dir/vite.config.js', 'utf8');
        if (!content.includes('0.0.0.0')) {
            const serverConfig = \"server: { host: '0.0.0.0', port: 5173, strictPort: true, hmr: { host: 'localhost' } },\n    \";
            if (content.includes('server:')) {
                content = content.replace(/server\s*:\s*\{[^}]*\}/, serverConfig.trim().slice(0, -1));
            } else {
                content = content.replace('plugins:', serverConfig + 'plugins:');
            }
            fs.writeFileSync('$project_dir/vite.config.js', content);
        }
        " 2>/dev/null || true
    fi

    echo "  [build] Compiling frontend assets..."
    (
        cd "$project_dir"

        if [ "$HAS_INTERNET" = "false" ]; then
            # حذف لینک‌های فونت برای جلوگیری از خطای تایم‌اوت Vite در بیلد آفلاین
            echo "  [offline] Disabling remote fonts to prevent Vite build timeout..."
            find resources -type f \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) -exec sed -i 's|@import url(.*fonts\.bunny\.net.*);||g' {} + 2>/dev/null || true
            find resources -type f \( -name "*.css" -o -name "*.blade.php" -o -name "*.jsx" -o -name "*.tsx" \) -exec sed -i '/fonts\.bunny\.net/d' {} + 2>/dev/null || true
        fi

        if [ "$HAS_INTERNET" = "true" ]; then
            pnpm install --offline 2>/dev/null || pnpm install --prefer-offline 2>/dev/null || true
        fi
        pnpm run build || true
    )

    echo "[ok] Laravel project initialized successfully."
fi

if [ "$TEMPLATE" != "laravel" ]; then
    if [ -f "$project_dir/.env.example" ] && [ ! -f "$project_dir/.env" ]; then
        cp "$project_dir/.env.example" "$project_dir/.env"
    fi
    if [ -f "$project_dir/package.json" ]; then
        echo "  [build] Compiling frontend assets..."
        (
            cd "$project_dir"
            if [ "$HAS_INTERNET" = "true" ]; then
                pnpm install --offline 2>/dev/null || pnpm install --prefer-offline 2>/dev/null || true
            fi
        )
    fi
fi

# ── Step 4: Final Message ────────────────────────────────────
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
