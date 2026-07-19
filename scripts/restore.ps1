. "$PSScriptRoot/common.ps1"

$backupDir = Join-Path $ScriptDir "backups"

Write-Host ""
Write-Host "========================================="
Write-Host "Restoring DevBox Data"
Write-Host "========================================="
Write-Host ""

if (-not (Test-Path $backupDir)) {
    Write-Host "[ERROR] No backups found in $backupDir"
    exit 1
}

# Get backup folders
$backupFolders = Get-ChildItem $backupDir -Directory | Where-Object { $_.Name -match "^devbox-backup-" } | Sort-Object LastWriteTime -Descending

if (-not $backupFolders) {
    Write-Host "[ERROR] No backup files found in $backupDir"
    exit 1
}

Write-Host "Available backups:"
Write-Host ""

$allBackups = @()
$index = 1

foreach ($folder in $backupFolders) {
    $infoFile = Join-Path $folder.FullName "backup-info.txt"
    $size = (Get-ChildItem -Path $folder.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeKB = [math]::Round($size / 1KB, 2)

    $backupInfo = ""
    if (Test-Path $infoFile) {
        $backupInfo = (Get-Content $infoFile -First 1) -replace "Backup created: ", ""
    }

    Write-Host "  $index) $($folder.Name) ($sizeKB KB) - $backupInfo"
    $allBackups += $folder
    $index++
}

Write-Host ""
$selection = Read-Host "Enter backup number to restore (1-$($allBackups.Count))"

if (-not $selection -or $selection -lt 1 -or $selection -gt $allBackups.Count) {
    Write-Host "[ERROR] Invalid selection"
    exit 1
}

$selectedBackup = $allBackups[$selection - 1]

Write-Host ""
Write-Host "========================================="
Write-Host "Select what to restore:"
Write-Host "========================================="
Write-Host ""
Write-Host "  1) All"
Write-Host "  2) Databases only"
Write-Host "  3) Bruno only"
Write-Host "  4) Projects only"
Write-Host ""

do {
    $restoreChoice = Read-Host "Select option (1-4)"
} while ($restoreChoice -notmatch "^[1-4]$")

Write-Host ""
Write-Host "Restoring from: $($selectedBackup.Name)"

$confirm = Read-Host "This will replace current data. Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Restore cancelled."
    exit 0
}

function Test-ContainerRunning {
    param([string]$Name)
    return [bool](docker ps --format '{{.Names}}' 2>$null | Select-String -Pattern "^$Name$")
}

