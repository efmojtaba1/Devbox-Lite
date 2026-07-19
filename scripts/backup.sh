#!/bin/bash
# DevBox Lite - Backup data

source "$(dirname "$0")/common.sh"

DATA_DIR="$PROJECT_ROOT/workspace/data"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M")
BACKUP_NAME="devbox-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_PATH"

# Backup API tools (Bruno)
backup_api() {
    echo ""
    echo "Backing up API tools (Bruno)..."

    if [ ! -d "$DATA_DIR" ]; then
        echo "  [WARN] Data directory not found, skipping"
        return
    fi

    items=$(find "$DATA_DIR" -mindepth 1 -not -name ".gitkeep" 2>/dev/null)
    if [ -z "$items" ]; then
        echo "  [WARN] No API tools data found, skipping"
        return
    fi

    mkdir -p "$BACKUP_PATH/api-tools"
    cp -r "$DATA_DIR"/* "$BACKUP_PATH/api-tools/" 2>/dev/null
    echo "  [OK] API tools backed up"
}

# Backup MySQL
backup_mysql() {
    echo ""
    echo "Backing up MySQL databases..."

    if ! docker ps --format '{{.Names}}' | grep -q "^devbox-mysql$"; then
        echo "  [WARN] MySQL container is not running, skipping"
        return
    fi

    mkdir -p "$BACKUP_PATH/mysql"

    databases=$(docker exec devbox-mysql mysql -u root -e "SHOW DATABASES;" 2>/dev/null | \
        grep -vE "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return
    fi

    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        if [ -n "$db" ]; then
            echo "  Dumping: $db"
            docker exec devbox-mysql mysqldump -u root --databases "$db" 2>/dev/null > "$BACKUP_PATH/mysql/$db.sql"
            if [ -f "$BACKUP_PATH/mysql/$db.sql" ]; then
                size=$(du -k "$BACKUP_PATH/mysql/$db.sql" | cut -f1)
                echo "    [OK] $db ($size KB)"
            fi
        fi
    done <<< "$databases"
}

# Backup PostgreSQL
backup_postgres() {
    echo ""
    echo "Backing up PostgreSQL databases..."

    if ! docker ps --format '{{.Names}}' | grep -q "^devbox-postgres$"; then
        echo "  [WARN] PostgreSQL container is not running, skipping"
        return
    fi

    mkdir -p "$BACKUP_PATH/postgresql"

    databases=$(docker exec devbox-postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" 2>/dev/null)

    if [ -z "$databases" ]; then
        echo "  [WARN] No user databases found, skipping"
        return
    fi

    while IFS= read -r db; do
        db=$(echo "$db" | tr -d '[:space:]')
        if [ -n "$db" ]; then
            echo "  Dumping: $db"
            docker exec devbox-postgres pg_dump -U postgres "$db" 2>/dev/null > "$BACKUP_PATH/postgresql/$db.sql"
            if [ -f "$BACKUP_PATH/postgresql/$db.sql" ]; then
                size=$(du -k "$BACKUP_PATH/postgresql/$db.sql" | cut -f1)
                echo "    [OK] $db ($size KB)"
            fi
        fi
    done <<< "$databases"
}

# Show menu
echo ""
echo "========================================="
echo "Select what to backup:"
echo "========================================="
echo ""
echo "  1) All (databases + API tools)"
echo "  2) Databases only (MySQL + PostgreSQL)"
echo "  3) API tools only (Bruno)"
echo ""
read -r -p "Select option (1-3): " choice

echo ""
echo "========================================="
echo "Backing up DevBox Data"
echo "========================================="

case "$choice" in
    1) backup_api; backup_mysql; backup_postgres ;;
    2) backup_mysql; backup_postgres ;;
    3) backup_api ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

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

echo ""
echo "========================================="
echo "[OK] Backup completed successfully!"
echo "========================================="
echo ""
echo "  Location: $BACKUP_PATH"
echo "  Size: ${size_kb} KB (${size_mb} MB)"
echo ""
echo "To restore, run: ./scripts/restore.sh"
