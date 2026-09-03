
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
    echo -e "${GREEN}[network] Online mode detected.${NC}"
else
    echo -e "${YELLOW}[network] Offline mode detected.${NC}"
fi

# ── Wait for Docker daemon to be ready ──────────────────
# On target systems after reboot, the Docker daemon inside WSL may
# not be running yet. Without this guard, docker commands hang
# indefinitely instead of failing cleanly.
wait_for_docker() {
    local max_attempts=30
    local attempt=1
    local command_timeout=5

    if timeout "$command_timeout" docker info >/dev/null 2>&1; then
        return 0
    fi

    echo "  [wait] Docker daemon not ready (attempt $attempt/$max_attempts)..."

    while [ "$attempt" -lt "$max_attempts" ]; do
        sleep 2
        attempt=$((attempt + 1))

        if timeout "$command_timeout" docker info >/dev/null 2>&1; then
            echo "  [ok] Docker daemon is ready."
            return 0
        fi

        echo "  [retry] Waiting for Docker daemon (attempt $attempt/$max_attempts)..."
    done

    echo -e "${RED}[error] Docker daemon not ready after $((max_attempts * 2))s.${NC}"
    echo "  Start Docker Desktop or the Docker service inside WSL and retry."
    return 1
}

docker_timeout() {
    timeout 30 docker "$@"
}

ensure_mysql_root() {
    if docker_timeout exec devbox-mysql mysql --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; then
        return 0
    fi

    echo "  [repair] Normalizing legacy MySQL root authentication..."
    if "$SCRIPT_DIR/db-manager.sh" repair mysql; then
        return 0
    fi

    echo -e "${RED}[error] Could not establish MySQL root access.${NC}"
    echo "  Existing MySQL data volume was preserved."
    return 1
}

# Wait for MySQL's TCP listener (port 3306) to actually accept connections.
# During first-time initialization MySQL 8.x runs a temporary socket-only
# server (started with --skip-networking) before the real server binds the
# TCP port. A socket-based readiness check can therefore pass while TCP still
# refuses connections. Laravel connects over TCP, so on a freshly created
# volume `php artisan migrate` fails with "[2002] Connection refused" unless
# we confirm the TCP port specifically.
# `mysqladmin ping` returns success whenever the server answers — even on an
# auth error — and fails only when the connection itself is refused, which is
# exactly the readiness signal we need here (independent of credentials).
wait_for_mysql_tcp() {
    local name="devbox-mysql"
    local max_attempts=30
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if docker_timeout exec "$name" \
            mysqladmin ping -h 127.0.0.1 -P 3306 --protocol=TCP -u root >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    return 1
}

ensure_postgres_credentials() {
    local name="devbox-postgres"

    if docker_timeout exec "$name" psql -U devbox -d postgres -c "SELECT 1" >/dev/null 2>&1; then
        return 0
    fi

    if docker_timeout exec "$name" psql -U postgres -d postgres -c "SELECT 1" >/dev/null 2>&1; then
        echo "  [repair] Creating/updating PostgreSQL application user..."
        if docker_timeout exec "$name" psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c \
            "DO \\$\$
            BEGIN
                IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'devbox') THEN
                    ALTER ROLE devbox WITH LOGIN PASSWORD 'devbox_pass' SUPERUSER;
                ELSE
                    CREATE ROLE devbox LOGIN PASSWORD 'devbox_pass' SUPERUSER;
                END IF;
            END
            \\$\$;" >/dev/null 2>&1; then
            echo "  [ok] PostgreSQL application credentials configured."
            return 0
        fi
    fi

    echo -e "${RED}[error] Could not establish DevBox PostgreSQL credentials.${NC}"
    return 1
}

