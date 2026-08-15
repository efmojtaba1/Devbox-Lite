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
# Clean resumable download helper
# ------------------------------------------------------------
# Reuses complete files, resumes *.part files, retries transient
# failures, prefers IPv4, and falls back to the Windows host curl.
#
# Progress is rendered by this script (not curl) as one in-place line:
#   42% | 103.8 MB / 246.9 MB | 7.31 MB/s | ETA 00:20
#
# Existing files keep the current quiet/reuse behavior.
# ------------------------------------------------------------
DOWNLOAD_RETRIES="8"
DOWNLOAD_RETRY_DELAY="5"
DOWNLOAD_MAX_RETRY_TIME="1800"
DOWNLOAD_CONNECT_TIMEOUT="30"
DOWNLOAD_SPEED_LIMIT="1024"
DOWNLOAD_SPEED_TIME="180"
DOWNLOAD_USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/151.0.0.0 Safari/537.36"

format_bytes() {
  local bytes="${1:-0}"
  if [ "$bytes" -ge 1073741824 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f GB", b/1073741824 }'
  elif [ "$bytes" -ge 1048576 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f MB", b/1048576 }'
  elif [ "$bytes" -ge 1024 ]; then
    awk -v b="$bytes" 'BEGIN { printf "%.1f KB", b/1024 }'
  else
    printf '%s B' "$bytes"
  fi
}

format_seconds() {
  local seconds="${1:-0}"
  [ "$seconds" -lt 0 ] && seconds=0
  printf '%02d:%02d' $((seconds / 60)) $((seconds % 60))
}

get_remote_size() {
  local url="${1:-}"
  curl -4 -fsSLI \
    --retry 3 \
    --retry-delay 2 \
    --connect-timeout "$DOWNLOAD_CONNECT_TIMEOUT" \
    --user-agent "$DOWNLOAD_USER_AGENT" \
    "$url" 2>/dev/null |
    awk 'BEGIN{IGNORECASE=1} /^content-length:/ { gsub(/\r/,"",$2); size=$2 } END{ if (size ~ /^[0-9]+$/) print size; else print 0 }'
}

render_download_progress() {
  local part="${1:-}"
  local total="${2:-0}"
  local start_epoch="${3:-0}"

  local current=0
  local elapsed=0
  local percent=0
  local speed=0
  local eta=0

  if [ -f "$part" ]; then
    current="$(stat -c '%s' "$part" 2>/dev/null || echo 0)"
  fi

  elapsed=$(( $(date +%s) - start_epoch ))
  [ "$elapsed" -lt 1 ] && elapsed=1

  if [ "$total" -gt 0 ]; then
    percent=$((current * 100 / total))
    [ "$percent" -gt 100 ] && percent=100
  fi

  speed=$((current / elapsed))

  if [ "$speed" -gt 0 ] && [ "$total" -gt "$current" ]; then
    eta=$(( (total - current) / speed ))
  fi

  local percent_text="${percent}%"
  local percent_pad_left=$(( (5 - ${#percent_text}) / 2 ))
  local percent_pad_right=$(( 5 - ${#percent_text} - percent_pad_left ))
  printf '\r    | %*s%s%*s | %10s / %-10s | %10s/s | ETA %s' \
    "$percent_pad_left" "" \
    "$percent_text" \
    "$percent_pad_right" "" \
    "$(format_bytes "$current")" \
    "$(format_bytes "$total")" \
    "$(format_bytes "$speed")" \
    "$(format_seconds "$eta")"
}

wait_for_download() {
  local pid="${1:-}"
  local part="${2:-}"
  local total="${3:-0}"
  local start_epoch="${4:-0}"
  local rc=0

  while kill -0 "$pid" >/dev/null 2>&1; do
    render_download_progress "$part" "$total" "$start_epoch"
    sleep 1
  done

  wait "$pid" || rc=$?
  render_download_progress "$part" "$total" "$start_epoch"
  printf '\n'
  return "$rc"
}

download_with_wsl_curl() {
  local url="${1:-}"
  local part="${2:-}"
  local total="${3:-0}"
  local resume_args=()
  local start_epoch="$(date +%s)"

  [ -s "$part" ] && resume_args=(--continue-at -)

  curl -4 \
    --silent \
    --show-error \
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
    "$url" >/dev/null 2>&1 &

  local pid=$!
  wait_for_download "$pid" "$part" "$total" "$start_epoch"
}

download_with_windows_host() {
  local url="${1:-}"
  local part="${2:-}"
  local total="${3:-0}"
  local win_output=""
  local resume="0"
  local start_epoch="$(date +%s)"

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
      '--silent',
      '--show-error',
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
  " >/dev/null 2>&1 &

  local pid=$!
  wait_for_download "$pid" "$part" "$total" "$start_epoch"
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
  echo "    URL: $url"

  if [ -s "$part" ]; then
    local bytes
    bytes="$(stat -c '%s' "$part" 2>/dev/null || echo 0)"
    echo "  [resume] Partial file detected: $(format_bytes "$bytes")"
  fi

  local total
  total="$(get_remote_size "$url")"
  [ -n "$total" ] || total=0

  if [ "$total" -gt 0 ] && [ -s "$part" ]; then
    total="$total"
  fi

  if download_with_wsl_curl "$url" "$part" "$total"; then
    :
  else
    local wsl_rc=$?
    echo "  [warn] WSL download failed (curl exit $wsl_rc)."

    if download_with_windows_host "$url" "$part" "$total"; then
      :
    else
      local host_rc=$?
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

  if ! curl -fsSL --retry 3 --retry-delay 2 \
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
  --exclude='prebuilt' \
  -czf "$BUNDLE_DIR/project-src.tar.gz" \
  -C "$PROJECT_ROOT" .

if [ ! -s "$BUNDLE_DIR/project-src.tar.gz" ]; then
  echo "[error] project-src.tar.gz was not created."
  exit 1
fi

if tar -tzf "$BUNDLE_DIR/project-src.tar.gz" | grep -qE '(^|/)prebuilt(/|$)'; then
  echo "[error] project-src.tar.gz unexpectedly contains prebuilt/."
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

if grep -q "Get-FileHash" "$PROJECT_ROOT/scripts/import.ps1"; then
  echo "[error] scripts/import.ps1 still depends on Get-FileHash."
  echo "        Replace it with the portable .NET SHA256 implementation before exporting."
  exit 1
fi

echo "  [ok] import.ps1"

# Generate Windows-side validation and feature-management scripts first.
# Complex PowerShell logic is kept outside CMD to avoid cmd.exe parser issues.
cat > "$BUNDLE_DIR/scripts/validate-offline.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot
)

$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    Write-Host "[ERROR] $Message"
    exit 1
}

try {
    Write-Host '  [validate] Checking Windows version...'
    $os = Get-CimInstance Win32_OperatingSystem
    $build = [int]$os.BuildNumber
    $caption = [string]$os.Caption
    $supported = (($caption -match 'Windows 10') -and ($build -ge 19045)) -or
                 (($caption -match 'Windows 11') -and ($build -ge 22631))

    if (-not $supported) {
        Fail "Unsupported Windows version: $caption build $build. Required: Windows 10 22H2 build 19045+, or Windows 11 23H2 build 22631+."
    }

    Write-Host '  [validate] Checking 64-bit Windows...'
    if (-not [Environment]::Is64BitOperatingSystem) {
        Fail 'A 64-bit Windows installation is required.'
    }

    Write-Host '  [validate] Checking physical memory...'
    $ram = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    if ($ram -lt 8GB) {
        $ramGb = [math]::Round($ram / 1GB, 1)
        Fail "At least 8 GB of RAM is required. Detected: ${ramGb} GB."
    }

    Write-Host '  [validate] Checking hardware virtualization...'
    $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
    $virtFirmware = $processor.VirtualizationFirmwareEnabled
    $hypervisorPresent = (Get-CimInstance Win32_ComputerSystem).HypervisorPresent

    if ($hypervisorPresent -eq $true) {
        Write-Host '  [OK] Windows hypervisor is running; hardware virtualization is available.'
    }
    elseif ($virtFirmware -eq $true) {
        Write-Host '  [OK] Hardware virtualization is enabled in firmware.'
    }
    elseif ($null -eq $virtFirmware) {
        Write-Host '  [WARN] Firmware virtualization state could not be detected. Continuing.'
    }
    else {
        Fail 'Hardware virtualization is unavailable. Enable Intel VT-x or AMD-V/SVM in BIOS/UEFI and ensure the Windows hypervisor can start.'
    }

    $required = @(
        @{ Path = (Join-Path $PackageRoot 'offline-deps\wsl.x64.msi'); Name = 'WSL MSI' },
        @{ Path = (Join-Path $PackageRoot 'offline-deps\ubuntu-24.04.4-wsl-amd64.wsl'); Name = 'Ubuntu 24.04 WSL package' },
        @{ Path = (Join-Path $PackageRoot 'offline-deps\Docker Desktop Installer.exe'); Name = 'Docker Desktop installer' },
        @{ Path = (Join-Path $PackageRoot 'image.tar'); Name = 'DevBox Docker image' },
        @{ Path = (Join-Path $PackageRoot 'scripts\import.ps1'); Name = 'import.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\manage-wsl-features.ps1'); Name = 'manage-wsl-features.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\check-wsl-distro.ps1'); Name = 'check-wsl-distro.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\check-wsl-ready.ps1'); Name = 'check-wsl-ready.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\check-restart-required.ps1'); Name = 'check-restart-required.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\check-docker-restart-required.ps1'); Name = 'check-docker-restart-required.ps1' }
    )

    foreach ($item in $required) {
        if (-not (Test-Path -LiteralPath $item.Path -PathType Leaf)) {
            Fail "Required offline package file was not found: $($item.Name)`n        $($item.Path)"
        }
    }

    Write-Host '  [OK] Windows prerequisites passed.'
    Write-Host '  [OK] Required offline package files found.'
    exit 0
}
catch {
    Write-Host "[ERROR] Validation failed: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] validate-offline.ps1"

cat > "$BUNDLE_DIR/scripts/manage-wsl-features.ps1" <<'PS1'
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    Write-Host '  Checking WSL2 Windows features...'

    $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

    Write-Host "  WSL state                 : $($wsl.State)"
    Write-Host "  Virtual Machine Platform : $($vmp.State)"

    $restartNeeded = $false

    if ($wsl.State -ne 'Enabled') {
        Write-Host '  Enabling Windows Subsystem for Linux...'

        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName Microsoft-Windows-Subsystem-Linux `
            -All `
            -NoRestart `
            -ErrorAction Stop | Out-Null

        $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

        if ($wsl.State -ne 'Enabled') {
            Write-Host '[ERROR] Failed to enable Windows Subsystem for Linux.'
            Write-Host "        Current state: $($wsl.State)"
            exit 1
        }

        Write-Host '  [OK] Windows Subsystem for Linux enabled.'
        $restartNeeded = $true
    }
    else {
        Write-Host '  [OK] Windows Subsystem for Linux is already enabled.'
    }

    if ($vmp.State -ne 'Enabled') {
        Write-Host '  Enabling Virtual Machine Platform...'

        Enable-WindowsOptionalFeature `
            -Online `
            -FeatureName VirtualMachinePlatform `
            -All `
            -NoRestart `
            -ErrorAction Stop | Out-Null

        $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

        if ($vmp.State -ne 'Enabled') {
            Write-Host '[ERROR] Failed to enable Virtual Machine Platform.'
            Write-Host "        Current state: $($vmp.State)"
            exit 1
        }

        Write-Host '  [OK] Virtual Machine Platform enabled.'
        $restartNeeded = $true
    }
    else {
        Write-Host '  [OK] Virtual Machine Platform is already enabled.'
    }

    if ($restartNeeded) {
        Write-Host ''
        Write-Host '  [OK] Required WSL2 Windows features are enabled.'
        Write-Host '  [INFO] Windows restart is required before continuing.'
        exit 3010
    }

    Write-Host ''
    Write-Host '  [OK] Required WSL2 Windows features are already enabled.'
    exit 0
}
catch {
    Write-Host "[ERROR] Failed to configure WSL2 Windows features: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] manage-wsl-features.ps1"

cat > "$BUNDLE_DIR/scripts/check-wsl-distro.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Distribution
)

$ErrorActionPreference = 'Stop'

try {
    $distros = @(
        wsl.exe --list --quiet 2>$null |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )

    if ($distros -contains $Distribution) {
        exit 0
    }

    exit 1
}
catch {
    Write-Host "[ERROR] Failed to query WSL distributions: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] check-wsl-distro.ps1"

cat > "$BUNDLE_DIR/scripts/check-wsl-ready.ps1" <<'PS1'
[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 90,
    [int]$PollSeconds = 3
)

$ErrorActionPreference = 'Stop'

try {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastReason = 'Waiting for WSL virtualization backend.'

    do {
        $computer = Get-CimInstance Win32_ComputerSystem
        $hypervisor = $computer.HypervisorPresent -eq $true
        $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
        $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

        if ($wsl.State -ne 'Enabled' -or $vmp.State -ne 'Enabled') {
            $lastReason = 'Required Windows WSL2 features are not enabled yet.'
        }
        elseif (-not $hypervisor) {
            $lastReason = 'Windows hypervisor is not running yet.'
        }
        else {
            wsl.exe --status *> $null
            if ($LASTEXITCODE -eq 0) {
                wsl.exe --version *> $null
                if ($LASTEXITCODE -eq 0) { exit 0 }
                $lastReason = 'WSL command is available but version query is not ready yet.'
            }
            else {
                $lastReason = 'WSL service is not ready yet.'
            }
        }
        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Host "  [WARN] $lastReason"
    Write-Host '  [INFO] WSL virtualization backend is not ready after waiting.'
    exit 3010
}
catch {
    Write-Host "[ERROR] Failed to check WSL readiness: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] check-wsl-ready.ps1"

cat > "$BUNDLE_DIR/scripts/check-restart-required.ps1" <<'PS1'
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

try {
    $pending = $false

    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($key in $keys) {
        if (Test-Path -LiteralPath $key) {
            $pending = $true
            break
        }
    }

    if (-not $pending) {
        try {
            $sessionManager = Get-ItemProperty `
                -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' `
                -Name PendingFileRenameOperations `
                -ErrorAction Stop

            if ($null -ne $sessionManager.PendingFileRenameOperations) {
                $pending = $true
            }
        }
        catch {
            # Property does not exist; no pending reboot from this source.
        }
    }

    if ($pending) {
        Write-Host '  [INFO] Windows restart is required.'
        exit 3010
    }

    exit 0
}
catch {
    Write-Host "[ERROR] Failed to check pending Windows restart: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] check-restart-required.ps1"

cat > "$BUNDLE_DIR/scripts/check-docker-restart-required.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Begin','Check')]
    [string]$Mode,
    [Parameter(Mandatory = $true)]
    [string]$StatePath
)

$ErrorActionPreference = 'Stop'

try {
    function Get-HyperVState {
        try { return (Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).State }
        catch { return 'Unknown' }
    }

    if ($Mode -eq 'Begin') {
        $dir = Split-Path -Parent $StatePath
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Set-Content -LiteralPath $StatePath -Value (Get-HyperVState) -Encoding ASCII
        exit 0
    }

    if (-not (Test-Path -LiteralPath $StatePath)) { exit 0 }
    $before = (Get-Content -LiteralPath $StatePath -ErrorAction Stop | Select-Object -First 1).Trim()
    $after = Get-HyperVState

    if ($before -ne 'Enabled' -and $after -eq 'Enabled') {
        Write-Host '  [INFO] Docker Desktop enabled Microsoft-Hyper-V during installation.'
        Write-Host '  [INFO] Windows restart is required before continuing.'
        exit 3010
    }

    exit 0
}
catch {
    Write-Host "[ERROR] Failed to check Docker restart requirement: $($_.Exception.Message)"
    exit 1
}
PS1

echo "  [ok] check-docker-restart-required.ps1"

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
set "STAGE=FEATURES"
call :enable_wsl_features
set "FEATURE_RC=%errorlevel%"
if "%FEATURE_RC%"=="0" goto :features_ready
if "%FEATURE_RC%"=="3010" goto :features_restart
goto :fail

:features_ready
call :save_stage FEATURES_ENABLED
if errorlevel 1 goto :fail
set "STAGE=INSTALL_WSL"
call :install_wsl
set "WSL_RC=%errorlevel%"
if "%WSL_RC%"=="0" goto :wsl_completed
if "%WSL_RC%"=="3010" goto :wsl_msi_restart
goto :fail

:wsl_completed
call :save_stage WSL_INSTALLED
if errorlevel 1 goto :fail
goto :stage_ubuntu

:features_restart
call :save_stage FEATURES_ENABLED
if errorlevel 1 goto :fail
call :schedule_restart
exit /b 3010

:stage_wsl
set "STAGE=INSTALL_WSL"
call :install_wsl
set "WSL_RC=%errorlevel%"
if "%WSL_RC%"=="0" goto :wsl_completed
if "%WSL_RC%"=="3010" goto :wsl_msi_restart
goto :fail

:wsl_msi_restart
call :save_stage WSL_INSTALLED
if errorlevel 1 goto :fail
call :schedule_restart
exit /b 3010

:stage_ubuntu
set "STAGE=INSTALL_UBUNTU"
call :ensure_wsl_ready
set "READY_RC=%errorlevel%"
if "%READY_RC%"=="0" goto :ubuntu_install_continue
if "%READY_RC%"=="3010" goto :ubuntu_readiness_restart
goto :fail

:ubuntu_readiness_restart
call :save_stage WSL_INSTALLED
if errorlevel 1 goto :fail
call :schedule_restart
exit /b 3010

:ubuntu_install_continue
call :install_ubuntu
if errorlevel 1 goto :fail
call :save_stage UBUNTU_INSTALLED
if errorlevel 1 goto :fail

goto :stage_docker

:stage_docker
set "STAGE=INSTALL_DOCKER"
call :install_docker
set "DOCKER_RC=%errorlevel%"
if "%DOCKER_RC%"=="0" goto :docker_completed
if "%DOCKER_RC%"=="3010" goto :docker_restart
goto :fail

:docker_completed
call :save_stage DOCKER_INSTALLED
if errorlevel 1 goto :fail
goto :stage_restore

:docker_restart
call :save_stage DOCKER_INSTALLED
if errorlevel 1 goto :fail
call :schedule_restart
exit /b 3010

:stage_restore
set "STAGE=RESTORE_DEVBOX"
call :restore_devbox
if errorlevel 1 goto :fail
call :save_stage RESTORED
if errorlevel 1 goto :fail

goto :stage_verify

:stage_verify
set "STAGE=VERIFY"
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
exit /b %errorlevel%

:install_wsl
echo.
echo [3/6] Installing WSL from the offline MSI...

where wsl.exe >nul 2>&1
if errorlevel 1 goto :wsl_command_missing

wsl.exe --version >nul 2>&1
if not errorlevel 1 goto :wsl_ready

echo   Installing WSL MSI...
msiexec.exe /i "%WSL_MSI%" /passive /norestart
set "WSL_MSI_RC=%errorlevel%"
if "%WSL_MSI_RC%"=="3010" exit /b 3010
if not "%WSL_MSI_RC%"=="0" goto :wsl_install_error

:wsl_ready
wsl.exe --set-default-version 2 >nul 2>&1
if errorlevel 1 goto :wsl_default_error

rem WSL MSI may return success while Windows still has a pending reboot.
rem Detect the actual Windows restart state instead of relying only on MSI 3010.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-restart-required.ps1"
set "WSL_RESTART_RC=%errorlevel%"
if "%WSL_RESTART_RC%"=="3010" exit /b 3010
if not "%WSL_RESTART_RC%"=="0" goto :wsl_install_error

echo   [OK] WSL2 is installed and default version is 2.
exit /b 0

:ensure_wsl_ready
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-ready.ps1" -TimeoutSeconds 90 -PollSeconds 3
exit /b %errorlevel%

:install_ubuntu
echo.
echo [4/6] Installing Ubuntu 24.04 offline...
set "UBUNTU_WSL=%PACKAGE_ROOT%\offline-deps\ubuntu-24.04.4-wsl-amd64.wsl"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-distro.ps1" -Distribution "Ubuntu-24.04"
if not errorlevel 1 goto :ubuntu_exists

echo   Installing Ubuntu from:
echo     %UBUNTU_WSL%
wsl.exe --install --from-file "%UBUNTU_WSL%" --no-launch
if errorlevel 1 goto :ubuntu_install_error

set "UBUNTU_VERIFY_COUNT=0"
:ubuntu_verify
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-distro.ps1" -Distribution "Ubuntu-24.04"
if not errorlevel 1 goto :ubuntu_configure

set /a UBUNTU_VERIFY_COUNT+=1
if %UBUNTU_VERIFY_COUNT% GEQ 15 goto :ubuntu_registration_error
timeout /t 2 /nobreak >nul
goto :ubuntu_verify

:ubuntu_exists
echo   [OK] Ubuntu-24.04 is already installed.

:ubuntu_configure
wsl.exe --set-version Ubuntu-24.04 2 >nul 2>&1
if errorlevel 1 goto :ubuntu_wsl2_error
wsl.exe --set-default Ubuntu-24.04 >nul 2>&1
if errorlevel 1 goto :ubuntu_default_error

echo   [OK] Ubuntu-24.04 is installed as WSL2 and set as default distro.
exit /b 0

:install_docker
echo.
echo [5/6] Installing Docker Desktop offline...
set "DOCKER_EXE=%PACKAGE_ROOT%\offline-deps\Docker Desktop Installer.exe"
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "DOCKER_RESTART_STATE=%STATE_DIR%\docker-hyperv.state"

if exist "%DOCKER_DESKTOP_EXE%" goto :docker_start

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-docker-restart-required.ps1" -Mode Begin -StatePath "%DOCKER_RESTART_STATE%"
if errorlevel 1 goto :docker_install_error

echo   Installing Docker Desktop for all users...
start /wait "" "%DOCKER_EXE%" install --accept-license --backend=wsl-2 --no-windows-containers
set "DOCKER_INSTALL_RC=%errorlevel%"
if "%DOCKER_INSTALL_RC%"=="3010" goto :docker_installer_restart
if not "%DOCKER_INSTALL_RC%"=="0" goto :docker_install_error

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-docker-restart-required.ps1" -Mode Check -StatePath "%DOCKER_RESTART_STATE%"
set "DOCKER_RESTART_RC=%errorlevel%"
if "%DOCKER_RESTART_RC%"=="3010" exit /b 3010
if not "%DOCKER_RESTART_RC%"=="0" goto :docker_install_error

:docker_start
if not exist "%DOCKER_DESKTOP_EXE%" goto :docker_exe_missing
start "" "%DOCKER_DESKTOP_EXE%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-restart-required.ps1"
set "RESTART_RC=%errorlevel%"
if "%RESTART_RC%"=="3010" exit /b 3010
if not "%RESTART_RC%"=="0" goto :docker_install_error

echo   Waiting for Docker Engine...
set /a WAIT_COUNT=0

:docker_wait_loop
set /a WAIT_COUNT+=1
timeout /t 5 /nobreak >nul
docker version >nul 2>&1
if not errorlevel 1 goto :docker_ready
if %WAIT_COUNT% GEQ 60 goto :docker_timeout
goto :docker_wait_loop

:docker_ready
echo   [OK] Docker Engine is ready.
exit /b 0

:docker_installer_restart
exit /b 3010

:restore_devbox
echo.
echo [6/6] Restoring DevBox Lite to:
echo        %DEST_PATH%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\import.ps1" -InputPath "%PACKAGE_ROOT%" -TargetProj "%DEST_PATH%"
if errorlevel 1 goto :restore_error
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

:schedule_restart
echo.
echo   Windows restart is required before installation can continue.
echo   The installer will resume automatically after login.
echo.

set "RESUME_WRAPPER=%STATE_DIR%\resume-offline-setup.cmd"
>"%RESUME_WRAPPER%" echo @echo off
>>"%RESUME_WRAPPER%" echo call "%~f0" /resume

if not exist "%RESUME_WRAPPER%" goto :resume_task_error

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /create /tn "%TASK_NAME%" /sc onlogon /delay 0000:15 /rl HIGHEST /tr "%ComSpec% /d /c ""%RESUME_WRAPPER%""" /f >nul 2>&1
if errorlevel 1 goto :resume_task_error

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if errorlevel 1 goto :resume_task_error

echo   [OK] Automatic resume task created and verified.
echo   [INFO] Windows will restart in 10 seconds.
shutdown /r /t 10 /c "DevBox Lite Offline Setup requires a restart to continue."
if errorlevel 1 goto :restart_schedule_error
exit /b 0

:save_stage
set "NEW_STAGE=%~1"
set "STATE_TMP=%STATE_FILE%.tmp"

rem Do not rely on ERRORLEVEL immediately after ECHO redirection.
rem CMD can preserve the previous stage return code (for example 3010).
if exist "%STATE_TMP%" del /f /q "%STATE_TMP%" >nul 2>&1
>"%STATE_TMP%" echo DEST_PATH=%DEST_PATH%
if not exist "%STATE_TMP%" goto :save_stage_error
>>"%STATE_TMP%" echo STAGE=%NEW_STAGE%

findstr /B /C:"DEST_PATH=" "%STATE_TMP%" >nul 2>&1
if errorlevel 1 goto :save_stage_error
findstr /B /C:"STAGE=%NEW_STAGE%" "%STATE_TMP%" >nul 2>&1
if errorlevel 1 goto :save_stage_error

move /Y "%STATE_TMP%" "%STATE_FILE%" >nul 2>&1
if errorlevel 1 goto :save_stage_error
if not exist "%STATE_FILE%" goto :save_stage_error

set "STAGE=%NEW_STAGE%"
exit /b 0

:save_stage_error
del /f /q "%STATE_TMP%" >nul 2>&1
echo [ERROR] Could not save installer state: %STATE_FILE%
exit /b 1

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
if exist "%STATE_DIR%\resume-offline-setup.cmd" del /f /q "%STATE_DIR%\resume-offline-setup.cmd" >nul 2>&1
if exist "%STATE_DIR%\docker-hyperv.state" del /f /q "%STATE_DIR%\docker-hyperv.state" >nul 2>&1
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
echo [ERROR] Could not create or verify the automatic resume task.
echo         After restart, run setup-offline.bat /resume manually.
exit /b 1

:restart_schedule_error
echo [ERROR] Windows restart could not be scheduled.
echo         Run setup-offline.bat /resume after restarting manually.
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

:ubuntu_registration_error
echo [ERROR] Ubuntu-24.04 was not registered after installation.
echo         Check WSL status and try setup-offline.bat again.
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
python3 - "$ABS_OUT/setup-offline.bat" "$BUNDLE_DIR/scripts/validate-offline.ps1" "$BUNDLE_DIR/scripts/manage-wsl-features.ps1" "$BUNDLE_DIR/scripts/check-wsl-distro.ps1" "$BUNDLE_DIR/scripts/check-wsl-ready.ps1" "$BUNDLE_DIR/scripts/check-restart-required.ps1" "$BUNDLE_DIR/scripts/check-docker-restart-required.ps1" "$BUNDLE_DIR/scripts/import.ps1" <<'PY'
from pathlib import Path
import re
import sys

bat = Path(sys.argv[1])
validate = Path(sys.argv[2])
features = Path(sys.argv[3])
distro = Path(sys.argv[4])
ready = Path(sys.argv[5])
restart = Path(sys.argv[6])
docker_restart = Path(sys.argv[7])

bat_text = bat.read_text(encoding='utf-8')
validate_text = validate.read_text(encoding='utf-8')
features_text = features.read_text(encoding='utf-8')
distro_text = distro.read_text(encoding='utf-8')
ready_text = ready.read_text(encoding='utf-8')
restart_text = restart.read_text(encoding='utf-8')
docker_restart_text = docker_restart.read_text(encoding='utf-8')

required_labels = [
    'main', 'resume', 'require_admin', 'validate_package',
    'enable_wsl_features', 'install_wsl', 'install_ubuntu',
    'install_docker', 'restore_devbox', 'verify', 'schedule_restart',
    'save_stage', 'load_state_line', 'apply_state', 'cleanup_success', 'save_stage_error', 'resume_task_error', 'restart_schedule_error',
    'fail', 'features_restart', 'wsl_msi_restart', 'docker_restart', 'ubuntu_readiness_restart',
]
required_calls = [
    'call :validate_package',
    'call :enable_wsl_features',
    'call :install_wsl',
    'call :install_ubuntu',
    'call :install_docker',
    'call :restore_devbox',
    'call :verify',
    'call :schedule_restart',
]

labels = re.findall(r'^\s*:([A-Za-z0-9_]+)\s*$', bat_text, re.M)
label_set = set(labels)
if len(labels) != len(label_set):
    duplicates = sorted({x for x in labels if labels.count(x) > 1})
    raise SystemExit('Generated BAT validation failed: duplicate labels: ' + ', '.join(duplicates))

if 'docker_wait_loop' in bat_text and ':docker_wait_loop' not in bat_text:
    raise SystemExit('Generated BAT validation failed: docker_wait_loop label is malformed.')

save_stage_block = bat_text.split(':save_stage\n', 1)[1].split(':save_stage_error\n', 1)[0]
if 'echo DEST_PATH=' in save_stage_block and 'if errorlevel 1 goto :save_stage_error' in save_stage_block.split('>>',1)[0]:
    raise SystemExit('Generated BAT validation failed: save_stage must not test stale ERRORLEVEL after ECHO redirection.')

missing = [x for x in required_labels if x not in label_set]
if missing:
    raise SystemExit('Generated BAT validation failed: missing labels: ' + ', '.join(missing))

missing = [x for x in required_calls if x not in bat_text]
if missing:
    raise SystemExit('Generated BAT validation failed: missing calls: ' + ', '.join(missing))

if 'goto :eof' in bat_text.lower():
    raise SystemExit('Generated BAT validation failed: goto :eof is not permitted.')

if 'ubuntu_registration_wait' in bat_text:
    raise SystemExit('Generated BAT validation failed: obsolete ubuntu_registration_wait label detected.')

if 'wsl.exe -l -q 2>nul | findstr /I /X "Ubuntu-24.04"' in bat_text:
    raise SystemExit('Generated BAT validation failed: obsolete Ubuntu findstr detection detected.')

if 'validate-offline.ps1' not in bat_text or 'manage-wsl-features.ps1' not in bat_text:
    raise SystemExit('Generated BAT validation failed: required PowerShell scripts are not referenced.')

if 'check-wsl-distro.ps1' not in bat_text or 'check-wsl-ready.ps1' not in bat_text or 'check-restart-required.ps1' not in bat_text or 'check-docker-restart-required.ps1' not in bat_text:
    raise SystemExit('Generated BAT validation failed: helper PowerShell scripts are not referenced.')

install_wsl_start = bat_text.find(':install_wsl')
install_ubuntu_start = bat_text.find(':install_ubuntu')
if install_wsl_start == -1 or install_ubuntu_start == -1 or install_ubuntu_start <= install_wsl_start:
    raise SystemExit('Generated BAT validation failed: install_wsl/install_ubuntu sections could not be located.')
install_wsl_text = bat_text[install_wsl_start:install_ubuntu_start]
if 'check-restart-required.ps1' not in install_wsl_text:
    raise SystemExit('Generated BAT validation failed: install_wsl must verify Windows pending restart state.')

if 'call :save_stage START' in bat_text:
    raise SystemExit('Generated BAT validation failed: startup must not depend on save_stage START.')

if re.search(r'for\s+/f[^\n]*powershell\.exe', bat_text, re.I):
    raise SystemExit('Generated BAT validation failed: inline PowerShell for /f parser pattern detected.')

if 'param(' not in validate_text or '-LiteralPath' not in validate_text:
    raise SystemExit('Generated validation script check failed.')
import_text = Path(sys.argv[8]).read_text(encoding='utf-8') if len(sys.argv) > 8 else ''
if 'Get-FileHash' in import_text:
    raise SystemExit('Generated import.ps1 validation failed: Get-FileHash dependency detected.')
if 'System.Security.Cryptography.SHA256' not in import_text:
    raise SystemExit('Generated import.ps1 validation failed: portable SHA256 implementation is missing.')

if '$LASTEXITCODE' in features_text:
    raise SystemExit('Generated WSL feature script validation failed: LASTEXITCODE must not be used.')

if 'Get-WindowsOptionalFeature' not in features_text or 'VirtualMachinePlatform' not in features_text:
    raise SystemExit('Generated WSL feature script validation failed: feature verification is missing.')

if 'wsl.exe --list --quiet' not in distro_text:
    raise SystemExit('Generated WSL distro helper validation failed.')

if 'wsl.exe --status' not in ready_text or 'HypervisorPresent' not in ready_text:
    raise SystemExit('Generated WSL readiness helper validation failed.')

if 'Microsoft-Hyper-V' not in docker_restart_text or 'Mode' not in docker_restart_text:
    raise SystemExit('Generated Docker restart helper validation failed.')

if 'RebootPending' not in restart_text and 'RebootRequired' not in restart_text:
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
MANIFEST_TMP="$BUNDLE_DIR/manifest.txt.tmp"
rm -f "$MANIFEST_TMP" "$BUNDLE_DIR/manifest.txt"

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
} > "$MANIFEST_TMP"

if [ ! -s "$MANIFEST_TMP" ]; then
  echo "[error] manifest.txt could not be generated."
  rm -f "$MANIFEST_TMP"
  exit 1
fi

mv -f "$MANIFEST_TMP" "$BUNDLE_DIR/manifest.txt"

if [ ! -s "$BUNDLE_DIR/manifest.txt" ]; then
  echo "[error] manifest.txt is missing or empty after generation."
  exit 1
fi

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
  "$BUNDLE_DIR/scripts/check-wsl-ready.ps1"
  "$BUNDLE_DIR/scripts/check-restart-required.ps1"
  "$BUNDLE_DIR/scripts/check-docker-restart-required.ps1"
)

if [ -d "$PROJECT_ROOT/prebuilt" ]; then
  required_files+=("$BUNDLE_DIR/prebuilt.tar.gz")
fi

for f in "${required_files[@]}"; do
  if [ ! -s "$f" ]; then
    echo "[error] Required package file missing or empty:"
    echo "        $f"
    exit 1
  fi
done

# Verify that the manifest contains the required metadata and hashes point
# to the actual package files. This prevents an incomplete/stale manifest
# from reaching the destination machine.
python3 - "$BUNDLE_DIR/manifest.txt" "$BUNDLE_DIR" "${VOLUMES[@]}" <<'PY'
from pathlib import Path
import hashlib
import sys

manifest = Path(sys.argv[1])
bundle = Path(sys.argv[2])
volumes = sys.argv[3:]

text = manifest.read_text(encoding='utf-8')
lines = [line.strip() for line in text.splitlines() if line.strip()]

required_prefixes = [
    'format_version:',
    'generated_at:',
    'architecture:',
    'wsl_distribution:',
    'ubuntu_wsl_filename:',
    'ubuntu_wsl_sha256:',
    'wsl_msi_filename:',
    'wsl_msi_sha256:',
    'docker_desktop_version:',
    'docker_desktop_installer_filename:',
    'docker_desktop_installer_sha256:',
    'docker_desktop_download_policy:',
    'image:',
    'image_sha256:',
    'compose_project:',
    'compose_file:',
    '[volumes]',
    '[archives]',
    'project-src.tar.gz:',
]

for prefix in required_prefixes:
    if not any(line.startswith(prefix) for line in lines):
        raise SystemExit(f'Manifest validation failed: missing {prefix}')

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

entries = {}
for line in lines:
    if ':' not in line:
        continue
    key, value = line.split(':', 1)
    if len(value) == 64 and all(c in '0123456789abcdef' for c in value.lower()):
        entries[key] = value.lower()

checks = {
    'project-src.tar.gz': bundle / 'project-src.tar.gz',
    'prebuilt.tar.gz': bundle / 'prebuilt.tar.gz',
}

# Metadata hashes point to the downloaded/built payloads.
metadata_checks = {
    'image_sha256': bundle / 'image.tar',
    'ubuntu_wsl_sha256': bundle / 'offline-deps' / 'ubuntu-24.04.4-wsl-amd64.wsl',
    'wsl_msi_sha256': bundle / 'offline-deps' / next(p.name for p in (bundle / 'offline-deps').glob('*.msi')),
    'docker_desktop_installer_sha256': bundle / 'offline-deps' / 'Docker Desktop Installer.exe',
}
for key, path in checks.items():
    if not path.exists():
        if key == 'prebuilt.tar.gz' and not (bundle / 'prebuilt.tar.gz').exists():
            continue
        raise SystemExit(f'Manifest validation failed: referenced file missing: {key}')
    expected = entries.get(key)
    if expected is None:
        raise SystemExit(f'Manifest validation failed: missing SHA256 entry: {key}')
    actual = sha256(path)
    if actual != expected:
        raise SystemExit(f'Manifest validation failed: SHA256 mismatch for {key}')

for key, path in metadata_checks.items():
    if not path.exists():
        raise SystemExit(f'Manifest validation failed: referenced payload missing: {key}')
    expected = entries.get(key)
    if expected is None:
        raise SystemExit(f'Manifest validation failed: missing metadata SHA256 entry: {key}')
    actual = sha256(path)
    if actual != expected:
        raise SystemExit(f'Manifest validation failed: SHA256 mismatch for {key}')

for volume in volumes:
    key = f'volumes/vol-{volume}.tar.gz'
    path = bundle / 'volumes' / f'vol-{volume}.tar.gz'
    if not path.exists():
        raise SystemExit(f'Manifest validation failed: volume archive missing: {key}')
    expected = entries.get(key)
    if expected is None:
        raise SystemExit(f'Manifest validation failed: missing volume SHA256 entry: {key}')
    actual = sha256(path)
    if actual != expected:
        raise SystemExit(f'Manifest validation failed: SHA256 mismatch for {key}')

print('  [ok] manifest.txt verified')
PY

echo "  [ok] All required package files are present."

echo ""
echo "========================================="
echo " Offline package created successfully"
echo "========================================="
echo "Location: $ABS_OUT"
echo ""
echo "The destination PC can now be completely offline."
echo "Run setup-offline.bat as Administrator."
