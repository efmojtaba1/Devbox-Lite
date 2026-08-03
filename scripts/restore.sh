#!/bin/bash
# DevBox Lite - Restore data from backup

source "$(dirname "$0")/common.sh"

BACKUP_DIR="$PROJECT_ROOT/backups"

echo ""
echo "========================================="
echo "Restoring DevBox Data"
echo "========================================="
echo ""

if [ ! -d "$BACKUP_DIR" ]; then
    echo "[ERROR] No backups found in $BACKUP_DIR"
    exit 1
fi

# Find backup folders
backups=()
for dir in "$BACKUP_DIR"/devbox-backup-*/; do
    [ -d "$dir" ] || continue
    backups+=("$dir")
done

if [ ${#backups[@]} -eq 0 ]; then
    echo "[ERROR] No backup files found in $BACKUP_DIR"
    exit 1
fi

echo "Available backups:"
echo ""

index=1
for item in "${backups[@]}"; do
    name=$(basename "$item")
    size=$(du -sk "$item" | cut -f1)
    info=""
    if [ -f "$item/backup-info.txt" ]; then
        info=$(head -1 "$item/backup-info.txt" | sed 's/Backup created: //')
    fi
    echo "  $index) $name ($size KB) - $info"
    index=$((index + 1))
done

echo ""
read -r -p "Enter backup number to restore (1-${#backups[@]}): " selection

if [ -z "$selection" ] || [ "$selection" -lt 1 ] || [ "$selection" -gt "${#backups[@]}" ]; then
    echo "[ERROR] Invalid selection"
    exit 1
fi

selected="${backups[$((selection - 1))]}"

echo ""
echo "========================================="
echo "Select what to restore:"
echo "========================================="
echo ""
echo "  1) All"
echo "  2) Databases only"
echo "  3) Bruno only"
echo "  4) Projects only"
echo ""
read -r -p "Select option (1-4): " restore_choice

echo ""
echo "Restoring from: $(basename "$selected")"
read -r -p "This will replace current data. Continue? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Check if a container is running
is_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$1$"
}

# =====================
# MySQL
# =====================
restore_mysql() {
    local src="$1/mysql"
    echo ""
    echo "Restoring MySQL..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No MySQL data found in backup, skipping"
        return
    fi

    if ! is_running "devbox-mysql"; then
        echo "  [WARN] MySQL is not running, skipping"
        return
    fi

    count=0
    for dump in "$src"/*.sql; do
        [ -f "$dump" ] || continue
        dbName=$(basename "$dump" .sql)
        echo "  Restoring: $dbName"
        docker exec -i devbox-mysql mysql -u root < "$dump" 2>/dev/null
        echo "    [OK] $dbName restored"
        count=$((count + 1))
    done
    echo "  Total: $count database(s)"
}

# =====================
# PostgreSQL
# =====================
restore_postgres() {
    local src="$1/postgresql"
    echo ""
    echo "Restoring PostgreSQL..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No PostgreSQL data found in backup, skipping"
        return
    fi

    if ! is_running "devbox-postgres"; then
        echo "  [WARN] PostgreSQL is not running, skipping"
        return
    fi

    count=0
    for dump in "$src"/*.sql; do
        [ -f "$dump" ] || continue
        dbName=$(basename "$dump" .sql)
        echo "  Restoring: $dbName"
        docker exec devbox-postgres psql -U postgres -c "CREATE DATABASE \"$dbName\";" 2>/dev/null
        docker exec -i devbox-postgres psql -U postgres -d "$dbName" < "$dump" 2>/dev/null
        echo "    [OK] $dbName restored"
        count=$((count + 1))
    done
    echo "  Total: $count database(s)"
}

# =====================
# MongoDB
# =====================
restore_mongo() {
    local src="$1/mongodb"
    echo ""
    echo "Restoring MongoDB..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No MongoDB data found in backup, skipping"
        return
    fi

    if ! is_running "devbox-mongo"; then
        echo "  [WARN] MongoDB is not running, skipping"
        return
    fi

    count=0
    for archive in "$src"/*.archive; do
        [ -f "$archive" ] || continue
        dbName=$(basename "$archive" .archive)
        echo "  Restoring: $dbName"
        docker exec -i devbox-mongo mongorestore --db "$dbName" --archive 2>/dev/null < "$archive"
        echo "    [OK] $dbName restored"
        count=$((count + 1))
    done
    echo "  Total: $count database(s)"
}

# =====================
# MariaDB
# =====================
restore_mariadb() {
    local src="$1/mariadb"
    echo ""
    echo "Restoring MariaDB..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No MariaDB data found in backup, skipping"
        return
    fi

    if ! is_running "devbox-mariadb"; then
        echo "  [WARN] MariaDB is not running, skipping"
        return
    fi

    count=0
    for dump in "$src"/*.sql; do
        [ -f "$dump" ] || continue
        dbName=$(basename "$dump" .sql)
        echo "  Restoring: $dbName"
        docker exec -i devbox-mariadb mariadb -u root < "$dump" 2>/dev/null
        echo "    [OK] $dbName restored"
        count=$((count + 1))
    done
    echo "  Total: $count database(s)"
}

# =====================
# Redis
# =====================
restore_redis() {
    local src="$1/redis"
    echo ""
    echo "Restoring Redis..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No Redis data found in backup, skipping"
        return
    fi

    if ! is_running "devbox-redis"; then
        echo "  [WARN] Redis is not running, skipping"
        return
    fi

    if [ ! -f "$src/dump.rdb" ]; then
        echo "  [WARN] No dump.rdb found, skipping"
        return
    fi

    # Stop Redis, copy dump, restart
    echo "  Stopping Redis..."
    docker exec devbox-redis redis-cli SHUTDOWN NOSAVE 2>/dev/null
    sleep 1

    echo "  Copying dump.rdb..."
    docker cp "$src/dump.rdb" devbox-redis:/data/dump.rdb 2>/dev/null

    echo "  Starting Redis..."
    docker start devbox-redis 2>/dev/null
    sleep 1

    if is_running "devbox-redis"; then
        echo "  [OK] Redis restored"
    else
        echo "  [WARN] Redis may need manual restart"
    fi
}

# =====================
# Bruno (named volumes)
# =====================
restore_bruno() {
    local src="$1/bruno"
    echo ""
    echo "Restoring Bruno..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No Bruno data found in backup, skipping"
        return
    fi

    # Restore bruno-config volume
    if [ -f "$src/bruno-config.tar.gz" ]; then
        echo "  Restoring bruno-config..."
        docker run --rm \
            -v devbox_bruno-config:/data \
            -v "$(realpath "$src"):/backup:ro" \
            alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/bruno-config.tar.gz -C /data" 2>/dev/null
        echo "    [OK] bruno-config restored"
    fi

    # Restore bruno-collections volume
    if [ -f "$src/bruno-collections.tar.gz" ]; then
        echo "  Restoring bruno-collections..."
        docker run --rm \
            -v devbox_bruno-collections:/data \
            -v "$(realpath "$src"):/backup:ro" \
            alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/bruno-collections.tar.gz -C /data" 2>/dev/null
        echo "    [OK] bruno-collections restored"
    fi
}

# =====================
# Projects
# =====================
restore_projects() {
    local src="$1/projects"
    echo ""
    echo "Restoring projects..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No project data found in backup, skipping"
        return
    fi

    local workspace_dir="$PROJECT_ROOT/workspace"

    # Find available project archives
    local archives=()
    for archive in "$src"/*.tar.gz; do
        [ -f "$archive" ] || continue
        archives+=("$archive")
    done

    if [ ${#archives[@]} -eq 0 ]; then
        echo "  [WARN] No project archives found, skipping"
        return
    fi

    # Show project selection menu
    echo ""
    echo "========================================="
    echo "Available projects in backup:"
    echo "========================================="
    echo ""

    local i=1
    for archive in "${archives[@]}"; do
        local name=$(basename "$archive" .tar.gz)
        local size=$(du -k "$archive" | cut -f1)
        printf "  %d) %s (%s KB)\n" "$i" "$name" "$size"
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
            selected=("${archives[@]}")
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
            selected+=("${archives[$((choice - 1))]}")
            break
        fi
        echo "Invalid choice. Enter 1-$((i-1)) or a."
    done

    # Restore selected projects
    count=0
    for archive in "${selected[@]}"; do
        local name=$(basename "$archive" .tar.gz)
        echo "  Restoring: $name"

        # Check if project already exists
        if [ -d "$workspace_dir/$name" ]; then
            read -r -p "    Project '$name' exists. Overwrite? (y/N): " confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "    [SKIP] $name"
                continue
            fi
            rm -rf "$workspace_dir/$name"
        fi

        tar xzf "$archive" -C "$workspace_dir" 2>/dev/null
        if [ -d "$workspace_dir/$name" ]; then
            echo "    [OK] $name restored"
            count=$((count + 1))
        fi
    done
    echo "  Total: $count project(s)"
}

# =====================
# Execute restore
# =====================
case "$restore_choice" in
    1) restore_mysql "$selected"; restore_postgres "$selected"; restore_mongo "$selected"; restore_mariadb "$selected"; restore_redis "$selected"; restore_bruno "$selected"; restore_projects "$selected" ;;
    2) restore_mysql "$selected"; restore_postgres "$selected"; restore_mongo "$selected"; restore_mariadb "$selected"; restore_redis "$selected" ;;
    3) restore_bruno "$selected" ;;
    4) restore_projects "$selected" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

echo ""
echo "========================================="
echo "[OK] Restore completed successfully!"
echo "========================================="
echo ""
echo "Run 'up' to start DevBox."
