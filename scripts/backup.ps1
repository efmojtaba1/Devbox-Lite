$ScriptDir = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $ScriptDir "workspace\data"
$backupDir = Join-Path $ScriptDir "backups"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupName = "devbox-backup-$timestamp"
$backupPath = Join-Path $backupDir $backupName

# Create backup directory structure
function Initialize-BackupDir {
    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }
}

# Backup API tools (Bruno/Postman)
function Backup-ApiTools {
    Write-Host ""
    Write-Host "Backing up API tools (Bruno/Postman)..."
    
    if (-not (Test-Path $dataDir)) {
        Write-Host "  [WARN] Data directory not found, skipping"
        return
    }
    
    $dataItems = Get-ChildItem $dataDir -Force | Where-Object { $_.Name -ne ".gitkeep" }
    if (-not $dataItems) {
        Write-Host "  [WARN] No API tools data found, skipping"
        return
    }
    
    $apiBackupDir = Join-Path $backupPath "api-tools"
    New-Item -ItemType Directory -Path $apiBackupDir -Force | Out-Null
    Copy-Item -Path "$dataDir\*" -Destination $apiBackupDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] API tools backed up"
}

# Backup MySQL database
function Backup-MySQL {
    Write-Host ""
    Write-Host "Backing up MySQL databases..."
    
    # Check if MySQL container is running
    $mysqlRunning = docker ps --format '{{.Names}}' | Select-String -Pattern "^devbox-mysql$"
    if (-not $mysqlRunning) {
        Write-Host "  [WARN] MySQL container is not running, skipping"
        return
    }
    
    $mysqlBackupDir = Join-Path $backupPath "mysql"
    New-Item -ItemType Directory -Path $mysqlBackupDir -Force | Out-Null
    
    # Get list of databases (skip system databases)
    $databases = docker exec devbox-mysql mysql -u root -e "SHOW DATABASES;" 2>$null | 
        Where-Object { $_ -notmatch "^(Database|information_schema|performance_schema|mysql|sys)$" }
    
    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }
    
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) {
            $dumpFile = Join-Path $mysqlBackupDir "$db.sql"
            Write-Host "  Dumping: $db"
            docker exec devbox-mysql mysqldump -u root --databases $db 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
            if (Test-Path $dumpFile) {
                $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
                Write-Host "    [OK] $db ($size KB)"
            }
        }
    }
}

# Backup PostgreSQL database
function Backup-PostgreSQL {
    Write-Host ""
    Write-Host "Backing up PostgreSQL databases..."
    
    # Check if PostgreSQL container is running
    $pgRunning = docker ps --format '{{.Names}}' | Select-String -Pattern "^devbox-postgres$"
    if (-not $pgRunning) {
        Write-Host "  [WARN] PostgreSQL container is not running, skipping"
        return
    }
    
    $pgBackupDir = Join-Path $backupPath "postgresql"
    New-Item -ItemType Directory -Path $pgBackupDir -Force | Out-Null
    
    # Get list of databases (skip system databases)
    $databases = docker exec devbox-postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" 2>$null
    
    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }
    
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) {
            $dumpFile = Join-Path $pgBackupDir "$db.sql"
            Write-Host "  Dumping: $db"
            docker exec devbox-postgres pg_dump -U postgres $db 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
            if (Test-Path $dumpFile) {
                $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
                Write-Host "    [OK] $db ($size KB)"
            }
        }
    }
}

# Show backup menu
function Show-Menu {
    Write-Host ""
    Write-Host "========================================="
    Write-Host "Select what to backup:"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "  1) All (databases + API tools)"
    Write-Host "  2) Databases only (MySQL + PostgreSQL)"
    Write-Host "  3) API tools only (Bruno/Postman)"
    Write-Host ""
    
    do {
        $choice = Read-Host "Select option (1-3)"
    } while ($choice -notmatch "^[1-3]$")
    
    return $choice
}

# Main backup logic
$choice = Show-Menu

Write-Host ""
Write-Host "========================================="
Write-Host "Backing up DevBox Data"
Write-Host "========================================="

Initialize-BackupDir

switch ($choice) {
    "1" {
        Backup-ApiTools
        Backup-MySQL
        Backup-PostgreSQL
    }
    "2" {
        Backup-MySQL
        Backup-PostgreSQL
    }
    "3" {
        Backup-ApiTools
    }
}

# Create backup info file
$infoFile = Join-Path $backupPath "backup-info.txt"
 @"
Backup created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Selection: $choice
Timestamp: $timestamp
"@ | Out-File -FilePath $infoFile -Encoding UTF8

# Calculate total size
$totalSize = (Get-ChildItem -Path $backupPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalSizeKB = [math]::Round($totalSize / 1KB, 2)
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host ""
Write-Host "========================================="
Write-Host "[OK] Backup completed successfully!"
Write-Host "========================================="
Write-Host ""
Write-Host "  Location: $backupPath"
Write-Host "  Size: $totalSizeKB KB ($totalSizeMB MB)"
Write-Host ""
Write-Host "To restore, run: .\scripts\restore"
