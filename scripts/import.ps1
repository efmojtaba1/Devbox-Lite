[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$TargetProj = "D:\devbox-project",
    [string]$Distribution = "Ubuntu-24.04"
)

$ErrorActionPreference = "Stop"

function Write-Info([string]$Message) { Write-Host $Message -ForegroundColor Cyan }
function Write-Ok([string]$Message)   { Write-Host $Message -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Fail([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    throw $Message
}

function Get-Sha256([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Fail "File not found for checksum verification: $Path"
    }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $stream = [System.IO.File]::OpenRead($Path)
        try { $hash = $sha256.ComputeHash($stream) }
        finally { $stream.Dispose() }
    }
    finally { $sha256.Dispose() }
    return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
}

function Verify-Sha256([string]$Path, [string]$Expected) {
    if (-not $Expected) { return }
    $actual = Get-Sha256 $Path
    $expectedNormalized = $Expected.ToLowerInvariant()
    if ($actual -ne $expectedNormalized) {
        Fail "SHA256 mismatch for $(Split-Path $Path -Leaf). Expected $expectedNormalized but got $actual"
    }
    Write-Ok "  [OK] SHA256 $(Split-Path $Path -Leaf)"
}

function Invoke-WslRoot([string]$BashCommand) {
    & wsl.exe -d $Distribution -u root -- bash -lc $BashCommand
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        throw "WSL command failed with exit code $rc."
    }
}

function Invoke-WslDocker([string]$DockerArguments) {
    # The WSL Ubuntu Docker Engine is intentionally separate from Docker Desktop.
    # All operations in this function target the dedicated local socket.
    $cmd = 'export DOCKER_HOST=unix:///run/devbox-docker.sock; docker ' + $DockerArguments
    & wsl.exe -d $Distribution -u root -- bash -lc $cmd
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        throw "WSL Docker Engine command failed with exit code ${rc}: docker $DockerArguments"
    }
}