ensure_container_running() {
    local name="$1"
    local kind="$2"

    if ! wait_for_docker; then
        echo -e "${RED}[error] Cannot proceed without Docker.${NC}"
        return 1
    fi

    local needs_credentials=0

    if docker_timeout ps --format '{{.Names}}' | grep -q "^$name$"; then
        echo "  [skip] $kind is already running"
    elif docker_timeout ps -a --format '{{.Names}}' | grep -q "^$name$"; then
        echo "  [start] $kind exists, starting..."
        if docker_timeout start "$name" >/dev/null 2>&1; then
            echo "  [ok] $kind started"
        else
            echo -e "${RED}[error] Failed to start existing $kind container.${NC}"
            return 1
        fi
        needs_credentials=1
    else
        echo "  [create] $kind not found, creating..."
        [ -x "$SCRIPT_DIR/db-manager.sh" ] || {
            echo -e "${RED}[error] db-manager.sh not available; cannot create $kind${NC}"
            return 1
        }
        if ! "$SCRIPT_DIR/db-manager.sh" create "$kind"; then
            echo -e "${RED}[error] Failed to create $kind container.${NC}"
            return 1
        fi
        needs_credentials=1
    fi

    if [ "$needs_credentials" -eq 1 ]; then
        case "$kind" in
            mysql) ensure_mysql_root || return 1 ;;
            postgres) ensure_postgres_credentials || return 1 ;;
        esac
    fi

    echo "  [wait] Waiting for $kind to become ready..."
    local max_attempts=30
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        case "$kind" in
            mysql)
                # Verify root via socket first (MySQL 8.x with caching_sha2_password
                # fails on TCP with empty password), then create devbox user if needed.
                if docker_timeout exec "$name" mysql --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; then
                    # Socket is up, but clients (Laravel) connect over TCP. On a
                    # freshly initialized volume the TCP listener lags the socket,
                    # so confirm port 3306 actually accepts connections before
                    # declaring readiness.
                    if wait_for_mysql_tcp; then
                        echo "  [ok] $kind is ready"
                    else
                        echo -e "${RED}[error] MySQL socket is ready but TCP port 3306 never opened.${NC}"
                        return 1
                    fi
                elif docker_timeout exec "$name" mysql -u devbox -pdevbox_pass -e "SELECT 1" >/dev/null 2>&1; then
                    echo "  [ok] $kind is ready"
                else
                    echo "  [warn] Neither root nor devbox auth succeeded; trying repair..."
                    if "$SCRIPT_DIR/db-manager.sh" repair mysql; then
                        echo "  [ok] $kind is ready after repair"
                    else
                        echo -e "${RED}[error] $kind did not become ready in $((max_attempts * 2))s.${NC}"
                        return 1
                    fi
                fi
                return 0
                ;;
            postgres)
                if docker_timeout exec "$name" psql -U postgres -d template1 -c "SELECT 1" >/dev/null 2>&1; then
                    echo "  [ok] $kind is ready"
                    return 0
                fi
                ;;
            redis)
                if docker_timeout exec "$name" redis-cli ping 2>/dev/null | grep -q '^PONG$'; then
                    echo "  [ok] $kind is ready"
                    return 0
                fi
                ;;
            *)
                if docker_timeout inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q '^true$'; then
                    echo "  [ok] $kind is running"
                    return 0
                fi
                ;;
        esac

        if ! docker_timeout inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q '^true$'; then
            echo -e "${RED}[error] $kind container stopped while waiting for readiness.${NC}"
            docker_timeout logs --tail 60 "$name" 2>&1 || true
            return 1
        fi

        if [ "$attempt" -lt "$max_attempts" ]; then
            sleep 2
            attempt=$((attempt + 1))
            echo "  [retry] Waiting for $kind (attempt $attempt/$max_attempts)"
        else
            break
        fi
    done

    echo -e "${RED}[error] $kind did not become ready in $((max_attempts * 2))s.${NC}"
    return 1
}

# ── 1. Input Project Name ───────────────────────────────────
read -rp "Project name: " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo -e "${RED}[error] Project name cannot be empty.${NC}"
    exit 1
fi

project_dir="$WORKSPACE/projects/$PROJECT_NAME"
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
ENABLE_API="no"

