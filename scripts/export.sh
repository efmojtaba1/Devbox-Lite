#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DevBox Lite - Full Offline Export
#
# Creates a self-contained package for a Windows machine that
# has NO WSL and NO Docker Desktop and may be completely offline.
#
# The package contains:
#   - WSL MSI
#   - Ubuntu 24.04 WSL distribution
#   - Docker Desktop installer
#   - DevBox Docker image
#   - DevBox Docker volumes
#   - project source
#   - prebuilt directory
#   - setup-offline.bat
#   - scripts/import.ps1
#
# Internet is required only on the EXPORT machine when the
# official WSL / Ubuntu / Docker installers are not already
# present in offline-deps/.
# ============================================================

DEFAULT_OUT_DIR="/mnt/d/devbox-project"
DEFAULT_IMAGE="devbox-lite:latest"

WSL_API_URL="https://api.github.com/repos/microsoft/WSL/releases/latest"
UBUNTU_WSL_URL="https://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-wsl-amd64.wsl"
UBUNTU_WSL_SHA256="9b2f7730dc68227dd04a9f3e5eab86ad85caf556b8606ad94f1f29ff5c4fd3f5"

# Docker's official stable Windows x64 installer endpoint.
DOCKER_DESKTOP_VERSION="latest"
DOCKER_DESKTOP_URL="https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-win-amd64"
echo " DevBox Lite - Full Offline Export"
echo "========================================="

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[error] docker-compose.yml not found:"
  echo "        $COMPOSE_FILE"
  exit 1
fi

echo ""
echo "1) Use default location ($DEFAULT_OUT_DIR)"
echo "2) Enter custom location"
read -e -p "Choose an option [1/2] (default: 1): " choice
choice="${choice:-1}"

if [ "$choice" == "2" ]; then
  echo "  [Tip] Example: /mnt/d/devbox-project"
  read -e -p "  Enter custom path: " custom_dir
  OUT_DIR="${custom_dir:-$DEFAULT_OUT_DIR}"
else
  OUT_DIR="$DEFAULT_OUT_DIR"
fi

mkdir -p "$OUT_DIR"
ABS_OUT="$(cd "$OUT_DIR" && pwd)"
# اضافه کردن این دو خط برای ساخت پوشه داخلی
BUNDLE_DIR="$ABS_OUT/devbox-data"
mkdir -p "$BUNDLE_DIR"
OFFLINE_DEPS_DIR="$BUNDLE_DIR/offline-deps"

mkdir -p "$OFFLINE_DEPS_DIR"

echo ""
echo "1) Use default image ($DEFAULT_IMAGE)"
echo "2) Enter custom image name"
read -e -p "Choose an option [1/2] (default: 1): " img_choice
img_choice="${img_choice:-1}"

if [ "$img_choice" == "2" ]; then
  read -e -p "  Enter custom image name to save: " custom_image
  IMAGE_NAME="${custom_image:-$DEFAULT_IMAGE}"
else
  IMAGE_NAME="$DEFAULT_IMAGE"
fi

# ------------------------------------------------------------
# Prerequisites on EXPORT machine
# ------------------------------------------------------------
for cmd in docker curl python3 sha256sum tar; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[error] Required command not found: $cmd"
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "[error] Docker daemon is not available on the export machine."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] Docker Compose is not available on the export machine."
  exit 1
fi

COMPOSE_PROJECT="$(
  docker compose -f "$COMPOSE_FILE" config --format json 2>/dev/null |
    python3 -c '
import json,sys
try:
    data=json.load(sys.stdin)
    print(data.get("name",""))
except Exception:
    pass
' 2>/dev/null || true
)"

if [ -z "$COMPOSE_PROJECT" ]; then
  COMPOSE_PROJECT="devbox"
fi

echo ""
echo "[export] Project root   : $PROJECT_ROOT"
echo "[export] Compose file   : $COMPOSE_FILE"
echo "[export] Compose project : $COMPOSE_PROJECT"
echo "[export] Output          : $ABS_OUT"
echo ""

# ------------------------------------------------------------
# Logical volumes used by DevBox Lite
# ------------------------------------------------------------
VOLUMES=(
  example-templates
  pnpm-store
  composer-cache
  devbox-deps
  bruno-config
  bruno-collections
)

resolve_volume() {
  local logical_name="$1"
  local actual_volume=""

  actual_volume="$(
    docker volume ls -q \
      --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
      --filter "label=com.docker.compose.volume=${logical_name}" |
      head -n 1
  )"

  if [ -n "$actual_volume" ]; then
    printf '%s\n' "$actual_volume"
    return 0
  fi

  local fallback="${COMPOSE_PROJECT}_${logical_name}"
  if docker volume inspect "$fallback" >/dev/null 2>&1; then
    printf '%s\n' "$fallback"
    return 0
  fi

  return 1
}

# ------------------------------------------------------------
# Robust resumable download helper
# ------------------------------------------------------------
# Uses curl's native progress meter as the single progress mechanism.
#
# Strategy:
#   1. Reuse an existing complete file.
#   2. Resume *.part files.
#   3. Prefer IPv4 in WSL.
#   4. Retry transient failures.
#   5. If WSL receives a blocked response (for example HTTP 403),
#      retry through the Windows host's curl.exe/network stack.
#   6. Preserve partial files on failure.
#
# No blocking HEAD request and no second progress-monitor process.
# ------------------------------------------------------------
DOWNLOAD_RETRIES="8"
DOWNLOAD_RETRY_DELAY="5"
DOWNLOAD_MAX_RETRY_TIME="1800"
DOWNLOAD_CONNECT_TIMEOUT="30"
DOWNLOAD_SPEED_LIMIT="1024"
DOWNLOAD_SPEED_TIME="180"
DOWNLOAD_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/151.0.0.0 Safari/537.36"

download_with_wsl_curl() {
  local url="${1:-}"
  local part="${2:-}"
  local resume_args=()

  [ -s "$part" ] && resume_args=(--continue-at -)

  curl \
    -4 \
    --fail \
    --location \
    --user-agent "$DOWNLOAD_USER_AGENT" \
    "${resume_args[@]}" \
    --retry "$DOWNLOAD_RETRIES" \
    --retry-delay "$DOWNLOAD_RETRY_DELAY" \
    --retry-max-time "$DOWNLOAD_MAX_RETRY_TIME" \
    --retry-all-errors \
    --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" \
    --speed-limit "$DOWNLOAD_SPEED_LIMIT" \
    --speed-time "$DOWNLOAD_SPEED_TIME" \
    --output "$part" \
    "$url"
}

