param(
    [string]$InputPath,
    [string]$TargetProj
)

$ErrorActionPreference = "Stop"

function Write-Info($Message) {
    Write-Host $Message -ForegroundColor Cyan
}

function Write-Ok($Message) {
    Write-Host $Message -ForegroundColor Green
}

function Write-Warn($Message) {
    Write-Host $Message -ForegroundColor Yellow
}

function Fail($Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " DevBox Lite - Offline DevBox Restore" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if (-not $InputPath) {
    $InputPath = Join-Path (Get-Location).Path ".."
}

if (-not $TargetProj) {
    $TargetProj = Read-Host "Enter destination path for project setup [Default: D:\devbox-project]"
    if (-not $TargetProj) {
        $TargetProj = "D:\devbox-project"
    }
}

$InputPath = [System.IO.Path]::GetFullPath($InputPath)
$ProjectRoot = [System.IO.Path]::GetFullPath($TargetProj)

if (-not (Test-Path $InputPath)) {
    Fail "Offline package path not found: $InputPath"
}

if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    Fail "Docker CLI is not available. Docker Desktop must be installed and running before restore."
}

try {
    docker version *> $null
    if ($LASTEXITCODE -ne 0) {
        Fail "Docker Engine is not ready."
    }
}
catch {
    Fail "Docker Engine is not ready."
}

$ManifestPath = Join-Path $InputPath "manifest.txt"
if (-not (Test-Path $ManifestPath)) {
    Fail "manifest.txt not found in package: $ManifestPath"
}

$Manifest = @{}
$Volumes = @{}

$section = ""
foreach ($line in Get-Content -LiteralPath $ManifestPath) {
    $trimmed = $line.Trim()

    if (-not $trimmed) {
        continue
    }

    if ($trimmed -match '^\[(.+)\]$') {
        $section = $Matches[1]
        continue
    }

    if ($trimmed -match '^([^:]+):(.*)$') {
        $key = $Matches[1]
        $value = $Matches[2]

        if ($section -eq "volumes") {
            $Volumes[$key] = $value
        }
        else {
            $Manifest[$key] = $value
        }
    }
}

$ImageName = $Manifest["image"]
$ComposeProject = $Manifest["compose_project"]

if (-not $ImageName) {
    Fail "Image name is missing from manifest.txt"
}

if (-not $ComposeProject) {
    $ComposeProject = "devbox"
}

if (-not (Test-Path $ProjectRoot)) {
    New-Item -ItemType Directory -Force -Path $ProjectRoot | Out-Null
}

Write-Info "[restore] Package: $InputPath"
Write-Info "[restore] Project: $ProjectRoot"
Write-Info "[restore] Image:   $ImageName"
Write-Info "[restore] Compose: $ComposeProject"

# ------------------------------------------------------------
# Helper: verify SHA256 if the manifest contains one.
# ------------------------------------------------------------
function Get-Sha256($Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "File not found for checksum verification: $Path"
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try {
            $hash = $sha256.ComputeHash($stream)
        }
        finally {
            $stream.Dispose()
        }
    }
    finally {
        $sha256.Dispose()
    }

    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Verify-Sha256($Path, $Expected) {
    if (-not $Expected) {
        return
    }

    $Actual = Get-Sha256 $Path
    $ExpectedNormalized = $Expected.ToLowerInvariant()

    if ($Actual -ne $ExpectedNormalized) {
        Fail "SHA256 mismatch for $(Split-Path $Path -Leaf). Expected $ExpectedNormalized but got $Actual"
    }

    Write-Ok "  [OK] SHA256 $(Split-Path $Path -Leaf)"
}

# ------------------------------------------------------------
# Verify package archives before modifying the destination.
# ------------------------------------------------------------
Write-Info "[1/5] Verifying package archives..."

$ImageTar = Join-Path $InputPath "image.tar"
$ProjectSrcTar = Join-Path $InputPath "project-src.tar.gz"

Verify-Sha256 $ImageTar $Manifest["image_sha256"]
Verify-Sha256 $ProjectSrcTar $Manifest["project-src.tar.gz"]

foreach ($logical in $Volumes.Keys) {
    $Archive = Join-Path $InputPath "volumes\vol-$logical.tar.gz"
    if (-not (Test-Path $Archive)) {
        Fail "Volume archive is missing: $Archive"
    }

    $Expected = $Manifest["volumes/vol-$logical.tar.gz"]
    Verify-Sha256 $Archive $Expected
}

$PrebuiltTar = Join-Path $InputPath "prebuilt.tar.gz"
if (Test-Path $PrebuiltTar) {
    Verify-Sha256 $PrebuiltTar $Manifest["prebuilt.tar.gz"]
}