TS_FLAG="--ts"
TW_FLAG="--tailwind"
AR_FLAG="--app"

if [ "$HAS_INTERNET" = "false" ]; then
    echo -e "\n${YELLOW}[offline] Network unavailable. Using cached baseline configuration.${NC}"

    if [ "$TEMPLATE" = "laravel" ]; then
        STARTER_KIT="React"
        DB_CHOICE="MySQL"
        TESTING="Pest"
        ENABLE_API="yes"
    elif [ "$TEMPLATE" = "next-js" ]; then
        TS_FLAG="--ts"
        TW_FLAG="--tailwind"
        AR_FLAG="--app"
    fi
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
            1) STARTER_KIT="None" ;;
            2) STARTER_KIT="React" ;;
            3) STARTER_KIT="Vue" ;;
            4) STARTER_KIT="Svelte" ;;
            5) STARTER_KIT="Livewire" ;;
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

        echo ""
        echo "Theme:"
        echo "Official Laravel Starter Kits include built-in light/dark mode."

        read -rp "API routes? [y/N]: " API_INPUT
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
if [ "$TEMPLATE" = "laravel" ]; then
    echo "  Starter:  $STARTER_KIT"
    echo "  Database: $DB_CHOICE"
    echo "  Testing:  $TESTING"
    echo "  Theme:    built-in light/dark"
    echo "  API:      $ENABLE_API"
elif [ "$TEMPLATE" = "next-js" ]; then
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

# ── Fix Git Ownership ───────────────────────────────────────
git config --global --add safe.directory "$project_dir" 2>/dev/null || true
git config --global --add safe.directory "$WORKSPACE" 2>/dev/null || true
git config --global --add safe.directory '*' 2>/dev/null || true

