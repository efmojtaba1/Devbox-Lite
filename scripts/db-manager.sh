#!/bin/bash

set -euo pipefail

NETWORK="devbox-network"
DOCKER_TIMEOUT=30

# ── Wait for Docker daemon to be ready ──────────────────
# On target systems after reboot, the Docker daemon inside WSL
# may not be running yet. Without this guard, docker commands
# hang indefinitely instead of failing cleanly.
wait_for_docker() {
    local max_attempts=$((DOCKER_TIMEOUT / 2))
    local attempt=1

    if timeout "$DOCKER_TIMEOUT" docker info >/dev/null 2>&1; then
        return 0
    fi

    echo "  [wait] Docker daemon not ready (attempt $attempt/$max_attempts)..."

    while [ "$attempt" -lt "$max_attempts" ]; do
        sleep 2
        attempt=$((attempt + 1))

        if timeout "$DOCKER_TIMEOUT" docker info >/dev/null 2>&1; then
            echo "  [ok] Docker daemon is ready."
            return 0
        fi

        echo "  [retry] Waiting for Docker daemon (attempt $attempt/$max_attempts)..."
    done

    echo -e "${RED}[error] Docker daemon not ready after ${DOCKER_TIMEOUT}s.${NC}"
    echo "  Start Docker Desktop or the Docker service inside WSL and retry."
    return 1
}

# Run a docker command with a timeout so it doesn't hang forever
# when the daemon is unresponsive.
docker_timeout() {
    timeout "$DOCKER_TIMEOUT" docker "$@"
}

# Ensure the network exists
ensure_network() {
    if ! docker network inspect "$NETWORK" > /dev/null 2>&1; then
        echo "Creating network '$NETWORK'..."
        if ! docker_timeout network create "$NETWORK" > /dev/null 2>&1; then
            echo -e "${RED}[error] Failed to create network '$NETWORK'.${NC}"
            return 1
        fi
    fi
}

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Database Commands:"
    echo "  create   <db>  - Pull image, create and start container"
    echo "  start    <db>  - Start existing container"
    echo "  stop     <db>  - Stop running container"
    echo "  connect  <db>  - Connect to database (interactive shell)"
    echo "  repair   mysql - Repair legacy MySQL authentication without deleting data"
    echo ""
    echo "GUI Tools (run directly):"
    echo "  phpmyadmin     - Start phpMyAdmin (MySQL/MariaDB)"
    echo "  adminer        - Start Adminer (multi-DB)"
    echo "  pgadmin        - Start pgAdmin (PostgreSQL)"
    echo ""
    echo "Databases: mysql, postgres, redis, mongo, mariadb, memcached"
    exit 1
}

# Prebuilt images directory (Compatible with both WSL2 and Windows/Docker Desktop)
# Priority order: container mount first, then WSL, then script-relative
if [ -d "/prebuilt/images" ]; then
    PREBUILT_DIR="${PREBUILT_DIR:-/prebuilt/images}"
elif [ -d "/workspace/prebuilt/images" ]; then
    PREBUILT_DIR="${PREBUILT_DIR:-/workspace/prebuilt/images}"
elif [ -d "$(pwd)/prebuilt/images" ]; then
    PREBUILT_DIR="${PREBUILT_DIR:-$(pwd)/prebuilt/images}"
else
    # Fallback to absolute relative path from script location
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PREBUILT_DIR="${PREBUILT_DIR:-$SCRIPT_DIR/../prebuilt/images}"
fi

# Map image name to prebuilt tar filename
image_to_tar() {
    local image="$1"
    # Strip :latest tag (it's the default, prebuilt files don't include it)
    image="${image%:latest}"
    # Strip namespace for namespaced images: dpage/pgadmin4 → pgadmin4
    image="${image##*/}"
    # Remaining tag becomes part of filename: mysql:8.4 → mysql-8.4.tar
    echo "${image//:/-}.tar"
}

