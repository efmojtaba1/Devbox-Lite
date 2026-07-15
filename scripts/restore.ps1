$ScriptDir = Split-Path -Parent $PSScriptRoot
$ComposeFile = Join-Path $ScriptDir "docker\compose\docker-compose.yml"
$backupDir = Join-Path $ScriptDir "backups"
$dataDir = Join-Path $ScriptDir "workspace\data"

Write-Host ""
Write-Host "========================================="
Write-Host "Restoring DevBox Data"
Write-Host "========================================="
Write-Host ""

if (-not (Test-Path $backupDir)) {
    Write-Host "[ERROR] No backups found in $backupDir"
    exit 1
}

# Get backup folders (new format) or zip files (old format)
$backupFolders = Get-ChildItem $backupDir -Directory | Where-Object { $_.Name -match "^devbox-backup-" } | Sort-Object LastWriteTime -Descending
$backupZips = Get-ChildItem $backupDir -Filter "devbox-data-*.zip" | Sort-Object LastWriteTime -Descending

if (-not $backupFolders -and -not $backupZips) {
    Write-Host "[ERROR] No backup files found in $backupDir"
    exit 1
}

Write-Host "Available backups:"
Write-Host ""

$allBackups = @()
$index = 1

# Add backup folders (new format)
foreach ($folder in $backupFolders) {
    $infoFile = Join-Path $folder.FullName "backup-info.txt"
    $size = (Get-ChildItem -Path $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeKB = [math]::Round($size / 1KB, 2)
    
    $backupInfo = ""
    if (Test-Path $infoFile) {
        $backupInfo = (Get-Content $infoFile -First 1) -replace "Backup created: ", ""
    }
    
    Write-Host "  $index) $($folder.Name) ($sizeKB KB) - $backupInfo"
    $allBackups += @{ type = "folder"; path = $folder.FullName; name = $folder.Name }
    $index++
}

# Add backup zips (old format)
foreach ($zip in $backupZips) {
    $size = [math]::Round($zip.Length / 1KB, 2)
    Write-Host "  $index) $($zip.Name) ($size KB) [legacy format]"
    $allBackups += @{ type = "zip"; path = $zip.FullName; name = $zip.Name }
    $index++
}

Write-Host ""
$selection = Read-Host "Enter backup number to restore (1-$($allBackups.Count))"

if (-not $selection -or $selection -lt 1 -or $selection -gt $allBackups.Count) {
    Write-Host "[ERROR] Invalid selection"
    exit 1
}

$selectedBackup = $allBackups[$selection - 1]

# Show restore menu
function Show-RestoreMenu {
    Write-Host ""
    Write-Host "========================================="
    Write-Host "Select what to restore:"
    Write-Host "========================================="
    Write-Host ""
    Write-Host "  1) All (databases + API tools)"
    Write-Host "  2) Databases only"
    Write-Host "  3) API tools only"
    Write-Host ""
    
    do {
        $choice = Read-Host "Select option (1-3)"
    } while ($choice -notmatch "^[1-3]$")
    
    return $choice
}

$restoreChoice = Show-RestoreMenu

Write-Host ""
Write-Host "Restoring from: $($selectedBackup.name)"

$confirm = Read-Host "This will replace current data. Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Restore cancelled."
    exit 0
}

# Restore API tools
function Restore-ApiTools {
    param($sourcePath)
    
    Write-Host ""
    Write-Host "Restoring API tools (Bruno/Postman)..."
    
    $apiSource = Join-Path $sourcePath "api-tools"
    if (-not (Test-Path $apiSource)) {
        Write-Host "  [WARN] No API tools data found in backup, skipping"
        return
    }
    
    if (Test-Path $dataDir) {
        Remove-Item "$dataDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Copy-Item -Path "$apiSource\*" -Destination $dataDir -Recurse -Force
    Write-Host "  [OK] API tools restored"
}

# Restore MySQL
function Restore-MySQL {
    param($sourcePath)
    
    Write-Host ""
    Write-Host "Restoring MySQL databases..."
    
    $mysqlSource = Join-Path $sourcePath "mysql"
    if (-not (Test-Path $mysqlSource)) {
        Write-Host "  [WARN] No MySQL data found in backup, skipping"
        return
    }
    
    # Check if MySQL container is running
    $mysqlRunning = docker ps --format '{{.Names}}' | Select-String -Pattern "^devbox-mysql$"
    if (-not $mysqlRunning) {
        Write-Host "  [WARN] MySQL container is not running, skipping"
        return
    }
    
    $dumpFiles = Get-ChildItem $mysqlSource -Filter "*.sql"
    foreach ($dumpFile in $dumpFiles) {
        $dbName = $dumpFile.BaseName
        Write-Host "  Restoring: $dbName"
        Get-Content $dumpFile.FullName | docker exec -i devbox-mysql mysql -u root 2>$null
        Write-Host "    [OK] $dbName restored"
    }
}

# Restore PostgreSQL
function Restore-PostgreSQL {
    param($sourcePath)
    
    Write-Host ""
    Write-Host "Restoring PostgreSQL databases..."
    
    $pgSource = Join-Path $sourcePath "postgresql"
    if (-not (Test-Path $pgSource)) {
        Write-Host "  [WARN] No PostgreSQL data found in backup, skipping"
        return
    }
    
    # Check if PostgreSQL container is running
    $pgRunning = docker ps --format '{{.Names}}' | Select-String -Pattern "^devbox-postgres$"
    if (-not $pgRunning) {
        Write-Host "  [WARN] PostgreSQL container is not running, skipping"
        return
    }
    
    $dumpFiles = Get-ChildItem $pgSource -Filter "*.sql"
    foreach ($dumpFile in $dumpFiles) {
        $dbName = $dumpFile.BaseName
        Write-Host "  Restoring: $dbName"
        
        # Create database if it doesn't exist
        docker exec devbox-postgres psql -U postgres -c "CREATE DATABASE ""$dbName"";" 2>$null
        
        # Restore from dump
        Get-Content $dumpFile.FullName | docker exec -i devbox-postgres psql -U postgres -d $dbName 2>$null
        Write-Host "    [OK] $dbName restored"
    }
}

# Handle restore based on selection type
if ($selectedBackup.type -eq "folder") {
    # New format: folder with subdirectories
    switch ($restoreChoice) {
        "1" {
            Restore-ApiTools -sourcePath $selectedBackup.path
            Restore-MySQL -sourcePath $selectedBackup.path
            Restore-PostgreSQL -sourcePath $selectedBackup.path
        }
        "2" {
            Restore-MySQL -sourcePath $selectedBackup.path
            Restore-PostgreSQL -sourcePath $selectedBackup.path
        }
        "3" {
            Restore-ApiTools -sourcePath $selectedBackup.path
        }
    }
}
else {
    # Old format: zip file (legacy)
    Write-Host ""
    Write-Host "Extracting legacy backup..."
    
    if (Test-Path $dataDir) {
        Remove-Item "$dataDir\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Expand-Archive -Path $selectedBackup.path -DestinationPath $dataDir -Force
    Write-Host "  [OK] Legacy backup restored"
}

Write-Host ""
Write-Host "========================================="
Write-Host "[OK] Restore completed successfully!"
Write-Host "========================================="
Write-Host ""
Write-Host "Run 'up' to start DevBox."