download_with_windows_host() {
  local url="${1:-}"
  local part="${2:-}"
  local win_output=""
  local resume="0"

  command -v powershell.exe >/dev/null 2>&1 || return 127
  command -v wslpath >/dev/null 2>&1 || return 127

  win_output="$(wslpath -w "$part" 2>/dev/null || true)"
  [ -n "$win_output" ] || return 127

  [ -s "$part" ] && resume="1"

  echo "  [fallback] Retrying through Windows host networking..."
  echo "             Output: $win_output"

  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
    \$ErrorActionPreference = 'Stop'
    \$args = @(
      '-4',
      '--fail',
      '--location',
      '--user-agent', '$DOWNLOAD_USER_AGENT',
      '--retry', '$DOWNLOAD_RETRIES',
      '--retry-delay', '$DOWNLOAD_RETRY_DELAY',
      '--retry-max-time', '$DOWNLOAD_MAX_RETRY_TIME',
      '--retry-all-errors',
      '--connect-timeout', '$DOWNLOAD_CONNECT_TIMEOUT',
      '--speed-limit', '$DOWNLOAD_SPEED_LIMIT',
      '--speed-time', '$DOWNLOAD_SPEED_TIME'
    )

    if ('$resume' -eq '1') {
      \$args += @('--continue-at', '-')
    }

    \$args += @('--output', '$win_output', '$url')
    & curl.exe @args
    exit \$LASTEXITCODE
  "
}

download_resumable() {
  local url="${1:-}"
  local output="${2:-}"
  local label="${3:-}"

  if [ -z "$url" ] || [ -z "$output" ]; then
    echo "  [error] download_resumable requires URL and output path."
    return 1
  fi

  [ -n "$label" ] || label="$(basename "$output")"

  local part="${output}.part"

  if [ -s "$output" ]; then
    echo "  [ok] Existing: $label"
    echo "  [info] Size: $(du -h "$output" | cut -f1)"
    return 0
  fi

  echo "  [download] $label"
  echo "  [info] Download URL:"
  echo "         $url"

  if [ -s "$part" ]; then
    local bytes
    bytes="$(stat -c '%s' "$part" 2>/dev/null || echo 0)"
    echo "  [resume] Partial file detected: $((bytes / 1024 / 1024)) MB"
  fi

  if download_with_wsl_curl "$url" "$part"; then
    :
  else
    local wsl_rc=$?
    echo ""
    echo "  [warn] WSL download failed (curl exit $wsl_rc)."

    if download_with_windows_host "$url" "$part"; then
      :
    else
      local host_rc=$?
      echo ""
      echo "  [error] Download failed: $label"
      echo "          WSL curl exit : $wsl_rc"
      echo "          Host curl exit: $host_rc"
      [ -s "$part" ] || rm -f "$part"
      return 1
    fi
  fi

  if [ ! -s "$part" ]; then
    echo "  [error] Downloaded file is missing or empty: $label"
    rm -f "$part"
    return 1
  fi

  mv -f "$part" "$output"

  echo "  [ok] Download complete: $label ($(du -h "$output" | cut -f1))"
}

# WSL MSI - latest stable x64 release
# ------------------------------------------------------------
echo ""
echo "[export] Preparing latest stable WSL x64 MSI..."

WSL_MSI="$OFFLINE_DEPS_DIR/wsl.x64.msi"

if [ -s "$WSL_MSI" ]; then
  echo "  [ok] Existing: $(basename "$WSL_MSI")"
  echo "  [info] Size: $(du -h "$WSL_MSI" | cut -f1)"
else
  WSL_RELEASE_JSON="$(mktemp)"
  trap 'rm -f "$WSL_RELEASE_JSON"' EXIT

  if ! curl -fL --retry 3 --retry-delay 2 \
      -H "Accept: application/vnd.github+json" \
      -H "User-Agent: DevBox-Lite-Offline-Export" \
      -o "$WSL_RELEASE_JSON" \
      "$WSL_API_URL"; then
    echo "[error] Could not query the official WSL releases API."
    exit 1
  fi

  WSL_ASSET_URL="$(
    python3 - "$WSL_RELEASE_JSON" <<'PY2'
import json, sys
data=json.load(open(sys.argv[1], encoding="utf-8"))
assets=data.get("assets", [])
for asset in assets:
    name=asset.get("name","")
    url=asset.get("browser_download_url","")
    if name.lower().endswith(".x64.msi") and url:
        print(url)
        break
else:
    raise SystemExit("No stable x64 MSI asset found in the latest WSL release.")
PY2
  )"

  echo "  [info] WSL MSI URL:"
  echo "         $WSL_ASSET_URL"

  download_resumable "$WSL_ASSET_URL" "$WSL_MSI" "WSL x64 MSI"
fi

if [ ! -s "$WSL_MSI" ]; then
  echo "[error] WSL x64 MSI is missing or empty."
  exit 1
fi

echo "  [ok] WSL x64 MSI verified."
WSL_MSI_SHA256="$(sha256sum "$WSL_MSI" | awk '{print $1}')"

# ------------------------------------------------------------
# Ubuntu 24.04 WSL distribution
# ------------------------------------------------------------
echo ""
echo "[export] Preparing Ubuntu 24.04 WSL distribution..."

UBUNTU_WSL="$OFFLINE_DEPS_DIR/ubuntu-24.04.4-wsl-amd64.wsl"
download_resumable "$UBUNTU_WSL_URL" "$UBUNTU_WSL" "Ubuntu 24.04 WSL"

ACTUAL_UBUNTU_SHA256="$(sha256sum "$UBUNTU_WSL" | awk '{print $1}')"

if [ "$ACTUAL_UBUNTU_SHA256" != "$UBUNTU_WSL_SHA256" ]; then
  echo "[error] Ubuntu WSL SHA256 mismatch."
  echo "        Expected: $UBUNTU_WSL_SHA256"
  echo "        Actual  : $ACTUAL_UBUNTU_SHA256"
  exit 1