function Convert-WindowsPathToWsl([string]$WindowsPath) {
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($WindowsPath))
    $result = & wsl.exe -d $Distribution -u root -- bash -lc "p=`$(printf '%s' '$encoded' | base64 -d); wslpath -u `"$p`""
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "Could not convert Windows path to WSL path: $WindowsPath" }
    return (($result | Out-String).Trim())
}

function Get-WslNormalUser {
    # Resolve and validate the normal Linux account entirely inside WSL, then
    # return exactly one line to PowerShell. The command is base64-encoded so
    # Windows quoting cannot alter the bash script.
    $probe = @'
set -eu
user=""
if [ -f /etc/wsl.conf ]; then
  user="$(awk '
    BEGIN { section="" }
    /^\[user\][[:space:]]*$/ { section="user"; next }
    /^\[/ { section="" }
    section == "user" && $0 ~ /^[[:space:]]*default[[:space:]]*=/ {
      sub(/^[[:space:]]*default[[:space:]]*=[[:space:]]*/, "")
      gsub(/[[:space:]]/, "")
      print
      exit
    }
  ' /etc/wsl.conf)"
fi

if [ -n "$user" ] && getent passwd "$user" >/dev/null 2>&1; then
  :
else
  user="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')"
fi

if [ -z "$user" ]; then
  echo "[error] No normal Ubuntu user account was found (UID 1000+)." >&2
  exit 2
fi

entry="$(getent passwd "$user" || true)"
uid="$(printf '%s\n' "$entry" | cut -d: -f3)"
shell="$(printf '%s\n' "$entry" | cut -d: -f7)"
home="$(printf '%s\n' "$entry" | cut -d: -f6)"

case "$uid" in
  ''|*[!0-9]*) echo "[error] Invalid UID for WSL user: $user" >&2; exit 3 ;;
esac

if [ "$uid" -lt 1000 ] || [ "$uid" -ge 60000 ]; then
  echo "[error] WSL account is not a normal user: $user" >&2
  exit 4
fi

case "$shell" in
  */nologin|*/false) echo "[error] WSL account is not an interactive user: $user" >&2; exit 5 ;;
esac

if [ -z "$home" ] || [ ! -d "$home" ]; then
  echo "[error] WSL user home directory is missing: $home" >&2
  exit 6
fi

printf '%s\n' "$user"
'@

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($probe))
    $result = & wsl.exe -d $Distribution -u root -- bash -lc "echo '$encoded' | base64 -d | bash -s" 2>$null
    $rc = $LASTEXITCODE
    if ($rc -ne 0) {
        throw "Could not determine the Ubuntu normal user (exit code ${rc})."
    }

    $user = (($result | Where-Object { $_ -and $_.Trim() } | Select-Object -First 1) -as [string]).Trim()
    if (-not $user -or $user -notmatch '^[a-z_][a-z0-9_-]*$') {
        throw "No normal Ubuntu user account was found in /etc/wsl.conf or /etc/passwd."
    }

    return $user
}

function Get-WslUserHome([string]$UserName) {
    $encodedUser = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($UserName))
    $result = & wsl.exe -d $Distribution -u root -- bash -lc "u=`$(printf '%s' '$encodedUser' | base64 -d); getent passwd `"`$u`" | cut -d: -f6"
    $rc = $LASTEXITCODE
    if ($rc -ne 0) { throw "Could not resolve home directory for WSL user: $UserName (exit code ${rc})" }
    $home = (($result | Select-Object -First 1) -as [string]).Trim()
    if (-not $home) { throw "Could not resolve home directory for WSL user: $UserName" }
    return $home
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " DevBox Lite - Dual Docker Restore" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

if (-not $InputPath) {
    $InputPath = Join-Path (Get-Location).Path ".."
}

$InputPath = [System.IO.Path]::GetFullPath($InputPath)
$TargetProj = [System.IO.Path]::GetFullPath($TargetProj)

if (-not (Test-Path -LiteralPath $InputPath -PathType Container)) {
    Fail "Offline package path not found: $InputPath"
}
if (-not (Get-Command docker.exe -ErrorAction SilentlyContinue)) {
    Fail "docker.exe is not available. Docker Desktop must be installed."
}
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    Fail "wsl.exe is not available."
}

& wsl.exe -d $Distribution -u root -- true
if ($LASTEXITCODE -ne 0) {
    Fail "WSL distribution '$Distribution' is not ready."
}

try {
    docker.exe version *> $null
    if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop daemon is not ready." }
} catch {
    Fail "Docker Desktop daemon is not ready."
}

try {
    Invoke-WslDocker "version >/dev/null"
} catch {
    Fail "Docker Engine inside '$Distribution' is not ready on /run/devbox-docker.sock."
}

$ManifestPath = Join-Path $InputPath "manifest.txt"
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Fail "manifest.txt not found: $ManifestPath"
}

$Manifest = @{}
$Volumes = [ordered]@{}
$section = ""
foreach ($line in Get-Content -LiteralPath $ManifestPath) {
    $trimmed = $line.Trim()
    if (-not $trimmed) { continue }
    if ($trimmed -match '^\[(.+)\]$') {
        $section = $Matches[1]
        continue
    }
    if ($trimmed -match '^([^:]+):(.*)$') {
        $key = $Matches[1]
        $value = $Matches[2]
        if ($section -eq "volumes") { $Volumes[$key] = $value }
        else { $Manifest[$key] = $value }
    }
}

$ImageName = $Manifest["image"]
$ComposeProject = $Manifest["compose_project"]
if (-not $ImageName) { Fail "Image name is missing from manifest.txt" }
if (-not $ComposeProject) { $ComposeProject = "devbox" }

if (-not (Test-Path -LiteralPath $TargetProj)) {
    New-Item -ItemType Directory -Force -Path $TargetProj | Out-Null
}

Write-Info "[restore] Package : $InputPath"
Write-Info "[restore] Windows : $TargetProj"
Write-Info "[restore] WSL     : /home/<user>/projects/DevBox-Lite"
Write-Info "[restore] Image   : $ImageName"
Write-Info "[restore] Compose : $ComposeProject"

$ImageTar = Join-Path $InputPath "image.tar"
$ProjectSrcTar = Join-Path $InputPath "project-src.tar.gz"
$PrebuiltTar = Join-Path $InputPath "prebuilt.tar.gz"
$VolumesPath = Join-Path $InputPath "volumes"

Write-Info "[1/7] Verifying package archives..."
Verify-Sha256 $ImageTar $Manifest["image_sha256"]
Verify-Sha256 $ProjectSrcTar $Manifest["project-src.tar.gz"]
foreach ($logical in $Volumes.Keys) {
    $archive = Join-Path $VolumesPath "vol-$logical.tar.gz"
    if (-not (Test-Path -LiteralPath $archive -PathType Leaf)) {
        Fail "Volume archive is missing: $archive"
    }
    Verify-Sha256 $archive $Manifest["volumes/vol-$logical.tar.gz"]
}
if (Test-Path -LiteralPath $PrebuiltTar -PathType Leaf) {
    Verify-Sha256 $PrebuiltTar $Manifest["prebuilt.tar.gz"]
}

Write-Info "[2/7] Restoring project and prebuilt on Windows..."
if (Test-Path -LiteralPath $TargetProj) {
    Get-ChildItem -LiteralPath $TargetProj -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $TargetProj | Out-Null

tar.exe -xzf $ProjectSrcTar -C $TargetProj
if ($LASTEXITCODE -ne 0) { Fail "Failed to extract project-src.tar.gz on Windows." }

if (Test-Path -LiteralPath $PrebuiltTar -PathType Leaf) {
    tar.exe -xzf $PrebuiltTar -C $TargetProj
    if ($LASTEXITCODE -ne 0) { Fail "Failed to extract prebuilt.tar.gz on Windows." }
}
if (-not (Test-Path (Join-Path $TargetProj "docker\compose\docker-compose.yml"))) {
    Fail "Windows project restore did not produce docker/compose/docker-compose.yml"
}
if ((Test-Path -LiteralPath $PrebuiltTar) -and -not (Test-Path (Join-Path $TargetProj "prebuilt"))) {
    Fail "Windows prebuilt restore did not produce prebuilt directory."
}
Write-Ok "  [OK] Windows project: $TargetProj"

Write-Info "[3/7] Restoring project and prebuilt inside WSL..."
$wslUser = Get-WslNormalUser
$wslHome = Get-WslUserHome $wslUser
$wslProject = "$wslHome/projects/DevBox-Lite"

$projectTarWsl = Convert-WindowsPathToWsl $ProjectSrcTar
$prebuiltTarWsl = if (Test-Path -LiteralPath $PrebuiltTar) { Convert-WindowsPathToWsl $PrebuiltTar } else { "" }

$restoreWslProject = @'
set -euo pipefail
TARGET_USER="$1"
TARGET_HOME="$2"
PROJECT="$TARGET_HOME/projects/DevBox-Lite"
PROJECT_TAR="$3"
PREBUILT_TAR="${4:-}"

rm -rf "$PROJECT"
mkdir -p "$TARGET_HOME/projects" "$PROJECT"
tar -xzf "$PROJECT_TAR" -C "$PROJECT"

if [ -n "$PREBUILT_TAR" ] && [ -f "$PREBUILT_TAR" ]; then
  tar -xzf "$PREBUILT_TAR" -C "$PROJECT"
fi

chown -R "$TARGET_USER":"$TARGET_USER" "$PROJECT"
test -f "$PROJECT/docker/compose/docker-compose.yml"
if [ -n "$PREBUILT_TAR" ]; then
  test -d "$PROJECT/prebuilt"
fi
printf '%s\n' "$PROJECT"
'@
$scriptB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($restoreWslProject))
$args = @(
    "-d", $Distribution, "-u", "root", "--", "bash", "-lc",
    "printf '%s' '$scriptB64' | base64 -d | bash -s -- '$wslUser' '$wslHome' '$projectTarWsl' '$prebuiltTarWsl'"
)
& wsl.exe @args
if ($LASTEXITCODE -ne 0) { Fail "Failed to restore project/prebuilt inside WSL." }
Write-Ok "  [OK] WSL project: \\wsl.localhost\$Distribution$($wslProject -replace '/','\')"

Write-Info "[4/7] Loading image into Docker Desktop..."
docker.exe load -i $ImageTar
if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop image load failed." }
docker.exe image inspect $ImageName *> $null
if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop does not contain image '$ImageName' after load." }
Write-Ok "  [OK] Docker Desktop image: $ImageName"

Write-Info "[5/7] Loading image into WSL Docker Engine..."
$encodedTar = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Convert-WindowsPathToWsl $ImageTar)))
Invoke-WslRoot "image_wsl_tar_path=`$(printf '%s' '$encodedTar' | base64 -d); test -f `"`$image_wsl_tar_path`""
$imageWslPath = Convert-WindowsPathToWsl $ImageTar
$loadCmd = "export DOCKER_HOST=unix:///run/devbox-docker.sock; docker load -i '$imageWslPath'"
Invoke-WslRoot $loadCmd
Invoke-WslDocker "image inspect '$ImageName' >/dev/null"
Write-Ok "  [OK] WSL Docker Engine image: $ImageName"

Write-Info "[6/7] Restoring Docker volumes into both daemons..."
$tempRoot = "/tmp/devbox-lite-restore"
Invoke-WslRoot "rm -rf '$tempRoot'; mkdir -p '$tempRoot'"

foreach ($logical in $Volumes.Keys) {
    $volumeName = [string]$Volumes[$logical]
    if (-not $volumeName) { Fail "Empty Docker volume name for logical volume '$logical'" }

    $archive = Join-Path $VolumesPath "vol-$logical.tar.gz"

    # Docker Desktop volume.
    $inspect = & docker.exe volume inspect $volumeName 2>$null
    if ($LASTEXITCODE -ne 0) {
        & docker.exe volume create $volumeName *> $null
        if ($LASTEXITCODE -ne 0) { Fail "Could not create Docker Desktop volume '$volumeName'" }
    }
    $archiveName = Split-Path $archive -Leaf
    & docker.exe run --rm `
        -v "${volumeName}:/restore-target" `
        -v "${VolumesPath}:/backup:ro" `
        $ImageName `
        sh -c "rm -rf /restore-target/* /restore-target/.[!.]* /restore-target/..?* 2>/dev/null || true; tar xzf /backup/$archiveName -C /restore-target"
    if ($LASTEXITCODE -ne 0) { Fail "Failed to restore Docker Desktop volume '$volumeName'" }

    # WSL Docker Engine volume.
    $archiveWsl = Convert-WindowsPathToWsl $archive
    $stage = "$tempRoot/$archiveName"
    Invoke-WslRoot "cp -f '$archiveWsl' '$stage'"
    Invoke-WslDocker "volume inspect '$volumeName' >/dev/null 2>&1 || docker volume create '$volumeName' >/dev/null"
    Invoke-WslDocker "run --rm -v '${volumeName}:/restore-target' -v '${tempRoot}:/backup:ro' '$ImageName' sh -c `"rm -rf /restore-target/* /restore-target/.[!.]* /restore-target/..?* 2>/dev/null || true; tar xzf /backup/$archiveName -C /restore-target`""
    Invoke-WslRoot "rm -f '$stage'"

    Write-Ok "  [OK] $logical -> Desktop + WSL Engine: $volumeName"
}
Invoke-WslRoot "rm -rf '$tempRoot'"

