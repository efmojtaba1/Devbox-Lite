#!/bin/bash
# DevBox Lite - Restore data from backup

source "$(dirname "$0")/common.sh"

BACKUP_DIR="$PROJECT_ROOT/backups"
DATA_DIR="$PROJECT_ROOT/workspace/data"

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

# Find legacy zip files
for zip in "$BACKUP_DIR"/devbox-data-*.zip; do
    [ -f "$zip" ] || continue
    backups+=("$zip")
done

if [ ${#backups[@]} -eq 0 ]; then
    echo "[ERROR] No backup files found in $BACKUP_DIR"
    exit 1
fi

echo "Available backups:"
echo ""

index=1
for item in "${backups[@]}"; do
    if [ -d "$item" ]; then
        name=$(basename "$item")
        size=$(du -sk "$item" | cut -f1)
        info=""
        if [ -f "$item/backup-info.txt" ]; then
            info=$(head -1 "$item/backup-info.txt" | sed 's/Backup created: //')
        fi
        echo "  $index) $name ($size KB) - $info"
    else
        name=$(basename "$item")
        size=$(du -k "$item" | cut -f1)
        echo "  $index) $name ($size KB) [legacy format]"
    fi
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
echo "  1) All (databases + API tools)"
echo "  2) Databases only"
echo "  3) API tools only"
echo ""
read -r -p "Select option (1-3): " restore_choice

echo ""
echo "Restoring from: $(basename "$selected")"
read -r -p "This will replace current data. Continue? (y/N): " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Restore cancelled."
    exit 0
fi

# Restore API tools
restore_api() {
    local src="$1/api-tools"
    echo ""
    echo "Restoring API tools (Bruno)..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No API tools data found in backup, skipping"
        return
    fi

    mkdir -p "$DATA_DIR"
    rm -rf "$DATA_DIR"/*
    cp -r "$src"/* "$DATA_DIR/" 2>/dev/null
    echo "  [OK] API tools restored"
}

# Restore MySQL
restore_mysql() {
    local src="$1/mysql"
    echo ""
    echo "Restoring MySQL databases..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No MySQL data found in backup, skipping"
        return
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^devbox-mysql$"; then
        echo "  [WARN] MySQL container is not running, skipping"
        return
    fi

    for dump in "$src"/*.sql; do
        [ -f "$dump" ] || continue
        dbName=$(basename "$dump" .sql)
        echo "  Restoring: $dbName"
        docker exec -i devbox-mysql mysql -u root < "$dump" 2>/dev/null
        echo "    [OK] $dbName restored"
    done
}

# Restore PostgreSQL
restore_postgres() {
    local src="$1/postgresql"
    echo ""
    echo "Restoring PostgreSQL databases..."

    if [ ! -d "$src" ]; then
        echo "  [WARN] No PostgreSQL data found in backup, skipping"
        return
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^devbox-postgres$"; then
        echo "  [WARN] PostgreSQL container is not running, skipping"
        return
    fi

    for dump in "$src"/*.sql; do
        [ -f "$dump" ] || continue
        dbName=$(basename "$dump" .sql)
        echo "  Restoring: $dbName"
        docker exec devbox-postgres psql -U postgres -c "CREATE DATABASE \"$dbName\";" 2>/dev/null
        docker exec -i devbox-postgres psql -U postgres -d "$dbName" < "$dump" 2>/dev/null
        echo "    [OK] $dbName restored"
    done
}

# Execute restore
case "$restore_choice" in
    1) restore_api "$selected"; restore_mysql "$selected"; restore_postgres "$selected" ;;
    2) restore_mysql "$selected"; restore_postgres "$selected" ;;
    3) restore_api "$selected" ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

echo ""
echo "========================================="
echo "[OK] Restore completed successfully!"
echo "========================================="
echo ""
echo "Run 'up' to start DevBox."
