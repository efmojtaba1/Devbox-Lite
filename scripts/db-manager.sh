#!/bin/bash

set -euo pipefail

NETWORK="devbox-network"

# Ensure the network exists
ensure_network() {
    if ! docker network inspect "$NETWORK" > /dev/null 2>&1; then
        echo "Creating network '$NETWORK'..."
        docker network create "$NETWORK" > /dev/null 2>&1
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
    echo ""
    echo "GUI Tools (run directly):"
    echo "  phpmyadmin     - Start phpMyAdmin (MySQL/MariaDB)"
    echo "  adminer        - Start Adminer (multi-DB)"
    echo "  pgadmin        - Start pgAdmin (PostgreSQL)"
    echo ""
    echo "Databases: mysql, postgres, redis, mongo, mariadb, memcached"
    exit 1
}

# Prebuilt images directory (mounted from host)
PREBUILT_DIR="${PREBUILT_DIR:-/workspace/prebuilt/images}"

# Map image name to prebuilt tar filename
image_to_tar() {
    local image="$1"
    # Strip tag for filename: mysql:8.4 → mysql-8.4.tar
    echo "${image//:/-}.tar"
}

# Check if image exists locally, if not try prebuilt, then pull
ensure_image() {
    local image="$1"
    if docker image inspect "$image" > /dev/null 2>&1; then
        return 0
    fi

    # Try loading from prebuilt images
    local tarfile
    tarfile=$(image_to_tar "$image")
    if [ -f "$PREBUILT_DIR/$tarfile" ]; then
        echo "Loading '$image' from prebuilt images..."
        if docker load -i "$PREBUILT_DIR/$tarfile" 2>/dev/null; then
            echo "Image loaded from prebuilt cache"
            return 0
        fi
    fi

    echo "Image '$image' not found locally. Trying to pull..."
    if docker pull "$image" 2>/dev/null; then
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
    docker volume create devbox-mysql-data 2>/dev/null || true
    echo "Starting MySQL..."
    docker run -d \
        --name devbox-mysql \
        --network "$NETWORK" \
        -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
        -v devbox-mysql-data:/var/lib/mysql \
        -p 3307:3306 \
        mysql:8.4
    echo "MySQL ready on port 3307 (no auth)"
}

create_postgres() {
    ensure_image postgres:17 || return 1
    docker volume create devbox-postgres-data 2>/dev/null || true
    echo "Starting PostgreSQL..."
    docker run -d \
        --name devbox-postgres \
        --network "$NETWORK" \
        -e POSTGRES_HOST_AUTH_METHOD=trust \
        -v devbox-postgres-data:/var/lib/postgresql/data \
        -p 5433:5432 \
        postgres:17
    echo "PostgreSQL ready on port 5433 (no auth)"
}

create_redis() {
    ensure_image redis:7 || return 1
    docker volume create devbox-redis-data 2>/dev/null || true
    echo "Starting Redis..."
    docker run -d \
        --name devbox-redis \
        --network "$NETWORK" \
        -v devbox-redis-data:/data \
        -p 6380:6379 \
        redis:7
    echo "Redis ready on port 6380 (no auth)"
}

create_mongo() {
    ensure_image mongo:7 || return 1
    docker volume create devbox-mongo-data 2>/dev/null || true
    echo "Starting MongoDB..."
    docker run -d \
        --name devbox-mongo \
        --network "$NETWORK" \
        -v devbox-mongo-data:/data/db \
        -p 27017:27017 \
        mongo:7
    echo "MongoDB ready on port 27017 (no auth)"
}

create_mariadb() {
    ensure_image mariadb:11 || return 1
    docker volume create devbox-mariadb-data 2>/dev/null || true
    echo "Starting MariaDB..."
    docker run -d \
        --name devbox-mariadb \
        --network "$NETWORK" \
        -e MARIADB_ALLOW_EMPTY_ROOT_PASSWORD=yes \
        -v devbox-mariadb-data:/var/lib/mysql \
        -p 3308:3306 \
        mariadb:11
    echo "MariaDB ready on port 3308 (no auth)"
}

create_memcached() {
    ensure_image memcached:1 || return 1
    echo "Starting Memcached..."
    docker run -d \
        --name devbox-memcached \
        --network "$NETWORK" \
        -p 11211:11211 \
        memcached:1
    echo "Memcached ready on port 11211 (no auth)"
}

# Start/Stop functions
start_db() {
    local db="$1"
    local name="devbox-${db}"
    if docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Starting ${db}..."
        docker start "$name"
        echo "${db} is running"
    else
        echo "Container '${name}' not found. Run: $0 create ${db}"
        exit 1
    fi
}

stop_db() {
    local db="$1"
    local name="devbox-${db}"
    if docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Stopping ${db}..."
        docker stop "$name"
        echo "${db} stopped"
    else
        echo "Container '${name}' is not running"
    fi
}

# Connect functions
connect_mysql() {
    local name="devbox-mysql"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MySQL is not running. Start it first: $0 start mysql"
        exit 1
    fi
    echo "Connecting to MySQL..."
    docker exec -it "$name" mysql
}

connect_postgres() {
    local name="devbox-postgres"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "PostgreSQL is not running. Start it first: $0 start postgres"
        exit 1
    fi
    echo "Connecting to PostgreSQL..."
    docker exec -it "$name" psql -U postgres
}

connect_redis() {
    local name="devbox-redis"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Redis is not running. Start it first: $0 start redis"
        exit 1
    fi
    echo "Connecting to Redis..."
    docker exec -it "$name" redis-cli
}

connect_mongo() {
    local name="devbox-mongo"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MongoDB is not running. Start it first: $0 start mongo"
        exit 1
    fi
    echo "Connecting to MongoDB..."
    docker exec -it "$name" mongosh
}

connect_mariadb() {
    local name="devbox-mariadb"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "MariaDB is not running. Start it first: $0 start mariadb"
        exit 1
    fi
    echo "Connecting to MariaDB..."
    docker exec -it "$name" mariadb
}

connect_memcached() {
    local name="devbox-memcached"
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
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
    docker run -d \
        --name devbox-phpmyadmin \
        --network "$NETWORK" \
        -e PMA_HOST=devbox-mysql \
        -e PMA_PORT=3306 \
        -p 8081:80 \
        phpmyadmin:latest
    echo "phpMyAdmin ready at http://localhost:8081"
}

gui_adminer() {
    ensure_image adminer:latest || return 1
    echo "Starting Adminer..."
    docker run -d \
        --name devbox-adminer \
        --network "$NETWORK" \
        -p 8082:8080 \
        adminer:latest
    echo "Adminer ready at http://localhost:8082"
}

gui_pgadmin() {
    ensure_image dpage/pgadmin4:latest || return 1
    echo "Starting pgAdmin..."
    docker run -d \
        --name devbox-pgadmin \
        --network "$NETWORK" \
        -e PGADMIN_DEFAULT_EMAIL=admin@admin.com \
        -e PGADMIN_DEFAULT_PASSWORD=admin \
        -p 8083:80 \
        dpage/pgadmin4:latest
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
ensure_network

if [ $# -lt 1 ]; then
    usage
fi

COMMAND="$1"

case "$COMMAND" in
    create|start|stop|connect)
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
        esac
        ;;
    phpmyadmin) gui_phpmyadmin ;;
    adminer) gui_adminer ;;
    pgadmin) gui_pgadmin ;;
    *) echo "Error: Unknown command '$COMMAND'"; usage ;;
esac