# Check if image exists locally, if not try prebuilt, then pull
ensure_image() {
    local image="$1"
    if docker_timeout image inspect "$image" > /dev/null 2>&1; then
        return 0
    fi

    # Try loading from prebuilt images
    local tarfile
    tarfile=$(image_to_tar "$image")
    if [ -f "$PREBUILT_DIR/$tarfile" ]; then
        echo "Loading '$image' from prebuilt images..."
        if docker_timeout load -i "$PREBUILT_DIR/$tarfile" 2>/dev/null; then
            echo "Image loaded from prebuilt cache"
            return 0
        fi
    fi

    echo "Image '$image' not found locally. Trying to pull..."
    if docker_timeout pull "$image" 2>/dev/null; then
        echo "Image pulled successfully"
        return 0
    else
        echo "==========================================="
        echo "ERROR: Cannot pull image '$image'"
        echo "You are likely offline."
        echo ""
        echo "To fix this:"
        echo "1. Connect to the internet"
        echo "2. Run: docker pull $image"
        echo "3. Or place $tarfile in $PREBUILT_DIR/"
        echo "==========================================="
        return 1
    fi
}

# Database creation functions
create_mysql() {
    ensure_image mysql:8.4 || return 1
    docker_timeout volume create devbox-mysql-data >/dev/null 2>&1 || true

    if docker_timeout ps -a --format '{{.Names}}' | grep -q '^devbox-mysql$'; then
        echo "MySQL container already exists."
        return 0
    fi

    echo "Starting MySQL..."
    if ! docker_timeout run -d \
        --name devbox-mysql \
        --network "$NETWORK" \
        -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
        -v devbox-mysql-data:/var/lib/mysql \
        -p 3306:3306 \
        mysql:8.4 >/dev/null; then
        echo -e "${RED}[error] Failed to start MySQL.${NC}"
        return 1
    fi

    echo "MySQL container created on port 3306."

    local attempt=1
    local max_attempts=30
    while [ "$attempt" -le "$max_attempts" ]; do
        if docker_timeout exec devbox-mysql mysql -u root -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        if [ "$attempt" -eq "$max_attempts" ]; then
            echo -e "${RED}[error] MySQL started, but root authentication is unavailable.${NC}"
            echo "  No database data was deleted automatically."
            return 1
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    if ! docker_timeout exec devbox-mysql mysql -u root -e \
        "DROP USER IF EXISTS 'devbox'@'%';
         CREATE USER 'devbox'@'%' IDENTIFIED BY 'devbox_pass';
         GRANT ALL PRIVILEGES ON *.* TO 'devbox'@'%';
         FLUSH PRIVILEGES;" >/dev/null 2>&1; then
        echo -e "${RED}[error] MySQL is running, but the DevBox application user could not be created.${NC}"
        return 1
    fi

    echo "MySQL initialized: application user devbox/devbox_pass"
}

