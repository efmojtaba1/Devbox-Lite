. "$PSScriptRoot/common.ps1"

$backupDir = Join-Path $ScriptDir "backups"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupName = "devbox-backup-$timestamp"
$backupPath = Join-Path $backupDir $backupName

function Initialize-BackupDir {
    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }
}

function Test-ContainerRunning {
    param([string]$Name)
    return [bool](docker ps --format '{{.Names}}' 2>$null | Select-String -Pattern "^$Name$")
}

# =====================
# MySQL
# =====================
function Backup-MySQL {
    Write-Host ""
    Write-Host "Backing up MySQL..."

    if (-not (Test-ContainerRunning "devbox-mysql")) {
        Write-Host "  [WARN] MySQL is not running, skipping"
        return
    }

    $databases = docker exec devbox-mysql mysql -u root -e "SHOW DATABASES;" 2>$null |
        Where-Object { $_ -notmatch "^(Database|information_schema|performance_schema|mysql|sys)$" }

    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }

    $dbList = @()
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) { $dbList += $db }
    }

    # Show selection menu
    Write-Host ""
    Write-Host "  MySQL databases:"
    for ($i = 0; $i -lt $dbList.Count; $i++) {
        Write-Host "    $($i + 1)) $($dbList[$i])"
    }
    Write-Host ""
    Write-Host "    a) All databases"
    Write-Host ""

    $selected = @()
    while ($true) {
        $choice = Read-Host "    Select (1-$($dbList.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $dbList
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $dbList.Count) {
            $selected += $dbList[[int]$choice - 1]
            break
        }
        Write-Host "    Invalid choice."
    }

    $mysqlDir = Join-Path $backupPath "mysql"
    New-Item -ItemType Directory -Path $mysqlDir -Force | Out-Null

    $count = 0
    foreach ($db in $selected) {
        $dumpFile = Join-Path $mysqlDir "$db.sql"
        Write-Host "  Dumping: $db"
        docker exec devbox-mysql mysqldump -u root --databases $db 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
        if (Test-Path $dumpFile) {
            $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
            Write-Host "    [OK] $db ($size KB)"
            $count++
        }
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# PostgreSQL
# =====================
function Backup-PostgreSQL {
    Write-Host ""
    Write-Host "Backing up PostgreSQL..."

    if (-not (Test-ContainerRunning "devbox-postgres")) {
        Write-Host "  [WARN] PostgreSQL is not running, skipping"
        return
    }

    $databases = docker exec devbox-postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres');" 2>$null

    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }

    $dbList = @()
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) { $dbList += $db }
    }

    # Show selection menu
    Write-Host ""
    Write-Host "  PostgreSQL databases:"
    for ($i = 0; $i -lt $dbList.Count; $i++) {
        Write-Host "    $($i + 1)) $($dbList[$i])"
    }
    Write-Host ""
    Write-Host "    a) All databases"
    Write-Host ""

    $selected = @()
    while ($true) {
        $choice = Read-Host "    Select (1-$($dbList.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $dbList
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $dbList.Count) {
            $selected += $dbList[[int]$choice - 1]
            break
        }
        Write-Host "    Invalid choice."
    }

    $pgDir = Join-Path $backupPath "postgresql"
    New-Item -ItemType Directory -Path $pgDir -Force | Out-Null

    $count = 0
    foreach ($db in $selected) {
        $dumpFile = Join-Path $pgDir "$db.sql"
        Write-Host "  Dumping: $db"
        docker exec devbox-postgres pg_dump -U postgres $db 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
        if (Test-Path $dumpFile) {
            $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
            Write-Host "    [OK] $db ($size KB)"
            $count++
        }
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# MongoDB
# =====================
function Backup-MongoDB {
    Write-Host ""
    Write-Host "Backing up MongoDB..."

    if (-not (Test-ContainerRunning "devbox-mongo")) {
        Write-Host "  [WARN] MongoDB is not running, skipping"
        return
    }

    $databases = docker exec devbox-mongo mongosh --quiet --eval "db.adminCommand('listDatabases').databases.map(d => d.name).filter(n => !['admin','config','local'].includes(n)).join('\n')" 2>$null

    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }

    $dbList = @()
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) { $dbList += $db }
    }

    # Show selection menu
    Write-Host ""
    Write-Host "  MongoDB databases:"
    for ($i = 0; $i -lt $dbList.Count; $i++) {
        Write-Host "    $($i + 1)) $($dbList[$i])"
    }
    Write-Host ""
    Write-Host "    a) All databases"
    Write-Host ""

    $selected = @()
    while ($true) {
        $choice = Read-Host "    Select (1-$($dbList.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $dbList
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $dbList.Count) {
            $selected += $dbList[[int]$choice - 1]
            break
        }
        Write-Host "    Invalid choice."
    }

    $mongoDir = Join-Path $backupPath "mongodb"
    New-Item -ItemType Directory -Path $mongoDir -Force | Out-Null

    $count = 0
    foreach ($db in $selected) {
        $dumpFile = Join-Path $mongoDir "$db.archive"
        Write-Host "  Dumping: $db"
        docker exec devbox-mongo mongodump --db $db --archive 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
        if (Test-Path $dumpFile) {
            $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
            Write-Host "    [OK] $db ($size KB)"
            $count++
        }
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# MariaDB
# =====================
function Backup-MariaDB {
    Write-Host ""
    Write-Host "Backing up MariaDB..."

    if (-not (Test-ContainerRunning "devbox-mariadb")) {
        Write-Host "  [WARN] MariaDB is not running, skipping"
        return
    }

    $databases = docker exec devbox-mariadb mariadb -u root -e "SHOW DATABASES;" 2>$null |
        Where-Object { $_ -notmatch "^(Database|information_schema|performance_schema|mysql|sys)$" }

    if (-not $databases) {
        Write-Host "  [WARN] No user databases found, skipping"
        return
    }

    $dbList = @()
    foreach ($db in $databases) {
        $db = $db.Trim()
        if ($db) { $dbList += $db }
    }

    # Show selection menu
    Write-Host ""
    Write-Host "  MariaDB databases:"
    for ($i = 0; $i -lt $dbList.Count; $i++) {
        Write-Host "    $($i + 1)) $($dbList[$i])"
    }
    Write-Host ""
    Write-Host "    a) All databases"
    Write-Host ""

    $selected = @()
    while ($true) {
        $choice = Read-Host "    Select (1-$($dbList.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $dbList
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $dbList.Count) {
            $selected += $dbList[[int]$choice - 1]
            break
        }
        Write-Host "    Invalid choice."
    }

    $mariadbDir = Join-Path $backupPath "mariadb"
    New-Item -ItemType Directory -Path $mariadbDir -Force | Out-Null

    $count = 0
    foreach ($db in $selected) {
        $dumpFile = Join-Path $mariadbDir "$db.sql"
        Write-Host "  Dumping: $db"
        docker exec devbox-mariadb mariadb-dump -u root --databases $db 2>$null | Out-File -FilePath $dumpFile -Encoding UTF8
        if (Test-Path $dumpFile) {
            $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
            Write-Host "    [OK] $db ($size KB)"
            $count++
        }
    }
    Write-Host "  Total: $count database(s)"
}