# ------------------------------------------------------------
# Restore source.
# ------------------------------------------------------------
Write-Info "[2/5] Restoring project source..."

tar.exe -xzf $ProjectSrcTar -C $ProjectRoot
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to extract project-src.tar.gz"
}

Write-Ok "  [OK] Project source restored."

if (Test-Path $PrebuiltTar) {
    Write-Info "[restore] Restoring prebuilt directory..."
    tar.exe -xzf $PrebuiltTar -C $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to extract prebuilt.tar.gz"
    }

    Write-Ok "  [OK] prebuilt restored."
}

# ------------------------------------------------------------
# Load DevBox image.
# ------------------------------------------------------------
Write-Info "[3/5] Loading DevBox Docker image..."

docker.exe load -i $ImageTar
if ($LASTEXITCODE -ne 0) {
    Fail "docker load failed."
}

docker.exe image inspect $ImageName *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Loaded image could not be found as '$ImageName'."
}

Write-Ok "  [OK] Docker image loaded: $ImageName"

# ------------------------------------------------------------
# Restore volumes.
# ------------------------------------------------------------
Write-Info "[4/5] Restoring Docker volumes..."

# تعریف مسیر دقیق پوشه volumes
$VolumesPath = Join-Path $InputPath "volumes"

foreach ($logical in $Volumes.Keys) {
    $VolumeName = $Volumes[$logical]
    # اصلاح مسیر آرشیو برای خواندن از پوشه volumes
    $Archive = Join-Path $VolumesPath "vol-$logical.tar.gz"

    if (-not (Test-Path $Archive)) {
        Fail "Volume archive is missing: $Archive"
    }

    if (-not $VolumeName) {
        Fail "Empty Docker volume name for logical volume '$logical'"
    }

    docker.exe volume inspect $VolumeName *> $null
    if ($LASTEXITCODE -ne 0) {
        docker.exe volume create $VolumeName *> $null
        if ($LASTEXITCODE -ne 0) {
            Fail "Could not create Docker volume '$VolumeName'"
        }
    }

    Write-Info "  Restoring $logical -> $VolumeName"

    $ArchiveName = Split-Path $Archive -Leaf

    $RestoreCommand = "rm -rf /restore-target/* /restore-target/.[!.]* /restore-target/..?* 2>/dev/null || true; tar xzf /backup/$ArchiveName -C /restore-target"

    # اتصال مستقیم پوشه volumes به جای کل ریشه پکیج به مسیر /backup در کانتینر
    docker.exe run --rm `
        -v "${VolumeName}:/restore-target" `
        -v "${VolumesPath}:/backup:ro" `
        $ImageName `
        sh -c $RestoreCommand

    if ($LASTEXITCODE -ne 0) {
        Fail "Failed to restore Docker volume '$VolumeName'"
    }

    Write-Ok "  [OK] $VolumeName"
}

# ------------------------------------------------------------
# Start Compose using the original Compose project name.
# This prevents Compose from silently creating a different set
# of volume names on the destination machine.
# ------------------------------------------------------------
Write-Info "[5/5] Starting DevBox Lite..."

$ComposeRelative = $Manifest["compose_file"]
if (-not $ComposeRelative) {
    $ComposeRelative = "docker/compose/docker-compose.yml"
}

$ComposeFile = Join-Path $ProjectRoot ($ComposeRelative -replace '/', '\')

if (-not (Test-Path $ComposeFile)) {
    Fail "Compose file not found after project restore: $ComposeFile"
}

docker.exe compose -p $ComposeProject -f $ComposeFile up -d
if ($LASTEXITCODE -ne 0) {
    Fail "docker compose up failed."
}

Write-Ok "  [OK] Docker Compose started."

# ------------------------------------------------------------
# Final checks.
# ------------------------------------------------------------
Write-Info "[verify] Checking DevBox container state..."

$ComposePs = docker.exe compose -p $ComposeProject -f $ComposeFile ps --format json 2>$null

if ($LASTEXITCODE -ne 0) {
    Fail "Could not query Docker Compose status."
}

docker.exe image inspect $ImageName *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "DevBox image verification failed."
}

foreach ($logical in $Volumes.Keys) {
    $VolumeName = $Volumes[$logical]
    docker.exe volume inspect $VolumeName *> $null

    if ($LASTEXITCODE -ne 0) {
        Fail "Docker volume verification failed: $VolumeName"
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " DevBox Lite Restore Completed" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Project : $ProjectRoot"
Write-Host "Compose : $ComposeProject"
Write-Host "Image   : $ImageName"
Write-Host ""
Write-Host "Docker Desktop can now be used normally."
Write-Host "Ubuntu-24.04 is installed as WSL2 and can be used independently."
Write-Host ""
