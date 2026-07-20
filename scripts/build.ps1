. "$PSScriptRoot/common.ps1"

Show-Header "Building DevBox - lite"

$DockerFile = Join-Path $ScriptDir "docker/app/Dockerfile"
$BuildContext = Join-Path $ScriptDir "docker/app"
$PrebuiltDir = Join-Path $ScriptDir "prebuilt/images"

# Load prebuilt base images if available
Write-Host "Checking for prebuilt images..."
$ubuntuTar = Join-Path $PrebuiltDir "ubuntu-24.04.tar.gz"
$ubuntuTarRaw = Join-Path $PrebuiltDir "ubuntu-24.04.tar"

if (Test-Path $ubuntuTar) {
    Write-Host "  Loading ubuntu:24.04 from prebuilt..."
    docker load -i $ubuntuTar 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [ok] ubuntu:24.04 loaded" } else { Write-Host "  [skip] already exists or load failed" }
} elseif (Test-Path $ubuntuTarRaw) {
    Write-Host "  Loading ubuntu:24.04 from prebuilt..."
    docker load -i $ubuntuTarRaw 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "  [ok] ubuntu:24.04 loaded" } else { Write-Host "  [skip] already exists or load failed" }
} else {
    Write-Host "  [info] No prebuilt ubuntu:24.04 found, will download"
}
Write-Host ""

# Mirror selection
Write-Host "========================================="
Write-Host "Select APT Mirror:"
Write-Host "========================================="
Write-Host "  1) ArvanCloud (mirror.arvancloud.ir) [default - fastest]"
Write-Host "  2) Iran Official (ir.archive.ubuntu.com)"
Write-Host "  3) Default Ubuntu Mirrors"
Write-Host "  4) Custom URL"
Write-Host ""
$mirrorChoice = Read-Host "Enter choice (1-4) [1]"

$APT_MIRROR = switch ($mirrorChoice) {
    "1" { "https://mirror.arvancloud.ir/ubuntu" }
    "2" { "http://ir.archive.ubuntu.com/ubuntu" }
    "3" { "" }
    "4" { Read-Host "Enter mirror URL" }
    default { "https://mirror.arvancloud.ir/ubuntu" }
}

if ($APT_MIRROR) {
    Write-Host ""
    Write-Host "Using APT mirror: $APT_MIRROR"
} else {
    Write-Host ""
    Write-Host "Using default Ubuntu mirrors"
}

# Auto-select best pip mirror (PyPI default is fastest from Iran)
Write-Host ""
Write-Host "Using pip mirror: Default PyPI (pypi.org) - fastest from Iran"
Write-Host ""

# Build with mirror args
$buildArgs = @()
if ($APT_MIRROR) { $buildArgs += "--build-arg"; $buildArgs += "APT_MIRROR=$APT_MIRROR" }

# Copy example templates into build context (Dockerfile needs them)
# Exclude dependency dirs (symlinks to Docker volumes, can't be copied)
Write-Host "Copying example templates to build context..."
$exampleDst = Join-Path $BuildContext "example"
if (Test-Path $exampleDst) { Remove-Item -Recurse -Force $exampleDst 2>$null }
foreach ($tmpl in @("laravel", "next-js", "python", "react")) {
    $src = Join-Path $ScriptDir "example\$tmpl"
    $dst = Join-Path $exampleDst $tmpl
    if (Test-Path $src) {
        New-Item -ItemType Directory -Force -Path $dst | Out-Null
        Get-ChildItem $src -Directory | Where-Object { $_.Name -notin @("node_modules","vendor","venv",".next","__pycache__") } | ForEach-Object {
            Copy-Item -Recurse -Force $_.FullName $dst 2>$null
        }
        Get-ChildItem $src -File | ForEach-Object {
            Copy-Item -Force $_.FullName $dst 2>$null
        }
    }
}

docker build @buildArgs -t $ImageName -f $DockerFile $BuildContext

Test-Result "Build completed successfully." "Build failed."

# Cleanup copied example from build context
Remove-Item -Recurse -Force (Join-Path $BuildContext "example") 2>$null

# Start container and initialize example templates
Write-Host ""
Show-Header "Initializing Example Templates"
docker compose -f $ComposeFile up -d 2>$null
Start-Sleep -Seconds 3
docker exec $ContainerName bash -c "/scripts/init-example.sh" 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[warn] init-example failed. Run 'devbox init-example' manually." -ForegroundColor Yellow
}