# =====================
# Redis
# =====================
function Backup-Redis {
    Write-Host ""
    Write-Host "Backing up Redis..."

    if (-not (Test-ContainerRunning "devbox-redis")) {
        Write-Host "  [WARN] Redis is not running, skipping"
        return
    }

    $redisDir = Join-Path $backupPath "redis"
    New-Item -ItemType Directory -Path $redisDir -Force | Out-Null

    # Trigger background save
    docker exec devbox-redis redis-cli BGSAVE 2>$null | Out-Null
    Start-Sleep -Seconds 2

    # Copy dump.rdb
    $dumpFile = Join-Path $redisDir "dump.rdb"
    docker cp devbox-redis:/data/dump.rdb $dumpFile 2>$null

    if (Test-Path $dumpFile) {
        $size = [math]::Round((Get-Item $dumpFile).Length / 1KB, 2)
        Write-Host "  [OK] dump.rdb ($size KB)"
    } else {
        Write-Host "  [WARN] No Redis data found"
    }
}

# =====================
# Bruno (named volumes)
# =====================
function Backup-Bruno {
    Write-Host ""
    Write-Host "Backing up Bruno..."

    $brunoDir = Join-Path $backupPath "bruno"
    New-Item -ItemType Directory -Path $brunoDir -Force | Out-Null

    # Backup bruno-config volume
    $configExists = docker volume inspect devbox_bruno-config 2>$null
    if ($configExists) {
        Write-Host "  Backing up bruno-config..."
        $backupFile = Join-Path $brunoDir "bruno-config.tar.gz"
        docker run --rm -v devbox_bruno-config:/data:ro -v "${brunoDir}:/backup" alpine tar czf /backup/bruno-config.tar.gz -C /data . 2>$null
        if (Test-Path $backupFile) {
            $size = [math]::Round((Get-Item $backupFile).Length / 1KB, 2)
            Write-Host "    [OK] bruno-config ($size KB)"
        }
    } else {
        Write-Host "  [WARN] bruno-config volume not found, skipping"
    }

    # Backup bruno-collections volume
    $collectionsExists = docker volume inspect devbox_bruno-collections 2>$null
    if ($collectionsExists) {
        Write-Host "  Backing up bruno-collections..."
        $backupFile = Join-Path $brunoDir "bruno-collections.tar.gz"
        docker run --rm -v devbox_bruno-collections:/data:ro -v "${brunoDir}:/backup" alpine tar czf /backup/bruno-collections.tar.gz -C /data . 2>$null
        if (Test-Path $backupFile) {
            $size = [math]::Round((Get-Item $backupFile).Length / 1KB, 2)
            Write-Host "    [OK] bruno-collections ($size KB)"
        }
    } else {
        Write-Host "  [WARN] bruno-collections volume not found, skipping"
    }
}