Write-Info "[7/7] Verifying both Docker daemons and project trees..."

docker.exe image inspect $ImageName *> $null
if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop image verification failed." }

foreach ($logical in $Volumes.Keys) {
    $volumeName = [string]$Volumes[$logical]
    docker.exe volume inspect $volumeName *> $null
    if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop volume verification failed: $volumeName" }
}
if (-not (Test-Path (Join-Path $TargetProj "docker\compose\docker-compose.yml"))) {
    Fail "Windows project verification failed."
}
if (Test-Path -LiteralPath $PrebuiltTar) {
    if (-not (Test-Path (Join-Path $TargetProj "prebuilt"))) {
        Fail "Windows prebuilt verification failed."
    }
}

Invoke-WslDocker "image inspect '$ImageName' >/dev/null"
foreach ($logical in $Volumes.Keys) {
    $volumeName = [string]$Volumes[$logical]
    Invoke-WslDocker "volume inspect '$volumeName' >/dev/null"
}
Invoke-WslRoot "test -f '$wslProject/docker/compose/docker-compose.yml'"
if (Test-Path -LiteralPath $PrebuiltTar) {
    Invoke-WslRoot "test -d '$wslProject/prebuilt'"
}

# Start each Compose project against its own daemon.
$ComposeRelative = $Manifest["compose_file"]
if (-not $ComposeRelative) { $ComposeRelative = "docker/compose/docker-compose.yml" }
$ComposeFileWin = Join-Path $TargetProj ($ComposeRelative -replace '/', '\')

Write-Info "[start] Starting DevBox on Docker Desktop..."
& docker.exe compose -p $ComposeProject -f $ComposeFileWin up -d
if ($LASTEXITCODE -ne 0) { Fail "Docker Desktop docker compose up failed." }

Write-Info "[start] Starting DevBox on WSL Docker Engine..."
$composeFileWsl = "$wslProject/$($ComposeRelative -replace '\\','/')"
$composeProjectEsc = $ComposeProject.Replace("'","'\''")
$composeFileEsc = $composeFileWsl.Replace("'","'\''")
Invoke-WslDocker "compose -p '$composeProjectEsc' -f '$composeFileEsc' up -d"

Write-Ok "  [OK] Docker Desktop Compose started."
Write-Ok "  [OK] WSL Docker Engine Compose started."

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " DevBox Lite Dual Restore Completed" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "Windows project : $TargetProj"
Write-Host "WSL project     : \\wsl.localhost\$Distribution$($wslProject -replace '/','\')"
Write-Host "Image           : $ImageName"
Write-Host "Desktop daemon  : loaded + verified"
Write-Host "WSL daemon      : loaded + verified"
Write-Host "Volumes         : loaded + verified in both daemons"
Write-Host "Prebuilt        : restored in Windows and WSL"
Write-Host ""
