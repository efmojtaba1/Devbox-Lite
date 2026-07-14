$ScriptDir = Split-Path -Parent $PSScriptRoot
$dataDir = Join-Path $ScriptDir "workspace\data"
$backupDir = Join-Path $ScriptDir "backups"
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$backupFile = Join-Path $backupDir "devbox-data-$timestamp.zip"

Write-Host ""
Write-Host "========================================="
Write-Host "Backing up DevBox Data"
Write-Host "========================================="
Write-Host ""

if (-not (Test-Path $dataDir)) {
    Write-Host "[ERROR] Data directory not found: $dataDir"
    exit 1
}

$dataItems = Get-ChildItem $dataDir -Force | Where-Object { $_.Name -ne ".gitkeep" }
if (-not $dataItems) {
    Write-Host "[ERROR] No data to backup in $dataDir"
    exit 1
}

if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    Write-Host "Created backup directory: $backupDir"
}

Write-Host "Creating backup..."
Compress-Archive -Path "$dataDir\*" -DestinationPath $backupFile -Force

if (Test-Path $backupFile) {
    $size = [math]::Round((Get-Item $backupFile).Length / 1KB, 2)
    Write-Host ""
    Write-Host "[OK] Backup created successfully!"
    Write-Host ""
    Write-Host "  Location: $backupFile"
    Write-Host "  Size: $size KB"
    Write-Host ""
    Write-Host "To restore, run: .\scripts\restore.ps1"
}
else {
    Write-Host "[ERROR] Failed to create backup"
    exit 1
}
