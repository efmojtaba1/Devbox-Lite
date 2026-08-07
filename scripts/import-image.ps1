param(
    [string]$InputPath,
    [string]$ComposeFile = "docker/compose/docker-compose.yml"
)

$ErrorActionPreference = "Stop"

if (-not $InputPath) {
    $InputPath = Read-Host "Package directory or tar.gz to import"
    if (-not $InputPath) {
        Write-Error "No input provided. Aborting."
        exit 1
    }
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
    Write-Error "Usage: import-image <package-dir-or-tar.gz> [compose-file]"
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