# =====================
# Projects (excluding generated folders)
# =====================

# Detect project type (same as setup-deps.sh)
function Get-ProjectType {
    param([string]$Dir)

    if (Test-Path "$Dir\artisan") { return "laravel" }
    if (Test-Path "$Dir\manage.py") { return "django" }
    if (Get-ChildItem "$Dir\fastapi*" -ErrorAction SilentlyContinue) { return "fastapi" }
    if (Test-Path "$Dir\Gemfile") { return "rails" }
    if (Test-Path "$Dir\go.mod") { return "go" }
    if (Test-Path "$Dir\mix.exs") { return "phoenix" }
    $hasNextConfig = Get-ChildItem "$Dir\next.config*" -ErrorAction SilentlyContinue
    $hasDotNext = Test-Path "$Dir\.next"
    if ($hasNextConfig -or $hasDotNext) { return "nextjs" }
    if (Test-Path "$Dir\pubspec.yaml") { return "flutter" }
    if (Test-Path "$Dir\package.json") {
        $content = Get-Content "$Dir\package.json" -Raw -ErrorAction SilentlyContinue
        if ($content -match '"react"') { return "react" }
        return "express"
    }
    $hasRequirements = Test-Path "$Dir\requirements.txt"
    $hasPyproject = Test-Path "$Dir\pyproject.toml"
    $hasSetupPy = Test-Path "$Dir\setup.py"
    $hasPipfile = Test-Path "$Dir\Pipfile"
    if ($hasRequirements -or $hasPyproject -or $hasSetupPy -or $hasPipfile) { return "python" }
    if (Get-ChildItem "$Dir\*.py" -ErrorAction SilentlyContinue) { return "python" }
    return ""
}

# Get project type description
function Get-ProjectDesc {
    param([string]$Type)

    $descMap = @{
        "laravel" = "Laravel (PHP)"
        "django"  = "Django (Python)"
        "fastapi" = "FastAPI (Python)"
        "rails"   = "Rails (Ruby)"
        "go"      = "Go"
        "phoenix" = "Phoenix (Elixir)"
        "nextjs"  = "Next.js (React)"
        "flutter" = "Flutter (Dart)"
        "react"   = "React (JavaScript)"
        "express" = "Express (Node.js)"
        "python"  = "Python"
    }
    return $descMap[$Type]
}

