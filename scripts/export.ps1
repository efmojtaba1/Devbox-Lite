param(
    [string]$OutDir,
    [string]$ImageName
)

$ErrorActionPreference = "Stop"
$DefaultOutDir = "D:\devbox-image"
$DefaultImage = "devbox-lite:latest"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Full Project & Docker Export" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "1) Use default location ($DefaultOutDir)" -ForegroundColor White
Write-Host "2) Enter custom location" -ForegroundColor White
$choice = Read-Host "Choose an option [1/2] (default: 1)"

if ($choice -eq "2") {
    Write-Host "  [Tip] Example format: D:\devbox-image or C:\MyBackup" -ForegroundColor Yellow
    $customDir = Read-Host "  Enter custom path"
    $OutDir = if ($customDir) { $customDir } else { $DefaultOutDir }
} else {
    $OutDir = $DefaultOutDir
}

Write-Host ""
Write-Host "1) Use default image ($DefaultImage)" -ForegroundColor White
Write-Host "2) Enter custom image name" -ForegroundColor White
$imgChoice = Read-Host "Choose an option [1/2] (default: 1)"

if ($imgChoice -eq "2") {
    $customImage = Read-Host "  Enter image name to save"
    $ImageName = if ($customImage) { $customImage } else { $DefaultImage }
} else {
    $ImageName = $DefaultImage
}

$Volumes = @("example-templates", "pnpm-store", "composer-cache", "devbox-deps", "bruno-config", "bruno-collections")
$ProjectRoot = (Get-Item "$PSScriptRoot\..").FullName

if (!(Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}
$AbsOut = (Get-Item $OutDir).FullName

Write-Host "[export] Saving Docker image: $ImageName -> $AbsOut\image.tar"
docker image inspect $ImageName 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "[error] Image $ImageName not found locally. Run 'docker images' to verify."
    exit 1
}
docker save -o "$AbsOut\image.tar" $ImageName

Write-Host "[export] Exporting Docker volumes..."
foreach ($v in $Volumes) {
    Write-Host "[export] Volume: $v"
    docker run --rm -v "${v}:/volume" -v "${AbsOut}:/backup" alpine sh -c "cd /volume 2>/dev/null || true; tar czf /backup/vol-${v}.tar.gz -C /volume . || tar czf /backup/vol-${v}.tar.gz --files-from /dev/null"
    if (Test-Path "$AbsOut\vol-${v}.tar.gz") {
        Write-Host "  [ok] $v -> vol-${v}.tar.gz" -ForegroundColor Green
    } else {
        Write-Host "  [warn] vol-${v}.tar.gz not created (volume may be empty)" -ForegroundColor Yellow
    }
}

$PrebuiltDir = Join-Path $ProjectRoot "prebuilt"
if (Test-Path $PrebuiltDir) {
    Write-Host "[export] Packaging prebuilt directory..."
    tar czf "$AbsOut\prebuilt.tar.gz" -C $ProjectRoot prebuilt
    Write-Host "  [ok] prebuilt -> prebuilt.tar.gz" -ForegroundColor Green
} else {
    Write-Host "  [warn] prebuilt directory not found in project root; skipping" -ForegroundColor Yellow
}

Write-Host "[export] Packaging project source code..."
tar --exclude='.git' --exclude='node_modules' --exclude='vendor' --exclude='.env' --exclude='devbox-offline' --exclude='out' --exclude='backups' -czf "$AbsOut\project-src.tar.gz" -C $ProjectRoot .
Write-Host "  [ok] project source code -> project-src.tar.gz" -ForegroundColor Green

$ExportScriptsDir = Join-Path $AbsOut "scripts"
if (!(Test-Path $ExportScriptsDir)) {
    New-Item -ItemType Directory -Force -Path $ExportScriptsDir | Out-Null
}
Copy-Item "$PSScriptRoot\*" $ExportScriptsDir -Recurse -Force

$ManifestContent = "image:$ImageName`nvolumes:$($Volumes -join ' ')`ngenerated_at:$(Get-Date -UFormat %Y-%m-%dT%H:%M:%SZ)"
Set-Content -Path "$AbsOut\manifest.txt" -Value $ManifestContent

Write-Host "[done] Full self-contained package exported successfully to: $AbsOut" -ForegroundColor Green