# Repair a legacy MySQL data volume without deleting its data.
repair_mysql() {
    local name="devbox-mysql"
    local repair_name="devbox-mysql-auth-repair"
    local repair_volume="devbox-mysql-data"

    ensure_image mysql:8.4 || return 1

    if ! docker_timeout volume inspect "$repair_volume" >/dev/null 2>&1; then
        echo -e "${RED}[error] MySQL data volume '$repair_volume' does not exist.${NC}"
        return 1
    fi

    docker_timeout rm -f "$repair_name" >/dev/null 2>&1 || true

    if docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "  [repair] Stopping existing MySQL container..."
        docker_timeout stop "$name" >/dev/null || return 1
    fi

    echo "  [repair] Starting temporary MySQL auth-repair container..."
    if ! docker_timeout run -d \
        --name "$repair_name" \
        --network "$NETWORK" \
        -v "$repair_volume:/var/lib/mysql" \
        mysql:8.4 \
        mysqld --skip-grant-tables --skip-networking=0 --bind-address=127.0.0.1 >/dev/null; then
        echo -e "${RED}[error] Could not start the temporary MySQL repair container.${NC}"
        docker_timeout start "$name" >/dev/null 2>&1 || true
        return 1
    fi

    local attempt=1
    local max_attempts=30
    while [ "$attempt" -le "$max_attempts" ]; do
        if docker_timeout exec "$repair_name" mysql --protocol=socket -u root -e "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        if [ "$attempt" -eq "$max_attempts" ]; then
            echo -e "${RED}[error] Temporary MySQL repair server did not become ready.${NC}"
            docker_timeout logs --tail 80 "$repair_name" 2>&1 || true
            docker_timeout rm -f "$repair_name" >/dev/null 2>&1 || true
            docker_timeout start "$name" >/dev/null 2>&1 || true
            return 1
        fi
        sleep 1
        attempt=$((attempt + 1))
    done

    echo "  [repair] Restoring DevBox application credentials..."
    local sql
    sql="FLUSH PRIVILEGES;
DROP USER IF EXISTS 'devbox'@'%';
CREATE USER 'devbox'@'%' IDENTIFIED BY 'devbox_pass';
GRANT ALL PRIVILEGES ON *.* TO 'devbox'@'%';
FLUSH PRIVILEGES;"

    if ! docker_timeout exec "$repair_name" mysql --protocol=socket -u root -e "$sql" >/dev/null 2>&1; then
        echo -e "${RED}[error] Could not restore MySQL application credentials.${NC}"
        docker_timeout logs --tail 80 "$repair_name" 2>&1 || true
        docker_timeout rm -f "$repair_name" >/dev/null 2>&1 || true
        docker_timeout start "$name" >/dev/null 2>&1 || true
        return 1
    fi

    docker_timeout rm -f "$repair_name" >/dev/null 2>&1 || true

    echo "  [repair] Starting MySQL with the existing data volume..."
    if ! docker_timeout start "$name" >/dev/null; then
        echo -e "${RED}[error] MySQL could not be restarted after authentication repair.${NC}"
        return 1
    fi

    echo "  [ok] Legacy MySQL authentication repaired; existing data preserved."
    return 0
}

create_postgres() {
    ensure_image postgres:17 || return 1
    docker_timeout volume create devbox-postgres-data 2>/dev/null || true
    echo "Starting PostgreSQL..."
    if ! docker_timeout run -d \
        --name devbox-postgres \
        --network "$NETWORK" \
        -e POSTGRES_HOST_AUTH_METHOD=trust \
        -v devbox-postgres-data:/var/lib/postgresql/data \
        -p 5433:5432 \
        postgres:17; then
        echo -e "${RED}[error] Failed to start PostgreSQL.${NC}"
        return 1
    fi
    echo "PostgreSQL container created on port 5433."

    local attempt=1
    local max_attempts=30
    while [ "$attempt" -le "$max_attempts" ]; do
        if docker_timeout exec devbox-postgres psql -U postgres -d postgres -c "SELECT 1" >/dev/null 2>&1; then
            break
        fi
        if [ "$attempt" -eq "$max_attempts" ]; then
            echo -e "${RED}[error] PostgreSQL started, but the server did not become queryable.${NC}"
            return 1
        fi
        sleep 2
        attempt=$((attempt + 1))
    done

    if ! docker_timeout exec devbox-postgres psql -U postgres -d postgres -v ON_ERROR_STOP=1 -c \
        "DO \\$\$
         BEGIN
           IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'devbox') THEN
             ALTER ROLE devbox WITH LOGIN PASSWORD 'devbox_pass' SUPERUSER;
           ELSE
             CREATE ROLE devbox LOGIN PASSWORD 'devbox_pass' SUPERUSER;
           END IF;
         END
         \\$\$;" >/dev/null 2>&1; then
        echo -e "${RED}[error] PostgreSQL is running, but the DevBox application user could not be created.${NC}"
        return 1
    fi

    echo "PostgreSQL initialized: application user devbox/devbox_pass"
}

