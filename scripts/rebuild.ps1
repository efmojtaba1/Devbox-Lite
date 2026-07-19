. "$PSScriptRoot/common.ps1"

Show-Header "Rebuilding DevBox (no cache)"

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
Write-Host "  1) Iran Mirror (ir.archive.ubuntu.com) [default]"
Write-Host "  2) ArvanCloud Mirror (mirror.arvancloud.ir)"
Write-Host "  3) Default Ubuntu Mirrors"
Write-Host "  4) Custom URL"
Write-Host ""
$mirrorChoice = Read-Host "Enter choice (1-4) [1]"

$APT_MIRROR = switch ($mirrorChoice) {
    "1" { "http://ir.archive.ubuntu.com/ubuntu" }
    "2" { "https://mirror.arvancloud.ir/ubuntu" }
    "3" { "" }
    "4" { Read-Host "Enter mirror URL" }
    default { "http://ir.archive.ubuntu.com/ubuntu" }
}

if ($APT_MIRROR) {
    Write-Host ""
    Write-Host "Using APT mirror: $APT_MIRROR"
} else {
    Write-Host ""
    Write-Host "Using default Ubuntu mirrors"
}

Write-Host ""

# Pip mirror selection
Write-Host "========================================="
Write-Host "Select Pip Mirror:"
Write-Host "========================================="
Write-Host "  1) Aliyun Mirror (mirrors.aliyun.com) [default]"
Write-Host "  2) Tsinghua Mirror (pypi.tuna.tsinghua.edu.cn)"
Write-Host "  3) Default PyPI"
Write-Host "  4) Custom URL"
Write-Host ""
$pipChoice = Read-Host "Enter choice (1-4) [1]"

$PIP_MIRROR = switch ($pipChoice) {
    "1" { "https://mirrors.aliyun.com/pypi/simple/" }
    "2" { "https://pypi.tuna.tsinghua.edu.cn/simple/" }
    "3" { "" }
    "4" { Read-Host "Enter mirror URL" }
    default { "https://mirrors.aliyun.com/pypi/simple/" }
}

if ($PIP_MIRROR) {
    Write-Host ""
    Write-Host "Using pip mirror: $PIP_MIRROR"
} else {
    Write-Host ""
    Write-Host "Using default PyPI"
}

Write-Host ""

# Build with mirror args
$buildArgs = @()
if ($APT_MIRROR) { $buildArgs += "--build-arg"; $buildArgs += "APT_MIRROR=$APT_MIRROR" }
if ($PIP_MIRROR) { $buildArgs += "--build-arg"; $buildArgs += "PIP_MIRROR=$PIP_MIRROR" }

docker build --no-cache @buildArgs -t $ImageName -f $DockerFile $BuildContext

Test-Result "Rebuild completed successfully." "Rebuild failed."
