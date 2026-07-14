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

$backups = Get-ChildItem $backupDir -Filter "devbox-data-*.zip" | Sort-Object LastWriteTime -Descending

if (-not $backups) {
    Write-Host "[ERROR] No backup files found in $backupDir"
    exit 1
}

Write-Host "Available backups:"
Write-Host ""
for ($i = 0; $i -lt $backups.Count; $i++) {
    $size = [math]::Round($backups[$i].Length / 1KB, 2)
    Write-Host "  $($i + 1). $($backups[$i].Name) ($size KB)"
}
Write-Host ""

$selection = Read-Host "Enter backup number to restore (1-$($backups.Count))"

if (-not $selection -or $selection -lt 1 -or $selection -gt $backups.Count) {
    Write-Host "[ERROR] Invalid selection"
    exit 1
}

$selectedBackup = $backups[$selection - 1]
Write-Host ""
Write-Host "Restoring from: $($selectedBackup.Name)"

$confirm = Read-Host "This will replace current data. Continue? (y/N)"
if ($confirm -ne "y" -and $confirm -ne "Y") {
    Write-Host "Restore cancelled."
    exit 0
}

Write-Host ""
Write-Host "Stopping container..."
docker compose -f $ComposeFile down 2>$null

if (Test-Path $dataDir) {
    Remove-Item "$dataDir\*" -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "Extracting backup..."
Expand-Archive -Path $selectedBackup.FullName -DestinationPath $dataDir -Force

Write-Host ""
Write-Host "[OK] Data restored successfully!"
Write-Host ""
Write-Host "Run '.\scripts\up.ps1' to start DevBox."