create_redis() {
    ensure_image redis:7 || return 1
    docker_timeout volume create devbox-redis-data 2>/dev/null || true
    echo "Starting Redis..."
    if ! docker_timeout run -d \
        --name devbox-redis \
        --network "$NETWORK" \
        -v devbox-redis-data:/data \
        -p 6380:6379 \
        redis:7; then
        echo -e "${RED}[error] Failed to start Redis.${NC}"
        return 1
    fi
    echo "Redis ready on port 6380 (no auth)"
}

create_mongo() {
    ensure_image mongo:7 || return 1
    docker_timeout volume create devbox-mongo-data 2>/dev/null || true
    echo "Starting MongoDB..."
    if ! docker_timeout run -d \
        --name devbox-mongo \
        --network "$NETWORK" \
        -v devbox-mongo-data:/data/db \
        -p 27017:27017 \
        mongo:7; then
        echo -e "${RED}[error] Failed to start MongoDB.${NC}"
        return 1
    fi
    echo "MongoDB ready on port 27017 (no auth)"
}

create_mariadb() {
    ensure_image mariadb:11 || return 1
    docker_timeout volume create devbox-mariadb-data 2>/dev/null || true
    echo "Starting MariaDB..."
    if ! docker_timeout run -d \
        --name devbox-mariadb \
        --network "$NETWORK" \
        -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=yes \
        -v devbox-mariadb-data:/var/lib/mysql \
        -p 3308:3306 \
        mariadb:11; then
        echo -e "${RED}[error] Failed to start MariaDB.${NC}"
        return 1
    fi
    echo "MariaDB ready on port 3308 (no auth)"
}

create_memcached() {
    ensure_image memcached:1 || return 1
    docker_timeout volume create devbox-memcached-data 2>/dev/null || true
    echo "Starting Memcached..."
    if ! docker_timeout run -d \
        --name devbox-memcached \
        --network "$NETWORK" \
        -p 11211:11211 \
        memcached:1; then
        echo -e "${RED}[error] Failed to start Memcached.${NC}"
        return 1
    fi
    echo "Memcached ready on port 11211 (no auth)"
}

# Start/Stop functions
start_db() {
    local db="$1"
    local name="devbox-${db}"
    if docker_timeout ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Starting ${db}..."
        if ! docker_timeout start "$name"; then
            echo -e "${RED}[error] Failed to start ${db}.${NC}"
            return 1
        fi
        echo "${db} is running"
    else
        echo "Container '${name}' not found. Run: $0 create ${db}"
        exit 1
    fi
}

stop_db() {
    local db="$1"
    local name="devbox-${db}"
    if docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Stopping ${db}..."
        if ! docker_timeout stop "$name"; then
            echo -e "${RED}[error] Failed to stop ${db}.${NC}"
            return 1
        fi
        echo "${db} stopped"
    else
        echo "Container '${name}' is not running"
    fi
}

# Connect functions
connect_mysql() {
    local name="devbox-mysql"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MySQL is not running. Start it first: $0 start mysql"
        exit 1
    fi
    echo "Connecting to MySQL as devbox..."
    docker exec -it "$name" mysql -u devbox -pdevbox_pass
}

connect_postgres() {
    local name="devbox-postgres"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "PostgreSQL is not running. Start it first: $0 start postgres"
        exit 1
    fi
    echo "Connecting to PostgreSQL..."
    docker exec -it "$name" psql -U postgres
}

connect_redis() {
    local name="devbox-redis"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Redis is not running. Start it first: $0 start redis"
        exit 1
    fi
    echo "Connecting to Redis..."
    docker exec -it "$name" redis-cli
}

connect_mongo() {
    local name="devbox-mongo"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MongoDB is not running. Start it first: $0 start mongo"
        exit 1
    fi
    echo "Connecting to MongoDB..."
    docker exec -it "$name" mongosh
}