fi

echo "  [ok] Ubuntu 24.04 WSL verified."

# ------------------------------------------------------------
# Docker Desktop installer
# ------------------------------------------------------------
echo ""
echo "[export] Preparing Docker Desktop Windows x64 installer..."

DOCKER_INSTALLER="$OFFLINE_DEPS_DIR/Docker Desktop Installer.exe"
DOCKER_INSTALLER_SHA_FILE="$OFFLINE_DEPS_DIR/docker-desktop.sha256"

DOCKER_NEEDS_DOWNLOAD="1"

if [ -s "$DOCKER_INSTALLER" ] && [ -s "$DOCKER_INSTALLER_SHA_FILE" ]; then
  CACHED_DOCKER_SHA256="$(awk 'NF {print $1; exit}' "$DOCKER_INSTALLER_SHA_FILE")"
  CURRENT_DOCKER_SHA256="$(sha256sum "$DOCKER_INSTALLER" | awk '{print $1}')"

  if [ "$CURRENT_DOCKER_SHA256" = "$CACHED_DOCKER_SHA256" ]; then
    echo "  [ok] Existing: $(basename "$DOCKER_INSTALLER")"
    echo "  [info] Size: $(du -h "$DOCKER_INSTALLER" | cut -f1)"
    DOCKER_NEEDS_DOWNLOAD="0"
  else
    echo "  [warn] Existing Docker Desktop installer checksum mismatch."
    rm -f "$DOCKER_INSTALLER"
  fi
elif [ -s "$DOCKER_INSTALLER" ]; then
  echo "  [ok] Existing: $(basename "$DOCKER_INSTALLER")"
  echo "  [info] Size: $(du -h "$DOCKER_INSTALLER" | cut -f1)"
  DOCKER_NEEDS_DOWNLOAD="0"
else
  :
fi

if [ "$DOCKER_NEEDS_DOWNLOAD" = "1" ]; then
  download_resumable "$DOCKER_DESKTOP_URL" "$DOCKER_INSTALLER" "Docker Desktop Installer"
fi

if [ ! -s "$DOCKER_INSTALLER" ]; then
  echo "[error] Docker Desktop installer is missing or empty."
  exit 1
fi

DOCKER_INSTALLER_SHA256="$(sha256sum "$DOCKER_INSTALLER" | awk '{print $1}')"
printf '%s  %s\n' "$DOCKER_INSTALLER_SHA256" "$(basename "$DOCKER_INSTALLER")" > "$DOCKER_INSTALLER_SHA_FILE"
echo "  [ok] Docker Desktop installer verified."

# ------------------------------------------------------------
# Docker image
# ------------------------------------------------------------
echo ""
echo "[export] Saving Docker image: $IMAGE_NAME"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[error] Image not found locally: $IMAGE_NAME"
  exit 1
fi

rm -f "$ABS_OUT/image.tar"
docker save -o "$BUNDLE_DIR/image.tar" "$IMAGE_NAME"

if [ ! -s "$BUNDLE_DIR/image.tar" ]; then
  echo "[error] image.tar was not created correctly."
  exit 1
fi

IMAGE_SHA256="$(sha256sum "$BUNDLE_DIR/image.tar" | awk '{print $1}')"
echo "  [ok] image.tar"

# ------------------------------------------------------------
# Docker volumes
# ------------------------------------------------------------
echo ""
echo "[export] Exporting Docker volumes..."

# ایجاد پوشه جداگانه برای ولوم‌ها
VOLUMES_OUT="$BUNDLE_DIR/volumes"
mkdir -p "$VOLUMES_OUT"

declare -A ACTUAL_VOLUMES

for logical_volume in "${VOLUMES[@]}"; do
  actual_volume="$(resolve_volume "$logical_volume" || true)"

  if [ -z "$actual_volume" ]; then
    echo "[error] Docker volume not found: $logical_volume"
    echo "        Start DevBox Lite once and make sure all volumes exist."
    exit 1
  fi

  ACTUAL_VOLUMES["$logical_volume"]="$actual_volume"

  # ذخیره آرشیو داخل پوشه volumes
  archive="$VOLUMES_OUT/vol-${logical_volume}.tar.gz"
  rm -f "$archive"

  docker run --rm \
    --mount "type=volume,source=${actual_volume},target=/volume,readonly" \
    --mount "type=bind,source=${VOLUMES_OUT},target=/backup" \
    "$IMAGE_NAME" \
    sh -c "tar czf /backup/vol-${logical_volume}.tar.gz -C /volume ."

  if [ ! -s "$archive" ]; then
    echo "[error] Volume archive was not created: $archive"
    exit 1
  fi

  if ! tar -tzf "$archive" >/dev/null 2>&1; then
    echo "[error] Invalid volume archive: $archive"
    exit 1
  fi

  sha="$(sha256sum "$archive" | awk '{print $1}')"
  echo "  [ok] $logical_volume -> $(basename "$archive")"
done

# ------------------------------------------------------------
# Project source
# ------------------------------------------------------------
echo ""
echo "[export] Packaging project source code..."

rm -f "$BUNDLE_DIR/project-src.tar.gz"

tar \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='vendor' \
  --exclude='.env' \
  --exclude='devbox-offline' \
  --exclude='out' \
  --exclude='backups' \
  -czf "$BUNDLE_DIR/project-src.tar.gz" \
  -C "$PROJECT_ROOT" .

if [ ! -s "$BUNDLE_DIR/project-src.tar.gz" ]; then
  echo "[error] project-src.tar.gz was not created."
  exit 1
fi

PROJECT_SHA256="$(sha256sum "$BUNDLE_DIR/project-src.tar.gz" | awk '{print $1}')"

# ------------------------------------------------------------
# Prebuilt
# ------------------------------------------------------------
if [ -d "$PROJECT_ROOT/prebuilt" ]; then
  echo ""
  echo "[export] Packaging prebuilt directory..."
  rm -f "$BUNDLE_DIR/prebuilt.tar.gz"
  tar czf "$BUNDLE_DIR/prebuilt.tar.gz" -C "$PROJECT_ROOT" prebuilt

  PREBUILT_SHA256="$(sha256sum "$BUNDLE_DIR/prebuilt.tar.gz" | awk '{print $1}')"
  echo "  [ok] prebuilt.tar.gz"