function Backup-Projects {
    Write-Host ""
    Write-Host "Backing up projects..."

    $workspaceDir = Join-Path $ScriptDir "workspace"
    $projectsDir = Join-Path $backupPath "projects"

    if (-not (Test-Path $workspaceDir)) {
        Write-Host "  [WARN] Workspace not found, skipping"
        return
    }

    # Detect all projects
    $projects = @()
    Get-ChildItem $workspaceDir -Directory | Where-Object {
        $_.Name -notin @("data", "scripts", "prebuilt", ".git") -and
        (Get-ChildItem $_.FullName -Force | Where-Object { $_.Name -ne ".gitkeep" }).Count -gt 0
    } | ForEach-Object {
        $ptype = Get-ProjectType $_.FullName
        if ($ptype) {
            $projects += @{ name = $_.Name; type = $ptype }
        }
    }

    if ($projects.Count -eq 0) {
        Write-Host "  [WARN] No projects found, skipping"
        return
    }

    # Show project selection menu
    Write-Host ""
    Write-Host "========================================="
    Write-Host "Detected projects:"
    Write-Host "========================================="
    Write-Host ""

    for ($i = 0; $i -lt $projects.Count; $i++) {
        $desc = Get-ProjectDesc $projects[$i].type
        Write-Host "  $($i + 1)) $($projects[$i].name) ($desc)"
    }

    Write-Host ""
    Write-Host "  a) All projects"
    Write-Host ""

    # Get user selection
    $selected = @()
    while ($true) {
        $choice = Read-Host "Select project (1-$($projects.Count) or a)"
        if ($choice -eq "a" -or $choice -eq "A") {
            $selected = $projects
            break
        }
        if ($choice -match "^\d+$" -and [int]$choice -ge 1 -and [int]$choice -le $projects.Count) {
            $selected += $projects[[int]$choice - 1]
            break
        }
        Write-Host "Invalid choice. Enter 1-$($projects.Count) or a."
    }

    # Create projects directory
    New-Item -ItemType Directory -Path $projectsDir -Force | Out-Null

    # Exclusion patterns
    $excludes = @(
        "node_modules", "vendor", "venv", ".venv", "__pycache__",
        ".next", ".nuxt", "dist", "build", ".git", ".cache",
        ".pytest_cache", "*.pyc", ".mypy_cache", ".tox",
        "coverage", ".coverage", "htmlcov", ".env.local", ".env.production"
    )

    $count = 0
    foreach ($project in $selected) {
        Write-Host "  Backing up: $($project.name)"

        # Build tar command with excludes
        $excludeArgs = ($excludes | ForEach-Object { "--exclude=$_" }) -join " "
        $archiveFile = Join-Path $projectsDir "$($project.name).tar.gz"

        # Use tar with excludes
        $workspaceParent = Split-Path $workspaceDir -Parent
        cmd /c "cd `"$workspaceParent`" && tar czf `"$archiveFile`" $excludeArgs `"$($project.name)`"" 2>$null

        if (Test-Path $archiveFile) {
            $size = [math]::Round((Get-Item $archiveFile).Length / 1KB, 2)
            Write-Host "    [OK] $($project.name) ($size KB)"
            $count++
        }
    }
    Write-Host "  Total: $count project(s)"
}

# =====================
# Validate backup
# =====================
function Test-Backup {
    Write-Host ""
    Write-Host "Validating backup..."

    $errors = 0

    # Check SQL files
    foreach ($dir in @("mysql", "postgresql", "mariadb")) {
        $dirPath = Join-Path $backupPath $dir
        if (Test-Path $dirPath) {
            Get-ChildItem $dirPath -Filter "*.sql" | ForEach-Object {
                if ($_.Length -eq 0) {
                    Write-Host "  [ERROR] Empty file: $($_.Name)"
                    $errors++
                }
            }
        }
    }

    # Check tar.gz files
    $brunoDir = Join-Path $backupPath "bruno"
    if (Test-Path $brunoDir) {
        Get-ChildItem $brunoDir -Filter "*.tar.gz" | ForEach-Object {
            $testResult = docker run --rm -v "${brunoDir}:/backup:ro" alpine tar tzf "/backup/$($_.Name)" 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  [ERROR] Corrupted archive: $($_.Name)"
                $errors++
            }
        }
    }

    # Check Redis dump
    $redisDump = Join-Path $backupPath "redis\dump.rdb"
    if ((Test-Path $redisDump) -and (Get-Item $redisDump).Length -eq 0) {
        Write-Host "  [ERROR] Empty Redis dump"
        $errors++
    }

    if ($errors -eq 0) {
        Write-Host "  [OK] All files valid"
    } else {
        Write-Host "  [WARN] $errors file(s) have issues"
    }
}