connect_mariadb() {
    local name="devbox-mariadb"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MariaDB is not running. Start it first: $0 start mariadb"
        exit 1
    fi
    echo "Connecting to MariaDB..."
    docker exec -it "$name" mariadb
}

connect_memcached() {
    local name="devbox-memcached"
    if ! docker_timeout ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Memcached is not running. Start it first: $0 start memcached"
        exit 1
    fi
    echo "Memcached is a key-value store. Use telnet or a client library to connect."
    echo "Container: $name | Port: 11211"
}

# GUI tool functions
gui_phpmyadmin() {
    ensure_image phpmyadmin:latest || return 1
    echo "Starting phpMyAdmin..."
    if ! docker_timeout run -d \
        --name devbox-phpmyadmin \
        --network "$NETWORK" \
        -e PMA_HOST=devbox-mysql \
        -e PMA_PORT=3306 \
        -p 8081:80 \
        phpmyadmin:latest; then
        echo -e "${RED}[error] Failed to start phpMyAdmin.${NC}"
        return 1
    fi
    echo "phpMyAdmin ready at http://localhost:8081"
}

gui_adminer() {
    ensure_image adminer:latest || return 1
    echo "Starting Adminer..."
    if ! docker_timeout run -d \
        --name devbox-adminer \
        --network "$NETWORK" \
        -p 8082:8080 \
        adminer:latest; then
        echo -e "${RED}[error] Failed to start Adminer.${NC}"
        return 1
    fi
    echo "Adminer ready at http://localhost:8082"
}

gui_pgadmin() {
    ensure_image dpage/pgadmin4:latest || return 1
    echo "Starting pgAdmin..."
    if ! docker_timeout run -d \
        --name devbox-pgadmin \
        --network "$NETWORK" \
        -e PGADMIN_DEFAULT_EMAIL=admin@admin.com \
        -e PGADMIN_DEFAULT_PASSWORD=admin \
        -p 8083:80 \
        dpage/pgadmin4:latest; then
        echo -e "${RED}[error] Failed to start pgAdmin.${NC}"
        return 1
    fi
    echo "pgAdmin ready at http://localhost:8083"
    echo "  Email: admin@admin.com"
    echo "  Password: admin"
}

# Validation
validate_db() {
    local db="$1"
    case "$db" in
        mysql|postgres|redis|mongo|mariadb|memcached) return 0 ;;
        *) echo "Error: Unknown database '$db'. Supported: mysql, postgres, redis, mongo, mariadb, memcached"; exit 1 ;;
    esac
}

validate_gui() {
    local tool="$1"
    case "$tool" in
        phpmyadmin|adminer|pgadmin) return 0 ;;
        *) echo "Error: Unknown GUI tool '$tool'. Supported: phpmyadmin, adminer, pgadmin"; exit 1 ;;
    esac
}

# Main
if ! wait_for_docker; then
    exit 1
fi
if ! ensure_network; then
    exit 1
fi

if [ $# -lt 1 ]; then
    usage
fi

COMMAND="$1"

case "$COMMAND" in
    create|start|stop|connect|repair)
        if [ $# -lt 2 ]; then
            echo "Error: '$COMMAND' requires a database name"
            usage
        fi
        DB="$2"
        validate_db "$DB"
        case "$COMMAND" in
            create) create_${DB} ;;
            start) start_db "$DB" ;;
            stop) stop_db "$DB" ;;
            connect) connect_${DB} ;;
            repair)
                [ "$DB" = "mysql" ] || { echo "Error: Only MySQL authentication repair is supported."; exit 1; }
                repair_mysql
                ;;
        esac
        ;;
    phpmyadmin) gui_phpmyadmin ;;
    adminer) gui_adminer ;;
    pgadmin) gui_pgadmin ;;
    *) echo "Error: Unknown command '$COMMAND'"; usage ;;
esac