else
  rm -f "$BUNDLE_DIR/prebuilt.tar.gz"
  echo ""
  echo "[info] prebuilt directory not found; skipping."
fi

# ------------------------------------------------------------
# Copy installer scripts
# ------------------------------------------------------------
echo ""
echo "[export] Copying offline installer scripts..."

rm -rf "$BUNDLE_DIR/scripts"
mkdir -p "$BUNDLE_DIR/scripts"

cp "$PROJECT_ROOT/scripts/import.ps1" "$BUNDLE_DIR/scripts/import.ps1"

if [ ! -f "$PROJECT_ROOT/scripts/import.ps1" ]; then
  echo "[error] scripts/import.ps1 not found in project."
  exit 1
fi

echo "  [ok] import.ps1"

# Generate Windows-side validation and feature-management scripts first.
# Complex PowerShell logic is kept outside CMD to avoid cmd.exe parser issues.
cat > "$BUNDLE_DIR/scripts/validate-offline.ps1" <<'PS1'
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$PackageRoot)
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { Write-Host "[ERROR] $Message"; exit 1 }
try {
    Write-Host '  [validate] Checking Windows version...'
    $os = Get-CimInstance Win32_OperatingSystem; $build=[int]$os.BuildNumber; $caption=[string]$os.Caption
    $supported=(($caption -match 'Windows 10') -and ($build -ge 19045)) -or (($caption -match 'Windows 11') -and ($build -ge 22631))
    if (-not $supported) { Fail "Unsupported Windows version: $caption build $build. Required: Windows 10 22H2 build 19045+, or Windows 11 23H2 build 22631+." }
    Write-Host '  [validate] Checking 64-bit Windows...'; if (-not [Environment]::Is64BitOperatingSystem) { Fail 'A 64-bit Windows installation is required.' }
    Write-Host '  [validate] Checking physical memory...'; $ram=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    if ($ram -lt 8GB) { $ramGb=[math]::Round($ram/1GB,1); Fail "At least 8 GB of RAM is required. Detected: ${ramGb} GB." }
    Write-Host '  [validate] Checking hardware virtualization...'; $cs=Get-CimInstance Win32_ComputerSystem; $cpu=Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cs.HypervisorPresent -eq $true) { Write-Host '  [OK] Windows hypervisor is running; hardware virtualization is available.' }
    elseif ($cpu.VirtualizationFirmwareEnabled -eq $true) { Write-Host '  [OK] Hardware virtualization is enabled in firmware.' }
    elseif ($null -eq $cpu.VirtualizationFirmwareEnabled) { Write-Host '  [WARN] Firmware virtualization state could not be detected. Continuing.' }
    else { Fail 'Hardware virtualization is not available. Enable Intel VT-x or AMD-V/SVM in BIOS/UEFI and ensure Windows virtualization features can start.' }
    $required=@(
      @{Path=(Join-Path $PackageRoot 'offline-deps\\wsl.x64.msi');Name='WSL MSI'},
      @{Path=(Join-Path $PackageRoot 'offline-deps\\ubuntu-24.04.4-wsl-amd64.wsl');Name='Ubuntu 24.04 WSL package'},
      @{Path=(Join-Path $PackageRoot 'offline-deps\\Docker Desktop Installer.exe');Name='Docker Desktop installer'},
      @{Path=(Join-Path $PackageRoot 'image.tar');Name='DevBox Docker image'},
      @{Path=(Join-Path $PackageRoot 'scripts\\import.ps1');Name='import.ps1'},
      @{Path=(Join-Path $PackageRoot 'scripts\\manage-wsl-features.ps1');Name='manage-wsl-features.ps1'},
      @{Path=(Join-Path $PackageRoot 'scripts\\check-wsl-distro.ps1');Name='check-wsl-distro.ps1'},
      @{Path=(Join-Path $PackageRoot 'scripts\\check-restart-required.ps1');Name='check-restart-required.ps1'})
    foreach($item in $required){if(-not(Test-Path -LiteralPath $item.Path -PathType Leaf)){Fail "Required offline package file was not found: $($item.Name)`n        $($item.Path)"}}
    Write-Host '  [OK] Windows prerequisites passed.'; Write-Host '  [OK] Required offline package files found.'; exit 0
} catch { Write-Host "[ERROR] Validation failed: $($_.Exception.Message)"; exit 1 }
PS1

echo "  [ok] validate-offline.ps1"

cat > "$BUNDLE_DIR/scripts/manage-wsl-features.ps1" <<'PS1'
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
function Get-FeatureState([string]$Name){(Get-WindowsOptionalFeature -Online -FeatureName $Name).State}
try{
 Write-Host '  Checking WSL2 Windows features...'; $wslState=Get-FeatureState 'Microsoft-Windows-Subsystem-Linux'; $vmpState=Get-FeatureState 'VirtualMachinePlatform'
 Write-Host "  WSL state                 : $wslState"; Write-Host "  Virtual Machine Platform : $vmpState"; $changed=$false
 if($wslState -ne 'Enabled'){Write-Host '  Enabling Windows Subsystem for Linux...'; Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All -NoRestart -ErrorAction Stop|Out-Null; $wslState=Get-FeatureState 'Microsoft-Windows-Subsystem-Linux'; if($wslState -ne 'Enabled'){Write-Host "[ERROR] Windows Subsystem for Linux did not reach Enabled state. Current state: $wslState";exit 1}; Write-Host '  [OK] Windows Subsystem for Linux enabled.';$changed=$true}else{Write-Host '  [OK] Windows Subsystem for Linux is already enabled.'}
 if($vmpState -ne 'Enabled'){Write-Host '  Enabling Virtual Machine Platform...'; Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -All -NoRestart -ErrorAction Stop|Out-Null; $vmpState=Get-FeatureState 'VirtualMachinePlatform'; if($vmpState -ne 'Enabled'){Write-Host "[ERROR] Virtual Machine Platform did not reach Enabled state. Current state: $vmpState";exit 1}; Write-Host '  [OK] Virtual Machine Platform enabled.';$changed=$true}else{Write-Host '  [OK] Virtual Machine Platform is already enabled.'}
 if($changed){Write-Host '';Write-Host '  [OK] Required WSL2 Windows features are enabled.';Write-Host '  [INFO] A Windows restart is required before continuing.';exit 3010}
 Write-Host '';Write-Host '  [OK] Required WSL2 Windows features are already enabled.';exit 0
}catch{Write-Host "[ERROR] Failed to configure WSL2 Windows features: $($_.Exception.Message)";exit 1}
PS1