# =====================
# Cleanup old backups
# =====================
function Remove-OldBackups {
    Write-Host ""
    Write-Host "Checking for old backups..."

    $backups = Get-ChildItem $backupDir -Directory | Where-Object { $_.Name -match "^devbox-backup-" } | Sort-Object LastWriteTime -Descending
    $count = $backups.Count

    if ($count -le 5) {
        Write-Host "  $count backup(s) found, no cleanup needed (minimum: 5)"
        return
    }

    Write-Host "  $count backup(s) found, checking for old ones..."

    # Always keep 5 most recent, delete others older than 30 days
    $removed = 0
    $cutoffDate = (Get-Date).AddDays(-30)

    for ($i = 5; $i -lt $backups.Count; $i++) {
        $backup = $backups[$i]
        if ($backup.LastWriteTime -lt $cutoffDate) {
            Write-Host "    Removing: $($backup.Name) (older than 30 days)"
            Remove-Item $backup.FullName -Recurse -Force
            $removed++
        }
    }

    if ($removed -eq 0) {
        Write-Host "  No old backups to remove"
    } else {
        Write-Host "  Removed $removed old backup(s)"
    }
}

# =====================
# Menu
# =====================
Write-Host ""
Write-Host "========================================="
Write-Host "Select what to backup:"
Write-Host "========================================="
Write-Host ""
Write-Host "  1) All"
Write-Host "  2) Databases only (MySQL + PostgreSQL + MongoDB + MariaDB + Redis)"
Write-Host "  3) Bruno only"
Write-Host "  4) Projects only"
Write-Host ""

do {
    $choice = Read-Host "Select option (1-4)"
} while ($choice -notmatch "^[1-4]$")

Write-Host ""
Write-Host "========================================="
Write-Host "Backing up DevBox Data"
Write-Host "========================================="

Initialize-BackupDir

switch ($choice) {
    "1" { Backup-MySQL; Backup-PostgreSQL; Backup-MongoDB; Backup-MariaDB; Backup-Redis; Backup-Bruno; Backup-Projects }
    "2" { Backup-MySQL; Backup-PostgreSQL; Backup-MongoDB; Backup-MariaDB; Backup-Redis }
    "3" { Backup-Bruno }
    "4" { Backup-Projects }
}

# Validate and cleanup
Test-Backup
Remove-OldBackups

# Create info file
$infoFile = Join-Path $backupPath "backup-info.txt"
@"
Backup created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Selection: $choice
Timestamp: $timestamp
"@ | Out-File -FilePath $infoFile -Encoding UTF8

# Calculate size and count items
$totalSize = (Get-ChildItem -Path $backupPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalSizeKB = [math]::Round($totalSize / 1KB, 2)
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

$items = 0
foreach ($dir in @("mysql", "postgresql", "mariadb")) {
    $dirPath = Join-Path $backupPath $dir
    if (Test-Path $dirPath) {
        $items += (Get-ChildItem $dirPath -Filter "*.sql").Count
    }
}
$mongoPath = Join-Path $backupPath "mongodb"
if (Test-Path $mongoPath) {
    $items += (Get-ChildItem $mongoPath -Filter "*.archive").Count
}
$redisDump = Join-Path $backupPath "redis\dump.rdb"
if (Test-Path $redisDump) { $items++ }
$brunoDir = Join-Path $backupPath "bruno"
if (Test-Path $brunoDir) {
    $items += (Get-ChildItem $brunoDir -Filter "*.tar.gz").Count
}
$projectsDir = Join-Path $backupPath "projects"
if (Test-Path $projectsDir) {
    $items += (Get-ChildItem $projectsDir -Filter "*.tar.gz").Count
}

Write-Host ""
Write-Host "========================================="
Write-Host "[OK] Backup completed successfully!"
Write-Host "========================================="
Write-Host ""
Write-Host "  Location: $backupPath"
Write-Host "  Size: $totalSizeKB KB ($totalSizeMB MB)"
Write-Host "  Items: $items file(s)"
Write-Host ""
Write-Host "To restore, run: .\scripts\restore"
