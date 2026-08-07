param(
    [string]$InputPath,
    [string]$ComposeFile = "docker/compose/docker-compose.yml"
)

$ErrorActionPreference = "Stop"
$DefaultInput = "D:\devbox-image"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Import Configuration" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "1) Use default path/directory ($DefaultInput)" -ForegroundColor White
Write-Host "2) Enter custom path or archive (.tar.gz)" -ForegroundColor White
$choice = Read-Host "Choose an option [1/2] (default: 1)"

if ($choice -eq "2") {
    Write-Host "  [Tip] Example format: D:\devbox-image or D:\backup.tar.gz" -ForegroundColor Yellow
    $customInput = Read-Host "  Enter path"
    $InputPath = if ($customInput) { $customInput } else { $DefaultInput }
} else {
    $InputPath = $DefaultInput
}

$WorkDir = ""
$TmpDir = ""

if ((Test-Path $InputPath) -and ($InputPath -like "*.tar.gz" -or $InputPath -like "*.tgz")) {
    $TmpDir = Join-Path $env:TEMP ([Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null
    Write-Host "[import] Extracting archive $InputPath -> $TmpDir"
    tar xzf $InputPath -C $TmpDir
    $WorkDir = $TmpDir
} elseif (Test-Path $InputPath -PathType Container) {
    $WorkDir = (Get-Item $InputPath).FullName
} else {
    Write-Error "Error: Path or archive not found: $InputPath"
    exit 1
}

$ImageTar = Join-Path $WorkDir "image.tar"
if (Test-Path $ImageTar) {
    Write-Host "[import] Loading image from $ImageTar"
    docker load -i $ImageTar
} else {
    Write-Host "[warn] image.tar not found in package; skipping docker load" -ForegroundColor Yellow
}

Get-ChildItem -Path $WorkDir -Filter "vol-*.tar.gz" | ForEach-Object {
    $fname = $_.Name
    $volname = $fname -replace '^vol-', '' -replace '\.tar\.gz$', ''
    Write-Host "[import] Restoring volume: $volname from $fname"

    $existingVolumes = docker volume ls -q
    if ($existingVolumes -notcontains $volname) {
        docker volume create $volname | Out-Null
    }
    docker run --rm -i -v "${volname}:/volume" -v "${WorkDir}:/backup" alpine sh -c "cd /volume || mkdir -p /volume; tar xzf /backup/$fname -C /volume || true"
}

if (Test-Path $ComposeFile) {
    Write-Host "[ok] Volumes restored. Starting compose: $ComposeFile" -ForegroundColor Green
    docker compose -f $ComposeFile up -d
    Write-Host "[ok] docker compose up started" -ForegroundColor Green
} else {
    Write-Host "[warn] Compose file $ComposeFile not found. Start containers manually." -ForegroundColor Yellow
}

Write-Host "[done] Import finished." -ForegroundColor Green