# =====================
# MySQL
# =====================
function Restore-MySQL {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring MySQL..."

    $mysqlSource = Join-Path $SourcePath "mysql"
    if (-not (Test-Path $mysqlSource)) {
        Write-Host "  [WARN] No MySQL data found in backup, skipping"
        return
    }

    if (-not (Test-ContainerRunning "devbox-mysql")) {
        Write-Host "  [WARN] MySQL is not running, skipping"
        return
    }

    $count = 0
    $dumpFiles = Get-ChildItem $mysqlSource -Filter "*.sql"
    foreach ($dumpFile in $dumpFiles) {
        $dbName = $dumpFile.BaseName
        Write-Host "  Restoring: $dbName"
        Get-Content $dumpFile.FullName | docker exec -i devbox-mysql mysql -u root 2>$null
        Write-Host "    [OK] $dbName restored"
        $count++
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# PostgreSQL
# =====================
function Restore-PostgreSQL {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring PostgreSQL..."

    $pgSource = Join-Path $SourcePath "postgresql"
    if (-not (Test-Path $pgSource)) {
        Write-Host "  [WARN] No PostgreSQL data found in backup, skipping"
        return
    }

    if (-not (Test-ContainerRunning "devbox-postgres")) {
        Write-Host "  [WARN] PostgreSQL is not running, skipping"
        return
    }

    $count = 0
    $dumpFiles = Get-ChildItem $pgSource -Filter "*.sql"
    foreach ($dumpFile in $dumpFiles) {
        $dbName = $dumpFile.BaseName
        Write-Host "  Restoring: $dbName"
        docker exec devbox-postgres psql -U postgres -c "CREATE DATABASE ""$dbName"";" 2>$null
        Get-Content $dumpFile.FullName | docker exec -i devbox-postgres psql -U postgres -d $dbName 2>$null
        Write-Host "    [OK] $dbName restored"
        $count++
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# MongoDB
# =====================
function Restore-MongoDB {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring MongoDB..."

    $mongoSource = Join-Path $SourcePath "mongodb"
    if (-not (Test-Path $mongoSource)) {
        Write-Host "  [WARN] No MongoDB data found in backup, skipping"
        return
    }

    if (-not (Test-ContainerRunning "devbox-mongo")) {
        Write-Host "  [WARN] MongoDB is not running, skipping"
        return
    }

    $count = 0
    $archiveFiles = Get-ChildItem $mongoSource -Filter "*.archive"
    foreach ($archiveFile in $archiveFiles) {
        $dbName = $archiveFile.BaseName
        Write-Host "  Restoring: $dbName"
        Get-Content $archiveFile.FullName -Raw | docker exec -i devbox-mongo mongorestore --db $dbName --archive 2>$null
        Write-Host "    [OK] $dbName restored"
        $count++
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# MariaDB
# =====================
function Restore-MariaDB {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring MariaDB..."

    $mariadbSource = Join-Path $SourcePath "mariadb"
    if (-not (Test-Path $mariadbSource)) {
        Write-Host "  [WARN] No MariaDB data found in backup, skipping"
        return
    }

    if (-not (Test-ContainerRunning "devbox-mariadb")) {
        Write-Host "  [WARN] MariaDB is not running, skipping"
        return
    }

    $count = 0
    $dumpFiles = Get-ChildItem $mariadbSource -Filter "*.sql"
    foreach ($dumpFile in $dumpFiles) {
        $dbName = $dumpFile.BaseName
        Write-Host "  Restoring: $dbName"
        Get-Content $dumpFile.FullName | docker exec -i devbox-mariadb mariadb -u root 2>$null
        Write-Host "    [OK] $dbName restored"
        $count++
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# Redis
# =====================
function Restore-Redis {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring Redis..."

    $redisSource = Join-Path $SourcePath "redis"
    if (-not (Test-Path $redisSource)) {
        Write-Host "  [WARN] No Redis data found in backup, skipping"
        return
    }

    if (-not (Test-ContainerRunning "devbox-redis")) {
        Write-Host "  [WARN] Redis is not running, skipping"
        return
    }

    $dumpFile = Join-Path $redisSource "dump.rdb"
    if (-not (Test-Path $dumpFile)) {
        Write-Host "  [WARN] No dump.rdb found, skipping"
        return
    }

    # Stop Redis, copy dump, restart
    Write-Host "  Stopping Redis..."
    docker exec devbox-redis redis-cli SHUTDOWN NOSAVE 2>$null
    Start-Sleep -Seconds 1

    Write-Host "  Copying dump.rdb..."
    docker cp $dumpFile devbox-redis:/data/dump.rdb 2>$null

    Write-Host "  Starting Redis..."
    docker start devbox-redis 2>$null
    Start-Sleep -Seconds 1

    if (Test-ContainerRunning "devbox-redis") {
        Write-Host "  [OK] Redis restored"
    } else {
        Write-Host "  [WARN] Redis may need manual restart"
    }
}

# =====================
# Bruno (named volumes)
# =====================
function Restore-Bruno {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring Bruno..."

    $brunoSource = Join-Path $SourcePath "bruno"
    if (-not (Test-Path $brunoSource)) {
        Write-Host "  [WARN] No Bruno data found in backup, skipping"
        return
    }

    # Restore bruno-config volume
    $configBackup = Join-Path $brunoSource "bruno-config.tar.gz"
    if (Test-Path $configBackup) {
        Write-Host "  Restoring bruno-config..."
        docker run --rm -v devbox_bruno-config:/data -v "${brunoSource}:/backup:ro" alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/bruno-config.tar.gz -C /data" 2>$null
        Write-Host "    [OK] bruno-config restored"
    }

    # Restore bruno-collections volume
    $collectionsBackup = Join-Path $brunoSource "bruno-collections.tar.gz"
    if (Test-Path $collectionsBackup) {
        Write-Host "  Restoring bruno-collections..."
        docker run --rm -v devbox_bruno-collections:/data -v "${brunoSource}:/backup:ro" alpine sh -c "rm -rf /data/* /data/..?* /data/.[!.]* 2>/dev/null; tar xzf /backup/bruno-collections.tar.gz -C /data" 2>$null
        Write-Host "    [OK] bruno-collections restored"
    }
}

# =====================
# Projects
# =====================
function Restore-Projects {
    param($SourcePath)

    Write-Host ""
    Write-Host "Restoring projects..."

    $projectsSource = Join-Path $SourcePath "projects"
    if (-not (Test-Path $projectsSource)) {
        Write-Host "  [WARN] No project data found in backup, skipping"
        return
    }

    $workspaceDir = Join-Path $ScriptDir "workspace"

    # Find available project archives
    $archives = Get-ChildItem $projectsSource -Filter "*.tar.gz"
    if ($archives.Count -eq 0) {
        Write-Host "  [WARN] No project archives found, skipping"
        return
    }

    # Show project selection menu
    Write-Host ""
    Write-Host "========================================="
    Write-Host "Available projects in backup:"
    Write-Host "========================================="
    Write-Host ""

    for ($i = 0; $i -lt $archives.Count; $i++) {
        $size = [math]::Round($archives[$i].Length / 1KB, 2)
        # Remove .tar.gz from filename to get project name
        $projName = $archives[$i].Name -replace '\.tar\.gz$', ''
        Write-Host "  $($i + 1)) $projName ($size KB)"
    }

    Write-Host ""
    Write-Host "  a) All projects"
    Write-Host ""

    # Get user selection
    $selected = @()
    while ($true) {
        $choice = Read-Host "Select project (1-$($archives.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $archives
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $archives.Count) {
            $selected += $archives[[int]$choice - 1]
            break
        }
        Write-Host "Invalid choice. Enter 1-$($archives.Count) or a."
    }

    # Restore selected projects
    $count = 0
    foreach ($archive in $selected) {
        # Remove .tar.gz from filename to get project name
        $name = $archive.Name -replace '\.tar\.gz$', ''
        Write-Host "  Restoring: $name"

        $projectDir = Join-Path $workspaceDir $name
        if (Test-Path $projectDir) {
            $confirm = Read-Host "    Project '$name' exists. Overwrite? (y/N)"
            if ($confirm -ne "y" -and $confirm -ne "Y") {
                Write-Host "    [SKIP] $name"
                continue
            }
            Remove-Item $projectDir -Recurse -Force
        }

        tar xzf $archive.FullName -C $workspaceDir 2>$null
        if (Test-Path $projectDir) {
            Write-Host "    [OK] $name restored"
            $count++
        }
    }
    Write-Host "  Total: $count project(s)"
}

# =====================
# Execute restore
# =====================
switch ($restoreChoice) {
    "1" {
        Restore-MySQL -SourcePath $selectedBackup.FullName
        Restore-PostgreSQL -SourcePath $selectedBackup.FullName
        Restore-MongoDB -SourcePath $selectedBackup.FullName
        Restore-MariaDB -SourcePath $selectedBackup.FullName
        Restore-Redis -SourcePath $selectedBackup.FullName
        Restore-Bruno -SourcePath $selectedBackup.FullName
        Restore-Projects -SourcePath $selectedBackup.FullName
    }
    "2" {
        Restore-MySQL -SourcePath $selectedBackup.FullName
        Restore-PostgreSQL -SourcePath $selectedBackup.FullName
        Restore-MongoDB -SourcePath $selectedBackup.FullName
        Restore-MariaDB -SourcePath $selectedBackup.FullName
        Restore-Redis -SourcePath $selectedBackup.FullName
    }
    "3" {
        Restore-Bruno -SourcePath $selectedBackup.FullName
    }
    "4" {
        Restore-Projects -SourcePath $selectedBackup.FullName
    }
}

Write-Host ""
Write-Host "========================================="
Write-Host "[OK] Restore completed successfully!"
Write-Host "========================================="
Write-Host ""
Write-Host "Run 'up' to start DevBox."