echo "  [ok] manage-wsl-features.ps1"

cat > "$BUNDLE_DIR/scripts/check-wsl-distro.ps1" <<'PS1'
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Distribution)
$ErrorActionPreference='Stop'
try{$distros=@(& wsl.exe --list --quiet 2>$null|ForEach-Object{($_ -replace "`0",'').Trim()}|Where-Object{$_});foreach($distro in $distros){if($distro -ieq $Distribution){exit 0}};exit 1}catch{exit 1}
PS1

echo "  [ok] check-wsl-distro.ps1"

cat > "$BUNDLE_DIR/scripts/check-restart-required.ps1" <<'PS1'
[CmdletBinding()]
param()
$ErrorActionPreference='SilentlyContinue';$pending=$false
if(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'){$pending=$true}
if(Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'){$pending=$true}
$sessionManager=Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue
if($null -ne $sessionManager.PendingFileRenameOperations){$pending=$true}
if($pending){Write-Host '  [INFO] Windows reports that a restart is required.';exit 3010};exit 0
PS1

echo "  [ok] check-restart-required.ps1"

cat > "$ABS_OUT/setup-offline.bat" <<'BAT'
@echo off
setlocal EnableExtensions DisableDelayedExpansion

title DevBox Lite - Offline Installer
color 0A

set "PACKAGE_ROOT=%~dp0devbox-data"
set "STATE_DIR=%ProgramData%\DevBoxLite"
set "STATE_FILE=%STATE_DIR%\offline-setup.state"
set "TASK_NAME=DevBoxLite-OfflineSetup"
set "RESUME_MODE=0"
set "STAGE=START"
set "DEST_PATH=D:\devbox-project"
set "WSL_MSI=%PACKAGE_ROOT%\offline-deps\wsl.x64.msi"

if /I "%~1"=="/resume" set "RESUME_MODE=1"
if "%RESUME_MODE%"=="1" goto :resume

echo ============================================================
echo   DevBox Lite - Offline Installer
echo   WSL2 + Ubuntu 24.04 + Docker Desktop + DevBox
echo ============================================================
echo.
echo [IMPORTANT] Hardware virtualization must be enabled in BIOS/UEFI.
echo.
echo Intel processors may use one of these names:
echo   Intel Virtualization Technology
echo   VT-x
echo   Virtualization Technology
echo.
echo AMD processors may use one of these names:
echo   SVM Mode
echo   AMD-V
echo   Secure Virtual Machine
echo.
echo Enable the matching option, save BIOS/UEFI changes, and restart Windows.
echo.
echo ============================================================
echo.

call :require_admin
if errorlevel 1 goto :fail

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
if not exist "%STATE_DIR%" goto :state_dir_error

set "DEST_PATH="
set /p "DEST_PATH=Enter destination path for project setup [Default: D:\devbox-project]: "
if not defined DEST_PATH set "DEST_PATH=D:\devbox-project"

rem A normal run always starts from START. Resume state is used only with /resume.
set "STAGE=START"
if exist "%STATE_FILE%" del /f /q "%STATE_FILE%" >nul 2>&1

goto :main

:resume
echo ============================================================
echo   DevBox Lite - Resuming Offline Installation
echo ============================================================
echo.

call :require_admin
if errorlevel 1 goto :fail

if not exist "%STATE_FILE%" goto :resume_state_error

for /f "usebackq delims=" %%A in ("%STATE_FILE%") do call :load_state_line "%%A"
if not defined DEST_PATH set "DEST_PATH=D:\devbox-project"

goto :main

:main
call :validate_package
set "VALIDATE_RC=%errorlevel%"
if not "%VALIDATE_RC%"=="0" goto :fail_validate

if /I "%STAGE%"=="START" goto :stage_features
if /I "%STAGE%"=="FEATURES_ENABLED" goto :stage_wsl
if /I "%STAGE%"=="WSL_INSTALLED" goto :stage_ubuntu
if /I "%STAGE%"=="UBUNTU_INSTALLED" goto :stage_docker
if /I "%STAGE%"=="DOCKER_INSTALLED" goto :stage_restore
if /I "%STAGE%"=="RESTORED" goto :stage_verify

echo [ERROR] Unknown installer stage: %STAGE%
goto :fail

:fail_validate
set "FAIL_CODE=%VALIDATE_RC%"
goto :fail

:stage_features
call :enable_wsl_features
if errorlevel 3010 exit /b 0
if errorlevel 1 goto :fail

:stage_wsl
call :install_wsl
if errorlevel 1 goto :fail

:stage_ubuntu
call :install_ubuntu
if errorlevel 1 goto :fail

:stage_docker
call :install_docker
if errorlevel 3010 exit /b 0
if errorlevel 1 goto :fail

:stage_restore
call :restore_devbox
if errorlevel 1 goto :fail

:stage_verify
call :verify
if errorlevel 1 goto :fail

call :cleanup_success

echo.
echo ============================================================
echo   DevBox Lite Offline Installation COMPLETED
echo ============================================================
echo.
echo Project location:
echo   %DEST_PATH%
echo.
echo WSL2 + Ubuntu 24.04 + Docker Desktop + DevBox are ready.
echo.
pause
exit /b 0

:require_admin
net session >nul 2>&1
if errorlevel 1 goto :not_admin
exit /b 0

:not_admin
echo [ERROR] Administrator privileges are required.
echo         Right-click setup-offline.bat and choose:
echo         Run as administrator
echo.
pause
exit /b 1

:validate_package
echo [1/6] Validating Windows and offline package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\validate-offline.ps1" -PackageRoot "%PACKAGE_ROOT%"
if errorlevel 1 exit /b 1
exit /b 0

:enable_wsl_features
echo.
echo [2/6] Checking Windows WSL2 components...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\manage-wsl-features.ps1"
set "FEATURE_RC=%errorlevel%"
if "%FEATURE_RC%"=="0" goto :features_ready
if "%FEATURE_RC%"=="3010" goto :features_restart
echo [ERROR] Failed to configure required WSL2 Windows features.
exit /b 1

:features_ready
call :save_stage FEATURES_ENABLED
exit /b %errorlevel%

:features_restart
call :save_stage FEATURES_ENABLED
if errorlevel 1 exit /b 1

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /create /tn "%TASK_NAME%" /sc onlogon /rl HIGHEST /tr "\"%~f0\" /resume" /f >nul 2>&1
if errorlevel 1 goto :resume_task_error

echo.
echo   Windows WSL2 components were enabled.
echo   A restart is required before installation can continue.
echo   The installer will resume automatically after login.
echo.
shutdown /r /t 10 /c "DevBox Lite Offline Setup requires a restart to continue WSL2 installation."
exit /b 3010

:install_wsl
echo.
echo [3/6] Installing WSL from the offline MSI...

where wsl.exe >nul 2>&1
if errorlevel 1 goto :wsl_command_missing

wsl.exe --version >nul 2>&1
if not errorlevel 1 goto :wsl_ready

echo   Installing WSL MSI...
msiexec.exe /i "%WSL_MSI%" /passive /norestart
if errorlevel 1 goto :wsl_install_error

:wsl_ready
wsl.exe --set-default-version 2 >nul 2>&1
if errorlevel 1 goto :wsl_default_error

call :save_stage WSL_INSTALLED
if errorlevel 1 exit /b 1

echo   [OK] WSL2 is installed and default version is 2.
exit /b 0

:install_ubuntu
echo.
echo [4/6] Installing Ubuntu 24.04 offline...
set "UBUNTU_WSL=%PACKAGE_ROOT%\offline-deps\ubuntu-24.04.4-wsl-amd64.wsl"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-distro.ps1" -Distribution "Ubuntu-24.04"
set "UBUNTU_CHECK_RC=%errorlevel%"
if "%UBUNTU_CHECK_RC%"=="0" goto :ubuntu_exists
if not "%UBUNTU_CHECK_RC%"=="1" goto :ubuntu_check_error

echo   Installing Ubuntu from:
echo     %UBUNTU_WSL%
wsl.exe --install --from-file "%UBUNTU_WSL%" --no-launch
if errorlevel 1 goto :ubuntu_install_error

set /a UBUNTU_VERIFY_COUNT=0

:ubuntu_verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-distro.ps1" -Distribution "Ubuntu-24.04"
if not errorlevel 1 goto :ubuntu_configure
set /a UBUNTU_VERIFY_COUNT+=1
if %UBUNTU_VERIFY_COUNT% GEQ 15 goto :ubuntu_registration_error
timeout /t 2 /nobreak >nul
goto :ubuntu_verify

:ubuntu_exists
echo   [OK] Ubuntu-24.04 is already installed.
goto :ubuntu_configure

:ubuntu_configure
wsl.exe --set-version Ubuntu-24.04 2 >nul 2>&1
if errorlevel 1 goto :ubuntu_wsl2_error
wsl.exe --set-default Ubuntu-24.04 >nul 2>&1
if errorlevel 1 goto :ubuntu_default_error

call :save_stage UBUNTU_INSTALLED
if errorlevel 1 exit /b 1

echo   [OK] Ubuntu-24.04 is installed as WSL2 and set as default distro.
exit /b 0

:install_docker
echo.
echo [5/6] Installing Docker Desktop offline...
set "DOCKER_EXE=%PACKAGE_ROOT%\offline-deps\Docker Desktop Installer.exe"
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

if exist "%DOCKER_DESKTOP_EXE%" goto :docker_start

echo   Installing Docker Desktop for all users...
start /wait "" "%DOCKER_EXE%" install --accept-license --backend=wsl-2 --no-windows-containers
if errorlevel 1 goto :docker_install_error

call :check_restart_required
if errorlevel 3010 goto :docker_restart_required
if errorlevel 1 goto :docker_restart_check_error

:docker_start
if not exist "%DOCKER_DESKTOP_EXE%" goto :docker_exe_missing
start "" "%DOCKER_DESKTOP_EXE%"

echo   Waiting for Docker Engine...
set /a WAIT_COUNT=0

docker_wait_loop:
set /a WAIT_COUNT+=1
timeout /t 5 /nobreak >nul
docker version >nul 2>&1
if not errorlevel 1 goto :docker_ready
if %WAIT_COUNT% GEQ 60 goto :docker_timeout
goto :docker_wait_loop

:docker_ready
call :save_stage DOCKER_INSTALLED
if errorlevel 1 exit /b 1

echo   [OK] Docker Engine is ready.
exit /b 0

:docker_restart_required
call :save_stage DOCKER_INSTALLED
if errorlevel 1 exit /b 1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /create /tn "%TASK_NAME%" /sc onlogon /rl HIGHEST /tr "\"%~f0\" /resume" /f >nul 2>&1
if errorlevel 1 goto :resume_task_error
echo.
echo   Docker Desktop installation requires a Windows restart.
echo   The installer will resume automatically after login.
echo.
shutdown /r /t 10 /c "DevBox Lite Offline Setup requires a restart to continue DevBox installation."
exit /b 3010

:docker_restart_check_error
echo [ERROR] Could not determine whether Windows requires a restart after Docker installation.
exit /b 1

:check_restart_required
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-restart-required.ps1"
exit /b %errorlevel%

:restore_devbox
echo.
echo [6/6] Restoring DevBox Lite to:
echo        %DEST_PATH%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\import.ps1" -InputPath "%PACKAGE_ROOT%" -TargetProj "%DEST_PATH%"
if errorlevel 1 goto :restore_error

call :save_stage RESTORED
if errorlevel 1 exit /b 1
exit /b 0

:verify
echo.
echo [verify] Checking final installation...

where wsl.exe >nul 2>&1
if errorlevel 1 goto :verify_wsl_missing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-distro.ps1" -Distribution "Ubuntu-24.04"
if errorlevel 1 goto :verify_ubuntu_missing

docker version >nul 2>&1
if errorlevel 1 goto :verify_docker_missing

if not exist "%DEST_PATH%\docker\compose\docker-compose.yml" goto :verify_project_missing

echo   [OK] WSL2
echo   [OK] Ubuntu 24.04
echo   [OK] Docker Desktop / Docker Engine
echo   [OK] DevBox project files
exit /b 0

:save_stage
set "NEW_STAGE=%~1"
set "SAVE_RC=0"
>"%STATE_FILE%" echo DEST_PATH=%DEST_PATH%
if errorlevel 1 set "SAVE_RC=1"
if "%SAVE_RC%"=="0" (
    >>"%STATE_FILE%" echo STAGE=%NEW_STAGE%
    if errorlevel 1 set "SAVE_RC=1"
)
set "STAGE=%NEW_STAGE%"
if not "%SAVE_RC%"=="0" (
    echo [ERROR] Could not save installer state: %STATE_FILE%
    exit /b %SAVE_RC%
)
exit /b 0

:load_state_line
set "STATE_LINE=%~1"
for /f "tokens=1,* delims==" %%A in ("%STATE_LINE%") do call :apply_state "%%A" "%%B"
exit /b 0

:apply_state
if /I "%~1"=="DEST_PATH" set "DEST_PATH=%~2"
if /I "%~1"=="STAGE" set "STAGE=%~2"
exit /b 0

:cleanup_success
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
if exist "%STATE_FILE%" del /f /q "%STATE_FILE%" >nul 2>&1
exit /b 0

:state_dir_error
echo [ERROR] Could not create state directory:
echo         %STATE_DIR%
goto :fail

:resume_state_error
echo [ERROR] Resume state was not found:
echo         %STATE_FILE%
echo Run setup-offline.bat normally instead.
goto :fail

:resume_task_error
echo [ERROR] Could not create the automatic resume task.
echo         After restart, run setup-offline.bat /resume manually.
exit /b 1

:wsl_command_missing
echo [ERROR] wsl.exe is not available after enabling WSL.
echo         Restart Windows and run setup-offline.bat /resume.
exit /b 1

:wsl_install_error
echo [ERROR] WSL MSI installation failed.
exit /b 1

:wsl_default_error
echo [ERROR] Could not set WSL default version to 2.
exit /b 1

:ubuntu_install_error
echo [ERROR] Failed to install Ubuntu 24.04 from the offline .wsl file.
exit /b 1

:ubuntu_wsl2_error
echo [ERROR] Ubuntu-24.04 could not be set to WSL2.
exit /b 1

:ubuntu_default_error
echo [ERROR] Could not set Ubuntu-24.04 as the default WSL distribution.
exit /b 1

:docker_install_error
echo [ERROR] Docker Desktop installation failed.
exit /b 1

:docker_exe_missing
echo [ERROR] Docker Desktop executable was not found after installation.
exit /b 1

:docker_timeout
echo [ERROR] Docker Engine did not become ready within 5 minutes.
echo         Open Docker Desktop and check its status.
exit /b 1

:restore_error
echo [ERROR] DevBox restore failed.
exit /b 1

:verify_wsl_missing
echo [ERROR] wsl.exe is not available.
exit /b 1

:verify_ubuntu_missing
echo [ERROR] Ubuntu-24.04 is not registered.
exit /b 1

:verify_docker_missing
echo [ERROR] Docker Engine is not available.
exit /b 1

:verify_project_missing
echo [ERROR] DevBox Compose file was not restored.
exit /b 1

:fail
if not defined FAIL_CODE set "FAIL_CODE=%errorlevel%"
if "%FAIL_CODE%"=="0" set "FAIL_CODE=1"

echo.
echo ============================================================
echo   DevBox Lite Offline Installation FAILED
echo ============================================================
echo.
echo Failed stage:
echo   %STAGE%
echo.
echo State file:
echo   %STATE_FILE%
echo.
echo Exit code: %FAIL_CODE%
echo.
echo Fix the reported problem and run setup-offline.bat again.
echo.
pause
exit /b %FAIL_CODE%
BAT

# Validate generated files before package creation continues.
python3 - "$ABS_OUT/setup-offline.bat" "$BUNDLE_DIR/scripts/validate-offline.ps1" "$BUNDLE_DIR/scripts/manage-wsl-features.ps1" "$BUNDLE_DIR/scripts/check-wsl-distro.ps1" "$BUNDLE_DIR/scripts/check-restart-required.ps1" <<'PY'
from pathlib import Path
import re
import sys

bat = Path(sys.argv[1])
validate = Path(sys.argv[2])
features = Path(sys.argv[3])
wsl_distro = Path(sys.argv[4])
restart_check = Path(sys.argv[5])

bat_text = bat.read_text(encoding='utf-8')
validate_text = validate.read_text(encoding='utf-8')
features_text = features.read_text(encoding='utf-8')
wsl_distro_text = wsl_distro.read_text(encoding='utf-8')
restart_check_text = restart_check.read_text(encoding='utf-8')

required_labels = [
    'main', 'resume', 'require_admin', 'validate_package',
    'enable_wsl_features', 'install_wsl', 'install_ubuntu',
    'install_docker', 'restore_devbox', 'verify', 'save_stage',
    'load_state_line', 'apply_state', 'cleanup_success', 'fail',
]
required_calls = [
    'call :validate_package',
    'call :enable_wsl_features',
    'call :install_wsl',
    'call :install_ubuntu',
    'call :install_docker',
    'call :restore_devbox',
    'call :verify',
]
labels = set(re.findall(r'^\s*:([A-Za-z0-9_]+)\s*$', bat_text, re.M))
missing = [x for x in required_labels if x not in labels]
if missing:
    raise SystemExit('Generated BAT validation failed: missing labels: ' + ', '.join(missing))
missing = [x for x in required_calls if x not in bat_text]
if missing:
    raise SystemExit('Generated BAT validation failed: missing calls: ' + ', '.join(missing))
if 'goto :eof' in bat_text.lower():
    raise SystemExit('Generated BAT validation failed: goto :eof is not permitted.')
if 'validate-offline.ps1' not in bat_text or 'manage-wsl-features.ps1' not in bat_text:
    raise SystemExit('Generated BAT validation failed: required external PowerShell scripts are not referenced.')
if 'call :save_stage START' in bat_text:
    raise SystemExit('Generated BAT validation failed: startup must not depend on save_stage START.')
if re.search(r'for\s+/f[^\n]*powershell\.exe', bat_text, re.I):
    raise SystemExit('Generated BAT validation failed: inline PowerShell for /f parser pattern detected.')
if 'param(' not in validate_text or '-LiteralPath' not in validate_text:
    raise SystemExit('Generated validation script check failed.')
if 'exit 3010' not in features_text or 'Enable-WindowsOptionalFeature' not in features_text:
    raise SystemExit('Generated WSL feature script check failed.')
if '$LASTEXITCODE' in features_text:
    raise SystemExit('Generated WSL feature script validation failed: LASTEXITCODE must not be used for PowerShell feature cmdlets.')
if 'RestartNeeded' not in features_text:
    raise SystemExit('Generated WSL feature script validation failed: RestartNeeded handling is missing.')
if 'HypervisorPresent' not in validate_text:
    raise SystemExit('Generated validation script check failed: HypervisorPresent handling is missing.')
if '$LASTEXITCODE' in features_text or 'RestartNeeded' in features_text:
    raise SystemExit('Generated WSL feature script validation failed.')
if 'check-wsl-distro.ps1' not in bat_text or 'check-restart-required.ps1' not in bat_text:
    raise SystemExit('Generated BAT validation failed: helper scripts are not referenced.')
if 'ubuntu_registration_wait' in bat_text:
    raise SystemExit('Generated BAT validation failed: legacy ubuntu_registration_wait label is still present.')
if 'findstr /I /X \"Ubuntu-24.04\"' in bat_text:
    raise SystemExit('Generated BAT validation failed: fragile Ubuntu findstr detection is still present.')
if 'Ubuntu-24.04' not in wsl_distro_text or '--list --quiet' not in wsl_distro_text:
    raise SystemExit('Generated WSL distro helper validation failed.')
if 'RebootPending' not in restart_check_text or 'RebootRequired' not in restart_check_text:
    raise SystemExit('Generated restart helper validation failed.')
print('  [ok] Generated setup-offline.bat structural validation passed')
print('  [ok] Generated PowerShell validation scripts passed')
PY

echo "  [ok] setup-offline.bat"


# ------------------------------------------------------------
# Manifest
# ------------------------------------------------------------
echo ""
echo "[export] Generating manifest.txt..."

CURRENT_DATE="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "format_version:2"
  echo "generated_at:$CURRENT_DATE"
  echo "architecture:x64"
  echo "wsl_distribution:Ubuntu-24.04"
  echo "ubuntu_wsl_filename:ubuntu-24.04.4-wsl-amd64.wsl"
  echo "ubuntu_wsl_url:$UBUNTU_WSL_URL"
  echo "ubuntu_wsl_sha256:$UBUNTU_WSL_SHA256"
  echo "wsl_msi_filename:$(basename "$WSL_MSI")"
  echo "wsl_msi_sha256:$WSL_MSI_SHA256"
  echo "docker_desktop_version:$DOCKER_DESKTOP_VERSION"
  echo "docker_desktop_installer_filename:$(basename "$DOCKER_INSTALLER")"
  echo "docker_desktop_installer_sha256:$DOCKER_INSTALLER_SHA256"
  echo "docker_desktop_download_policy:wsl-curl-then-windows-host-fallback"
  echo "image:$IMAGE_NAME"
  echo "image_sha256:$IMAGE_SHA256"
  echo "compose_project:$COMPOSE_PROJECT"
  echo "compose_file:docker/compose/docker-compose.yml"
  echo ""
  echo "[volumes]"
  for logical_volume in "${VOLUMES[@]}"; do
    echo "$logical_volume:${ACTUAL_VOLUMES[$logical_volume]}"
  done
  echo ""
  echo "[archives]"
  echo "project-src.tar.gz:$PROJECT_SHA256"
  if [ -f "$BUNDLE_DIR/prebuilt.tar.gz" ]; then
    echo "prebuilt.tar.gz:$PREBUILT_SHA256"
  fi
  for logical_volume in "${VOLUMES[@]}"; do
    archive="$BUNDLE_DIR/volumes/vol-${logical_volume}.tar.gz"
    echo "volumes/$(basename "$archive"):$(sha256sum "$archive" | awk '{print $1}')"
  done
} > "$BUNDLE_DIR/manifest.txt"

echo "  [ok] manifest.txt"

# ------------------------------------------------------------
# Final package verification
# ------------------------------------------------------------
echo ""
echo "[export] Final package verification..."

required_files=(
  "$ABS_OUT/setup-offline.bat"
  "$BUNDLE_DIR/manifest.txt"
  "$BUNDLE_DIR/image.tar"
  "$BUNDLE_DIR/project-src.tar.gz"
  "$BUNDLE_DIR/offline-deps/$(basename "$WSL_MSI")"
  "$BUNDLE_DIR/offline-deps/ubuntu-24.04.4-wsl-amd64.wsl"
  "$BUNDLE_DIR/offline-deps/Docker Desktop Installer.exe"
  "$BUNDLE_DIR/offline-deps/docker-desktop.sha256"
  "$BUNDLE_DIR/scripts/import.ps1"
  "$BUNDLE_DIR/scripts/validate-offline.ps1"
  "$BUNDLE_DIR/scripts/manage-wsl-features.ps1"
  "$BUNDLE_DIR/scripts/check-wsl-distro.ps1"
  "$BUNDLE_DIR/scripts/check-restart-required.ps1"
)

for f in "${required_files[@]}"; do
  if [ ! -s "$f" ]; then
    echo "[error] Required package file missing or empty:"
    echo "        $f"
    exit 1
  fi
done

echo "  [ok] All required package files are present."

echo ""
echo "========================================="
echo " Offline package created successfully"
echo "========================================="
echo "Location: $ABS_OUT"
echo ""
echo "The destination PC can now be completely offline."
echo "Run setup-offline.bat as Administrator."
