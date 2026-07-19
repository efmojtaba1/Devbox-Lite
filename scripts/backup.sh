#!/bin/bash
# DevBox Lite - Backup data

source "$(dirname "$0")/common.sh"

BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_NAME="devbox-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Check if a container is running
is_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$1$"
}

# =====================
# MySQL
# =====================
backup_mysql() {
    echo ""
    echo "Backing up MySQL..."

    if ! is_running "devbox-mysql"; then
        echo "  [WARN] MySQL is not running, skipping"
        return 1
    fi

    databases=$(docker exec devbox-mysql mysql -u root -e "SHOW DATABASES;" 2>/dev/null | \
        grep -vE "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return 1
    fi

    # Convert to array
    local db_list=()
    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        [ -n "$db" ] && db_list+=("$db")
    done <<< "$databases"

    # Show selection menu
    echo ""
    echo "  MySQL databases:"
    local i=1
    for db in "${db_list[@]}"; do
        printf "    %d) %s\n" "$i" "$db"
        i=$((i + 1))
    done
    echo ""
    echo "    a) All databases"
    echo ""

    local selected=()
    while true; do
        read -r -p "    Select (1-$((i-1)) or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            selected=("${db_list[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${db_list[$((choice - 1))]}")
            break
        fi
        echo "    Invalid choice."
    done

    mkdir -p "$BACKUP_PATH/mysql"
    count=0
    for db in "${selected[@]}"; do
        echo "  Dumping: $db"
        docker exec devbox-mysql mysqldump -u root --databases "$db" 2>/dev/null > "$BACKUP_PATH/mysql/$db.sql"
        if [ -f "$BACKUP_PATH/mysql/$db.sql" ]; then
            size=$(du -k "$BACKUP_PATH/mysql/$db.sql" | cut -f1)
            echo "    [OK] $db ($size KB)"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count database(s)"
}

# =====================
# PostgreSQL
# =====================
backup_postgres() {
    echo ""
    echo "Backing up PostgreSQL..."

    if ! is_running "devbox-postgres"; then
        echo "  [WARN] PostgreSQL is not running, skipping"
        return 1
    fi

    databases=$(docker exec devbox-postgres psql -U postgres -t -A -c \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" 2>/dev/null)

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return 1
    fi

    # Convert to array
    local db_list=()
    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        [ -n "$db" ] && db_list+=("$db")
    done <<< "$databases"

    # Show selection menu
    echo ""
    echo "  PostgreSQL databases:"
    local i=1
    for db in "${db_list[@]}"; do
        printf "    %d) %s\n" "$i" "$db"
        i=$((i + 1))
    done
    echo ""
    echo "    a) All databases"
    echo ""

    local selected=()
    while true; do
        read -r -p "    Select (1-$((i-1)) or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            selected=("${db_list[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${db_list[$((choice - 1))]}")
            break
        fi
        echo "    Invalid choice."
    done

    mkdir -p "$BACKUP_PATH/postgresql"
    count=0
    for db in "${selected[@]}"; do
        echo "  Dumping: $db"
        docker exec devbox-postgres pg_dump -U postgres "$db" 2>/dev/null > "$BACKUP_PATH/postgresql/$db.sql"
        if [ -f "$BACKUP_PATH/postgresql/$db.sql" ]; then
            size=$(du -k "$BACKUP_PATH/postgresql/$db.sql" | cut -f1)
            echo "    [OK] $db ($size KB)"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count database(s)"
}

# =====================
# MongoDB
# =====================
backup_mongo() {
    echo ""
    echo "Backing up MongoDB..."

    if ! is_running "devbox-mongo"; then
        echo "  [WARN] MongoDB is not running, skipping"
        return 1
    fi

    databases=$(docker exec devbox-mongo mongosh --quiet --eval "db.adminCommand('listDatabases').databases.map(d => d.name).filter(n => !['admin','config','local'].includes(n)).join('\n')" 2>/dev/null)

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return 1
    fi

    # Convert to array
    local db_list=()
    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        [ -n "$db" ] && db_list+=("$db")
    done <<< "$databases"

    # Show selection menu
    echo ""
    echo "  MongoDB databases:"
    local i=1
    for db in "${db_list[@]}"; do
        printf "    %d) %s\n" "$i" "$db"
        i=$((i + 1))
    done
    echo ""
    echo "    a) All databases"
    echo ""

    local selected=()
    while true; do
        read -r -p "    Select (1-$((i-1)) or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            selected=("${db_list[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${db_list[$((choice - 1))]}")
            break
        fi
        echo "    Invalid choice."
    done

    mkdir -p "$BACKUP_PATH/mongodb"
    count=0
    for db in "${selected[@]}"; do
        echo "  Dumping: $db"
        docker exec devbox-mongo mongodump --db "$db" --archive 2>/dev/null > "$BACKUP_PATH/mongodb/$db.archive"
        if [ -f "$BACKUP_PATH/mongodb/$db.archive" ]; then
            size=$(du -k "$BACKUP_PATH/mongodb/$db.archive" | cut -f1)
            echo "    [OK] $db ($size KB)"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count database(s)"
}

# =====================
# MariaDB
# =====================
backup_mariadb() {
    echo ""
    echo "Backing up MariaDB..."

    if ! is_running "devbox-mariadb"; then
        echo "  [WARN] MariaDB is not running, skipping"
        return 1
    fi

    databases=$(docker exec devbox-mariadb mariadb -u root -e "SHOW DATABASES;" 2>/dev/null | \
        grep -vE "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return 1
    fi

    # Convert to array
    local db_list=()
    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        [ -n "$db" ] && db_list+=("$db")
    done <<< "$databases"

    # Show selection menu
    echo ""
    echo "  MariaDB databases:"
    local i=1
    for db in "${db_list[@]}"; do
        printf "    %d) %s\n" "$i" "$db"
        i=$((i + 1))
    done
    echo ""
    echo "    a) All databases"
    echo ""

    local selected=()
    while true; do
        read -r -p "    Select (1-$((i-1)) or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            selected=("${db_list[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${db_list[$((choice - 1))]}")
            break
        fi
        echo "    Invalid choice."
    done

    mkdir -p "$BACKUP_PATH/mariadb"
    count=0
    for db in "${selected[@]}"; do
        echo "  Dumping: $db"
        docker exec devbox-mariadb mariadb-dump -u root --databases "$db" 2>/dev/null > "$BACKUP_PATH/mariadb/$db.sql"
        if [ -f "$BACKUP_PATH/mariadb/$db.sql" ]; then
            size=$(du -k "$BACKUP_PATH/mariadb/$db.sql" | cut -f1)
            echo "    [OK] $db ($size KB)"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count database(s)"
}

# =====================
# Redis
# =====================
backup_redis() {
    echo ""
    echo "Backing up Redis..."

    if ! is_running "devbox-redis"; then
        echo "  [WARN] Redis is not running, skipping"
        return 1
    fi

    mkdir -p "$BACKUP_PATH/redis"

    # Trigger background save and wait for it
    docker exec devbox-redis redis-cli BGSAVE >/dev/null 2>&1
    sleep 2

    # Copy dump.rdb from container
    docker cp devbox-redis:/data/dump.rdb "$BACKUP_PATH/redis/dump.rdb" 2>/dev/null

    if [ -f "$BACKUP_PATH/redis/dump.rdb" ]; then
        size=$(du -k "$BACKUP_PATH/redis/dump.rdb" | cut -f1)
        echo "  [OK] dump.rdb ($size KB)"
    else
        echo "  [WARN] No Redis data found"
        return 1
    fi
}

# =====================
# Bruno (named volumes)
# =====================
backup_bruno() {
    echo ""
    echo "Backing up Bruno..."

    mkdir -p "$BACKUP_PATH/bruno"

    # Backup bruno-config volume
    if docker volume inspect devbox_bruno-config >/dev/null 2>&1; then
        echo "  Backing up bruno-config..."
        docker run --rm \
            -v devbox_bruno-config:/data:ro \
            -v "$(realpath "$BACKUP_PATH/bruno"):/backup" \
            alpine tar czf /backup/bruno-config.tar.gz -C /data . 2>/dev/null
        if [ -f "$BACKUP_PATH/bruno/bruno-config.tar.gz" ]; then
            size=$(du -k "$BACKUP_PATH/bruno/bruno-config.tar.gz" | cut -f1)
            echo "    [OK] bruno-config ($size KB)"
        fi
    else
        echo "  [WARN] bruno-config volume not found, skipping"
    fi

    # Backup bruno-collections volume
    if docker volume inspect devbox_bruno-collections >/dev/null 2>&1; then
        echo "  Backing up bruno-collections..."
        docker run --rm \
            -v devbox_bruno-collections:/data:ro \
            -v "$(realpath "$BACKUP_PATH/bruno"):/backup" \
            alpine tar czf /backup/bruno-collections.tar.gz -C /data . 2>/dev/null
        if [ -f "$BACKUP_PATH/bruno/bruno-collections.tar.gz" ]; then
            size=$(du -k "$BACKUP_PATH/bruno/bruno-collections.tar.gz" | cut -f1)
            echo "    [OK] bruno-collections ($size KB)"
        fi
    else
        echo "  [WARN] bruno-collections volume not found, skipping"
    fi
}

# =====================
# Projects (excluding generated folders)
# =====================

# Detect project type (same as setup-deps.sh)
detect_project_type() {
    local dir="$1"
    if [ -f "$dir/artisan" ]; then echo "laravel"; return; fi
    if [ -f "$dir/manage.py" ]; then echo "django"; return; fi
    if ls "$dir"/fastapi* 1>/dev/null 2>&1; then echo "fastapi"; return; fi
    if [ -f "$dir/Gemfile" ]; then echo "rails"; return; fi
    if [ -f "$dir/go.mod" ]; then echo "go"; return; fi
    if [ -f "$dir/mix.exs" ]; then echo "phoenix"; return; fi
    if ls "$dir"/next.config* 1>/dev/null 2>&1 || [ -d "$dir/.next" ]; then echo "nextjs"; return; fi
    if [ -f "$dir/pubspec.yaml" ]; then echo "flutter"; return; fi
    if [ -f "$dir/package.json" ]; then
        if grep -q '"react"' "$dir/package.json" 2>/dev/null; then
            echo "react"; return
        else
            echo "express"; return
        fi
    fi
    if [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/Pipfile" ]; then
        echo "python"; return
    fi
    if ls "$dir"/*.py 1>/dev/null 2>&1; then
        echo "python"; return
    fi
    echo ""
}

# Get project type description
get_project_desc() {
    case "$1" in
        laravel)  echo "Laravel (PHP)" ;;
        django)   echo "Django (Python)" ;;
        fastapi)  echo "FastAPI (Python)" ;;
        rails)    echo "Rails (Ruby)" ;;
        go)       echo "Go" ;;
        phoenix)  echo "Phoenix (Elixir)" ;;
        nextjs)   echo "Next.js (React)" ;;
        flutter)  echo "Flutter (Dart)" ;;
        react)    echo "React (JavaScript)" ;;
        express)  echo "Express (Node.js)" ;;
        python)   echo "Python" ;;
        *)        echo "$1" ;;
    esac
}

backup_projects() {
    echo ""
    echo "Backing up projects..."

    local workspace_dir="$PROJECT_ROOT/workspace"
    local projects_dir="$BACKUP_PATH/projects"

    if [ ! -d "$workspace_dir" ]; then
        echo "  [WARN] Workspace not found, skipping"
        return 1
    fi

    # Detect all projects
    local projects=()
    for dir in "$workspace_dir"/*/; do
        [ -d "$dir" ] || continue
        local name=$(basename "$dir")
        # Skip non-project directories
        case "$name" in
            data|scripts|prebuilt|.git) continue ;;
        esac
        # Skip if only .gitkeep exists
        if [ "$(ls -A "$dir" 2>/dev/null | grep -v '.gitkeep' | wc -l)" -eq 0 ]; then
            continue
        fi
        local ptype=$(detect_project_type "$dir")
        if [ -n "$ptype" ]; then
            projects+=("$name|$ptype")
        fi
    done

    if [ ${#projects[@]} -eq 0 ]; then
        echo "  [WARN] No projects found, skipping"
        return 1
    fi

    # Show project selection menu
    echo ""
    echo "========================================="
    echo "Detected projects:"
    echo "========================================="
    echo ""

    local i=1
    for item in "${projects[@]}"; do
        local name="${item%%|*}"
        local ptype="${item##*|}"
        local desc=$(get_project_desc "$ptype")
        printf "  %d) %s (%s)\n" "$i" "$name" "$desc"
        i=$((i + 1))
    done

    echo ""
    echo "  a) All projects"
    echo ""

    # Get user selection
    local selected=()
    while true; do
        read -r -p "Select project (1-$((i-1)) or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            selected=("${projects[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${projects[$((choice - 1))]}")
            break
        fi
        echo "Invalid choice. Enter 1-$((i-1)) or a."
    done

    # Create projects directory
    mkdir -p "$projects_dir"

    # Exclusion patterns for generated folders
    local excludes=(
        "node_modules"
        "vendor"
        "venv"
        ".venv"
        "__pycache__"
        ".next"
        ".nuxt"
        "dist"
        "build"
        ".git"
        ".cache"
        ".pytest_cache"
        "*.pyc"
        ".mypy_cache"
        ".tox"
        "coverage"
        ".coverage"
        "htmlcov"
        ".env.local"
        ".env.production"
    )

    # Build tar exclude arguments
    local exclude_args=""
    for pattern in "${excludes[@]}"; do
        exclude_args="$exclude_args --exclude=$pattern"
    done

    count=0
    for item in "${selected[@]}"; do
        local name="${item%%|*}"
        echo "  Backing up: $name"

        # Use tar with excludes
        eval tar czf "$projects_dir/$name.tar.gz" -C "$workspace_dir" "$name" $exclude_args 2>/dev/null

        if [ -f "$projects_dir/$name.tar.gz" ]; then
            size=$(du -k "$projects_dir/$name.tar.gz" | cut -f1)
            echo "    [OK] $name ($size KB)"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count project(s)"
}

# =====================
# Validate backup
# =====================
validate_backup() {
    echo ""
    echo "Validating backup..."

    errors=0

    # Check SQL files are not empty
    for dir in mysql postgresql mariadb; do
        if [ -d "$BACKUP_PATH/$dir" ]; then
            for f in "$BACKUP_PATH/$dir"/*.sql; do
                [ -f "$f" ] || continue
                if [ ! -s "$f" ]; then
                    echo "  [ERROR] Empty file: $(basename "$f")"
                    errors=$((errors + 1))
                fi
            done
        fi
    done

    # Check tar.gz files are valid
    if [ -d "$BACKUP_PATH/bruno" ]; then
        for f in "$BACKUP_PATH/bruno"/*.tar.gz; do
            [ -f "$f" ] || continue
            if ! tar tzf "$f" >/dev/null 2>&1; then
                echo "  [ERROR] Corrupted archive: $(basename "$f")"
                errors=$((errors + 1))
            fi
        done
    fi

    # Check Redis dump
    if [ -f "$BACKUP_PATH/redis/dump.rdb" ]; then
        if [ ! -s "$BACKUP_PATH/redis/dump.rdb" ]; then
            echo "  [ERROR] Empty Redis dump"
            errors=$((errors + 1))
        fi
    fi

    if [ $errors -eq 0 ]; then
        echo "  [OK] All files valid"
    else
        echo "  [WARN] $errors file(s) have issues"
    fi
}

# =====================
# Cleanup old backups
# =====================
cleanup_old_backups() {
    echo ""
    echo "Checking for old backups..."

    count=0
    for dir in "$BACKUP_DIR"/devbox-backup-*/; do
        [ -d "$dir" ] || continue
        count=$((count + 1))
    done

    if [ $count -le 5 ]; then
        echo "  $count backup(s) found, no cleanup needed (minimum: 5)"
        return
    fi

    echo "  $count backup(s) found, checking for old ones..."

    # Always keep 5 most recent, delete others older than 30 days
    removed=0
    for dir in $(ls -dt "$BACKUP_DIR"/devbox-backup-*/); do
        [ -d "$dir" ] || continue
        count=$((count - 1))

        # Always keep 5 most recent
        if [ $count -lt 5 ]; then
            break
        fi

        # Check if older than 30 days
        if [ -d "$dir" ]; then
            dir_age=$(find "$dir" -maxdepth 0 -mtime +30 2>/dev/null)
            if [ -n "$dir_age" ]; then
                name=$(basename "$dir")
                echo "    Removing: $name (older than 30 days)"
                rm -rf "$dir"
                removed=$((removed + 1))
            fi
        fi
    done

    if [ $removed -eq 0 ]; then
        echo "  No old backups to remove"
    else
        echo "  Removed $removed old backup(s)"
    fi
}

# =====================
# Show menu
# =====================
echo ""
echo "========================================="
echo "Select what to backup:"
echo "========================================="
echo ""
echo "  1) All"
echo "  2) Databases only (MySQL + PostgreSQL + MongoDB + MariaDB + Redis)"
echo "  3) Bruno only"
echo "  4) Projects only"
echo ""
read -r -p "Select option (1-4): " choice

echo ""
echo "========================================="
echo "Backing up DevBox Data"
echo "========================================="

case "$choice" in
    1) backup_mysql; backup_postgres; backup_mongo; backup_mariadb; backup_redis; backup_bruno; backup_projects ;;
    2) backup_mysql; backup_postgres; backup_mongo; backup_mariadb; backup_redis ;;
    3) backup_bruno ;;
    4) backup_projects ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

# Validate and cleanup
validate_backup
cleanup_old_backups

# Create info file
cat > "$BACKUP_PATH/backup-info.txt" << EOF
Backup created: $(date +"%Y-%m-%d %H:%M:%S")
Selection: $choice
Timestamp: $TIMESTAMP
EOF

# Calculate size
total_size=$(du -sb "$BACKUP_PATH" | cut -f1)
size_kb=$((total_size / 1024))
size_mb=$((total_size / 1048576))

# Count items
items=0
[ -d "$BACKUP_PATH/mysql" ] && items=$((items + $(ls "$BACKUP_PATH/mysql"/*.sql 2>/dev/null | wc -l)))
[ -d "$BACKUP_PATH/postgresql" ] && items=$((items + $(ls "$BACKUP_PATH/postgresql"/*.sql 2>/dev/null | wc -l)))
[ -d "$BACKUP_PATH/mongodb" ] && items=$((items + $(ls "$BACKUP_PATH/mongodb"/*.archive 2>/dev/null | wc -l)))
[ -d "$BACKUP_PATH/mariadb" ] && items=$((items + $(ls "$BACKUP_PATH/mariadb"/*.sql 2>/dev/null | wc -l)))
[ -f "$BACKUP_PATH/redis/dump.rdb" ] && items=$((items + 1))
[ -d "$BACKUP_PATH/bruno" ] && items=$((items + $(ls "$BACKUP_PATH/bruno"/*.tar.gz 2>/dev/null | wc -l)))
[ -d "$BACKUP_PATH/projects" ] && items=$((items + $(ls "$BACKUP_PATH/projects"/*.tar.gz 2>/dev/null | wc -l)))

echo ""
echo "========================================="
echo "[OK] Backup completed successfully!"
echo "========================================="
echo ""
echo "  Location: $BACKUP_PATH"
echo "  Size: ${size_kb} KB (${size_mb} MB)"
echo "  Items: $items file(s)"
echo ""
echo "To restore, run: ./scripts/restore.sh"
