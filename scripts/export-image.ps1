param(
    [string]$OutDir = "./devbox-offline",
    [string]$ImageName = "devbox-lite:latest"
)

$ErrorActionPreference = "Stop"
$Volumes = @("example-templates", "pnpm-store", "composer-cache", "devbox-deps", "bruno-config", "bruno-collections")

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

Write-Host "[export] Exporting volumes to $AbsOut"
foreach ($v in $Volumes) {
    Write-Host "[export] Volume: $v"
    docker run --rm -v "${v}:/volume" -v "${AbsOut}:/backup" alpine sh -c "cd /volume 2>/dev/null || true; tar czf /backup/vol-${v}.tar.gz -C /volume . || tar czf /backup/vol-${v}.tar.gz --files-from /dev/null"
    if (Test-Path "$AbsOut\vol-${v}.tar.gz") {
        Write-Host "  [ok] $v -> vol-${v}.tar.gz" -ForegroundColor Green
    } else {
        Write-Host "  [warn] vol-${v}.tar.gz not created (volume may be empty)" -ForegroundColor Yellow
    }
}

$ManifestContent = "image:$ImageName`nvolumes:$($Volumes -join ' ')`ngenerated_at:$(Get-Date -UFormat %Y-%m-%dT%H:%M:%SZ)"
Set-Content -Path "$AbsOut\manifest.txt" -Value $ManifestContent

Write-Host "[done] Exported offline package to: $AbsOut" -ForegroundColor Green