# ── Helper: reset a project database ─────────────────────────
reset_mysql_database() {
    local db_name="$1"
    local host="$2"
    local sql
    sql=$(cat <<SQL_EOF
DROP DATABASE IF EXISTS \`$db_name\`;
CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL_EOF
    )

    echo "  [db] Resetting MySQL database '$db_name'..."

    if docker_timeout exec devbox-mysql mysql --protocol=socket -u root -e "$sql" >/dev/null 2>&1; then
        echo "  [ok] MySQL database '$db_name' reset."
        return 0
    fi

    # Fallback to TCP for the `devbox` user (created after startup).
    if docker_timeout exec devbox-mysql mysql -h 127.0.0.1 -u devbox -pdevbox_pass -e "$sql" >/dev/null 2>&1; then
        echo "  [ok] MySQL database '$db_name' reset via devbox user."
        return 0
    fi

    echo -e "${RED}[error] Cannot authenticate to MySQL as root.${NC}"
    echo "  No database changes were made."
    return 1
}

reset_postgres_database() {
    local db_name="$1"
    local host="$2"

    echo "  [db] Resetting PostgreSQL database '$db_name'..."

    if docker_timeout exec -i devbox-postgres \
        psql -U devbox -d postgres \
        -v ON_ERROR_STOP=1 \
        -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='${db_name}' AND pid <> pg_backend_pid();" >/dev/null 2>&1; then
        docker_timeout exec -i devbox-postgres \
            psql -U devbox -d postgres \
            -v ON_ERROR_STOP=1 \
            -c "DROP DATABASE IF EXISTS \"${db_name}\";" >/dev/null
        docker_timeout exec -i devbox-postgres \
            psql -U devbox -d postgres \
            -v ON_ERROR_STOP=1 \
            -c "CREATE DATABASE \"${db_name}\";" >/dev/null
        echo "  [ok] PostgreSQL database '$db_name' reset."
        return 0
    fi

    echo -e "${RED}[error] Cannot authenticate to PostgreSQL with DevBox credentials.${NC}"
    echo "  No database changes were made."
    return 1
}

# ── Step 1: Copy Source / Create Project ─────────────────────
example_dir="$EXAMPLE_DATA/$TEMPLATE"
IS_OFFLINE=false

if [ -d "$example_dir" ] && [ "$HAS_INTERNET" = "false" ]; then
    echo "[source] Using cached baseline template ($example_dir)..."
    mkdir -p "$project_dir"
    (
        cd "$example_dir"
        tar --exclude='./.next' --exclude='./__pycache__' -cf - .
    ) | tar -C "$project_dir" -xf -
    IS_OFFLINE=true
    echo "[ok] Baseline source copied successfully."
else
    echo -e "${CYAN}[source] Creating fresh project via online CLI tools...${NC}"

    if [ "$TEMPLATE" = "laravel" ]; then
        # The Laravel Installer owns the official Starter Kit scaffold.
        # It uses SQLite only for the initial scaffold/migration phase;
        # the selected DevBox database is configured afterwards and
        # migrated from a clean database.
        echo "  [laravel] Preparing official Starter Kit scaffold..."

        if [ "$DB_CHOICE" = "MySQL" ]; then
            ensure_container_running devbox-mysql mysql
        elif [ "$DB_CHOICE" = "PostgreSQL" ]; then
            ensure_container_running devbox-postgres postgres
        fi

        # Use a temporary sqlite database during installer bootstrap so
        # Laravel can complete its own initialization without requiring the
        # DevBox database credentials at that stage.
        LARAVEL_ARGS=("new" "$project_dir" "--database=sqlite" "--pnpm" "--no-interaction" "--no-boost")

        case "$STARTER_KIT" in
            React)    LARAVEL_ARGS+=("--react") ;;
            Vue)      LARAVEL_ARGS+=("--vue") ;;
            Svelte)   LARAVEL_ARGS+=("--svelte") ;;
            Livewire) LARAVEL_ARGS+=("--livewire") ;;
        esac

        if [ "$TESTING" = "Pest" ]; then
            LARAVEL_ARGS+=("--pest")
        else
            LARAVEL_ARGS+=("--phpunit")
        fi

        laravel "${LARAVEL_ARGS[@]}"
    else
        mkdir -p "$project_dir"
        case "$TEMPLATE" in
            next-js) pnpm create next-app "$project_dir" $TS_FLAG $TW_FLAG --eslint$AR_FLAG --src-dir --import-alias "@/*" --use-pnpm ;;
            react)
                        echo "  [react] Scaffolding Vite React project..."

                        (
                            cd "$WORKSPACE/projects"

                            npx --yes create-vite@latest "$PROJECT_NAME" \
                                --interactive \
                                --no-immediate \
                                --overwrite
                        )

                        echo "  [react] Configuring Vite for Docker access..."

                        cat > "$project_dir/vite.config.ts" <<'VITE_EOF'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
  },
})
VITE_EOF
                        ;;
            python)  python3 -m venv "$project_dir/venv" 2>/dev/null || true
                     if [ ! -f "$project_dir/app.py" ]; then
                         cat > "$project_dir/app.py" << 'EOF'
from fastapi import FastAPI
import uvicorn

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF
                     fi
                     if [ -d "$project_dir/venv" ]; then
                         . "$project_dir/venv/bin/activate"
                         pip install -q fastapi uvicorn flask 2>/dev/null || true
                         deactivate 2>/dev/null || true
                     fi
        esac
    fi
fi

# ── Step 2: Install Base Dependencies ────────────────────────
echo ""
echo "Installing dependencies..."

# Online Laravel Starter Kits install their dependencies/build during
# `laravel new`; do not run a second generic composer/pnpm install here.
if [ "$TEMPLATE" = "laravel" ] && [ "$HAS_INTERNET" = "true" ]; then
    :
else
    if [ -f "$project_dir/composer.json" ] && [ ! -d "$project_dir/vendor" ]; then
        echo "[install] composer install..."
        if [ "$HAS_INTERNET" = "true" ]; then
            (cd "$project_dir" && composer install --prefer-offline --no-audit --no-interaction)
        else
            echo -e "${YELLOW}[offline] Skipping composer install. Network unavailable.${NC}"
        fi
    fi

    if [ -f "$project_dir/package.json" ] && [ ! -d "$project_dir/node_modules" ]; then
        echo "[install] pnpm install..."
        if [ "$HAS_INTERNET" = "false" ]; then
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
                pnpm install --prefer-offline
            ) || {
                echo -e "${RED}[error] pnpm install failed.${NC}"
                exit 1
            }
        fi
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

    # Ensure runtime database services are available in both online and offline modes.
    if [ "$DB_CHOICE" = "MySQL" ]; then
        echo "  [db] Ensuring database service is running..."
        ensure_container_running devbox-mysql mysql
    elif [ "$DB_CHOICE" = "PostgreSQL" ]; then
        echo "  [db] Ensuring database service is running..."
        ensure_container_running devbox-postgres postgres
    fi

    if [ "$HAS_INTERNET" = "true" ]; then
        # Laravel's starter kits commonly use Redis. Keep the DevBox service
        # available when the generated project references it.
        if [ -f "$project_dir/.env" ] && grep -q '^REDIS_HOST=' "$project_dir/.env" 2>/dev/null; then
            echo "  [db] Ensuring Redis service is available..."
            ensure_container_running devbox-redis redis
        fi
    fi

    if [ -f "$project_dir/.env" ]; then
        case "$DB_CHOICE" in
            "MySQL")
                MYSQL_HOST="devbox-mysql"
                reset_mysql_database "$PROJECT_NAME" "$MYSQL_HOST"

                sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' "$project_dir/.env"
                sed -i "s/^DB_HOST=.*/DB_HOST=${MYSQL_HOST}/" "$project_dir/.env"
                sed -i "s/^# DB_HOST=.*/DB_HOST=${MYSQL_HOST}/" "$project_dir/.env"
                sed -i 's/^DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
                sed -i 's/^# DB_PORT=.*/DB_PORT=3306/' "$project_dir/.env"
                sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$project_dir/.env"
                sed -i "s/^DB_USERNAME=.*/DB_USERNAME=root/" "$project_dir/.env"
                sed -i "s/^# DB_USERNAME=.*/DB_USERNAME=root/" "$project_dir/.env"
                sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=/" "$project_dir/.env"
                sed -i "s/^# DB_PASSWORD=.*/DB_PASSWORD=/" "$project_dir/.env"
                ;;
            "PostgreSQL")
                PG_HOST="devbox-postgres"
                reset_postgres_database "$PROJECT_NAME" "$PG_HOST"

                sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/' "$project_dir/.env"
                sed -i "s/^DB_HOST=.*/DB_HOST=${PG_HOST}/" "$project_dir/.env"
                sed -i "s/^# DB_HOST=.*/DB_HOST=${PG_HOST}/" "$project_dir/.env"
                sed -i 's/^DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
                sed -i 's/^# DB_PORT=.*/DB_PORT=5432/' "$project_dir/.env"
                sed -i "s/^DB_DATABASE=.*/DB_DATABASE=${PROJECT_NAME}/" "$project_dir/.env"
                sed -i "s/^DB_USERNAME=.*/DB_USERNAME=root/" "$project_dir/.env"
                sed -i "s/^# DB_USERNAME=.*/DB_USERNAME=root/" "$project_dir/.env"
                sed -i "s/^DB_PASSWORD=.*/DB_PASSWORD=/" "$project_dir/.env"
                sed -i "s/^# DB_PASSWORD=.*/DB_PASSWORD=/" "$project_dir/.env"
                ;;
            "SQLite")
                sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=sqlite/' "$project_dir/.env"
                sed -i '/^DB_DATABASE=/d' "$project_dir/.env"
                mkdir -p "$project_dir/database"
                touch "$project_dir/database/database.sqlite"
                ;;
            "None")
                # Keep Laravel's default driver configuration intact, but do
                # not run any database lifecycle operation below.
                ;;
        esac
    fi

    if [ -f "$project_dir/.env" ]; then
        (cd "$project_dir" && php artisan key:generate --no-interaction)
    fi

    if [ "$HAS_INTERNET" = "true" ] && [ "$ENABLE_API" = "yes" ]; then
        echo "  [api] Setting up API routes..."
        (
            cd "$project_dir"
            php artisan install:api --no-interaction
        )
    fi

    if [ "$HAS_INTERNET" = "true" ] && [ "$DB_CHOICE" != "None" ]; then
        echo "  [db] Running final migrations on the selected DevBox database..."
        (
            cd "$project_dir"
            php artisan migrate:fresh --force
        )
    elif [ "$HAS_INTERNET" = "false" ]; then
        echo "  [check] Verifying database schema..."
        (
            cd "$project_dir"
            if grep -q '^DB_CONNECTION=sqlite' .env; then
                touch database/database.sqlite
            fi
            if [ "$DB_CHOICE" = "MySQL" ]; then
                sed -i 's/^DB_USERNAME=.*/DB_USERNAME=root/' .env
                sed -i 's/^# DB_USERNAME=.*/DB_USERNAME=root/' .env
                sed -i 's/^DB_PASSWORD=.*/DB_PASSWORD=/' .env
                sed -i 's/^# DB_PASSWORD=.*/DB_PASSWORD=/' .env
            fi
            if php artisan migrate --force; then
                echo "  [ok] Database migrations applied."
            else
                echo -e "${YELLOW}[warn] Database migration failed. Project was created; run 'php artisan migrate' manually after checking the database.${NC}"
            fi
        )
    fi

    # For online Laravel Starter Kits the installer already created the
    # official frontend stack and performed its initial dependency/build work.
    # We only run an explicit final build when a package script is present and
    # a build has not already been produced.
    if [ "$HAS_INTERNET" = "true" ]; then
        echo "  [build] Verifying frontend assets..."
        (
            cd "$project_dir"
            if [ -f package.json ] && grep -q '"build"' package.json; then
                if [ -d node_modules ]; then
                    if pnpm run build; then
                        echo "  [ok] Frontend assets built successfully."
                    else
                        echo -e "${RED}[error] Frontend build failed.${NC}"
                        exit 1
                    fi
                else
                    echo -e "${YELLOW}[warn] node_modules not present; relying on Laravel Installer output.${NC}"
                fi
            fi
        )
    elif [ "$HAS_INTERNET" = "false" ] && [ -f "$project_dir/package.json" ]; then
        echo "  [build] Preparing offline frontend assets..."
        (
            cd "$project_dir"
            if [ ! -d node_modules ]; then
                pnpm install --offline --frozen-lockfile
            fi
            if grep -q '"build"' package.json; then
                pnpm run build
            fi
        ) || {
            echo -e "${RED}[error] Offline frontend build failed.${NC}"
            exit 1
        }
    fi

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
                    pnpm install --prefer-offline
                fi
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
fi

# ── Step 4: Start runtime dependencies ───────────────────────
if [ -f "$SCRIPT_DIR/setup-deps.sh" ]; then
    echo ""
    echo "[setup] Ensuring runtime dependencies for $TEMPLATE are started..."
    if ! bash "$SCRIPT_DIR/setup-deps.sh" "$project_dir" "$TEMPLATE"; then
        echo -e "${YELLOW}[warn] setup-deps did not complete successfully for $TEMPLATE.${NC}"
    fi
fi

# ── Step 5: Final Message ────────────────────────────────────
# Extract just the project name for display (since user is already in /workspace)
PROJECT_DISPLAY="${project_dir##*/}"

echo ""
echo "========================================="
echo -e "${GREEN}  Project ready: $PROJECT_NAME${NC}"
echo "========================================="
echo ""
echo "  cd projects/$PROJECT_DISPLAY"
echo ""
case "$TEMPLATE" in
    laravel)       echo "  serve" ;;
    next-js|react) echo "  pnpm dev" ;;
    python)        echo "  py-dev" ;;
esac
echo ""