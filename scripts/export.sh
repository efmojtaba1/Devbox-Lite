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
#   - offline Docker Engine .deb packages for Ubuntu WSL
#   - Ubuntu Mono font packages for offline WSL use
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

# Ubuntu-side offline Docker Engine packages.
DOCKER_ENGINE_REPO="https://download.docker.com/linux/ubuntu"
DOCKER_ENGINE_GPG_URL="$DOCKER_ENGINE_REPO/gpg"
DOCKER_ENGINE_PACKAGES=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
  fonts-ubuntu
  fonts-ubuntu-console
)
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
# Offline Docker Engine + Ubuntu Mono packages for Ubuntu WSL
# ------------------------------------------------------------
echo ""
echo "[export] Preparing offline Docker Engine for Ubuntu WSL..."

command -v docker >/dev/null 2>&1 || {
    echo "[error] Docker is required on the export machine to build the exact Ubuntu 24.04 package environment."
    exit 1
}

DOCKER_ENGINE_DIR="$BUNDLE_DIR/docker-engine"
DOCKER_ENGINE_DEB_DIR="$DOCKER_ENGINE_DIR/debs"
DOCKER_ENGINE_META="$DOCKER_ENGINE_DIR/packages.txt"
DOCKER_ENGINE_WORK_DIR="$DOCKER_ENGINE_DIR/.resolver"
DOCKER_ENGINE_BASE_IMAGE="devbox-lite-ubuntu-24.04-resolver:latest"
mkdir -p "$DOCKER_ENGINE_DEB_DIR"
rm -rf "$DOCKER_ENGINE_WORK_DIR"
mkdir -p "$DOCKER_ENGINE_WORK_DIR"
find "$DOCKER_ENGINE_DEB_DIR" -maxdepth 1 -type f -name '*.deb' -delete

# IMPORTANT:
# Resolve Docker Engine dependencies inside the EXACT Ubuntu 24.04 WSL rootfs
# that will be installed on the destination. Resolving dependencies from the
# export host is unsafe because its installed libc/base-files versions can be
# newer than the destination WSL image.
if [ ! -s "$UBUNTU_WSL" ]; then
    echo "[error] Ubuntu 24.04 WSL package is missing before Docker dependency resolution."
    exit 1
fi

if ! tar -tf "$UBUNTU_WSL" >/dev/null 2>&1; then
    echo "[error] Ubuntu 24.04 WSL package is not a valid tar-compatible root filesystem."
    exit 1
fi

echo "  [info] Importing the exact Ubuntu 24.04 WSL rootfs for dependency resolution..."
docker rm -f devbox-lite-ubuntu-24.04-resolver >/dev/null 2>&1 || true
docker rmi -f "$DOCKER_ENGINE_BASE_IMAGE" >/dev/null 2>&1 || true

docker import "$UBUNTU_WSL" "$DOCKER_ENGINE_BASE_IMAGE" >/dev/null

# Export the package files through a bind-mounted directory. The resolver
# container is temporary and is removed after package collection.
cat > "$DOCKER_ENGINE_WORK_DIR/resolve.sh" <<'RESOLVER'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=C

OUT_DIR="/out"
REPO_URL="https://download.docker.com/linux/ubuntu"
KEY_FILE="/etc/apt/keyrings/devbox-lite-docker-engine.asc"
SOURCE_FILE="/etc/apt/sources.list.d/devbox-lite-docker-engine.sources"

printf '%s\n' '  [resolver] Updating Ubuntu 24.04 package metadata...'
apt-get update -qq
apt-get install -y --no-install-recommends ca-certificates curl gnupg >/dev/null

install -d -m 0755 /etc/apt/keyrings
curl -fsSL --retry 5 --retry-delay 2 "$REPO_URL/gpg" -o "$KEY_FILE"
chmod a+r "$KEY_FILE"

cat > "$SOURCE_FILE" <<EOF
Types: deb
URIs: $REPO_URL
Suites: noble
Components: stable
Architectures: amd64
Signed-By: $KEY_FILE
EOF

apt-get update -qq

ROOT_PACKAGES=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
  fonts-ubuntu
  fonts-ubuntu-console
)

printf '%s\n' '  [resolver] Calculating the complete Ubuntu 24.04 dependency set...'
apt-cache depends \
  --recurse \
  --no-recommends \
  --no-suggests \
  --no-conflicts \
  --no-breaks \
  --no-replaces \
  --no-enhances \
  "${ROOT_PACKAGES[@]}" 2>/dev/null |
awk '
  /^[[:space:]]+(Pre-)?Depends:/ {
    value=$0
    sub(/^[[:space:]]+(Pre-)?Depends:[[:space:]]*/, "", value)
    sub(/[[:space:]].*$/, "", value)
    gsub(/^</, "", value)
    gsub(/>$/, "", value)
    if (value != "") print value
  }
' |
awk 'NF && !seen[$0]++ { print }' > /tmp/devbox-engine-package-list.txt

{
  printf '%s\n' "${ROOT_PACKAGES[@]}"
  cat /tmp/devbox-engine-package-list.txt
} | awk 'NF && !seen[$0]++ { print }' > /tmp/devbox-engine-package-list-final.txt

mapfile -t PACKAGES < /tmp/devbox-engine-package-list-final.txt
if [ "${#PACKAGES[@]}" -eq 0 ]; then
  echo "[error] Could not resolve Docker Engine dependency closure inside Ubuntu 24.04."
  exit 1
fi

printf '  [resolver] Resolved %s packages.\n' "${#PACKAGES[@]}"

# Download every required .deb, including packages that are already installed
# in the base image. This makes the offline bundle self-contained.
apt-get -y --download-only \
  --no-install-recommends \
  -o Dir::Cache::archives="$OUT_DIR/" \
  -o APT::Keep-Downloaded-Packages=true \
  --reinstall \
  install "${PACKAGES[@]}"

find "$OUT_DIR" -maxdepth 1 -type f -name '*.deb' -printf '%f\n' | sort
RESOLVER
chmod +x "$DOCKER_ENGINE_WORK_DIR/resolve.sh"

echo "  [info] Downloading Docker Engine packages and all dependencies from the Ubuntu 24.04 environment..."
docker run --rm \
  --platform linux/amd64 \
  -v "$DOCKER_ENGINE_DEB_DIR:/out" \
  -v "$DOCKER_ENGINE_WORK_DIR/resolve.sh:/resolver.sh:ro" \
  --entrypoint /bin/bash \
  "$DOCKER_ENGINE_BASE_IMAGE" \
  /resolver.sh

# APT creates temporary cache artifacts in the output directory. They are not
# part of the offline package and must never be shipped in devbox-data.
rm -rf "$DOCKER_ENGINE_DEB_DIR/partial"
find "$DOCKER_ENGINE_DEB_DIR" -maxdepth 1 -type f \
    \( -name 'lock' -o -name 'lock.*' \) -delete

# Verify that the exact Docker Engine root packages exist in the generated bundle.
mapfile -t ENGINE_DEBS < <(find "$DOCKER_ENGINE_DEB_DIR" -maxdepth 1 -type f -name '*.deb' | sort)
if [ "${#ENGINE_DEBS[@]}" -eq 0 ]; then
    echo "[error] No Docker Engine .deb packages were downloaded."
    docker rmi -f "$DOCKER_ENGINE_BASE_IMAGE" >/dev/null 2>&1 || true
    rm -rf "$DOCKER_ENGINE_WORK_DIR"
    exit 1
fi

for required_pkg in "${DOCKER_ENGINE_PACKAGES[@]}"; do
    found_pkg="0"
    for deb in "${ENGINE_DEBS[@]}"; do
        if [ "$(dpkg-deb -f "$deb" Package 2>/dev/null || true)" = "$required_pkg" ]; then
            found_pkg="1"
            break
        fi
    done
    if [ "$found_pkg" != "1" ]; then
        echo "[error] Required Docker Engine package is missing from offline bundle: $required_pkg"
        docker rmi -f "$DOCKER_ENGINE_BASE_IMAGE" >/dev/null 2>&1 || true
        rm -rf "$DOCKER_ENGINE_WORK_DIR"
        exit 1
    fi
done

# Record the Ubuntu base package versions used by the dependency resolver.
# This provides an audit trail and makes accidental cross-release exports easy
# to identify.
RESOLVER_UBUNTU_VERSION="$({ docker run --rm --platform linux/amd64 "$DOCKER_ENGINE_BASE_IMAGE" bash -lc '. /etc/os-release; printf "%s|%s|%s\n" "$PRETTY_NAME" "$VERSION_ID" "$VERSION_CODENAME"'; } 2>/dev/null || true)"
RESOLVER_LIBC_VERSION="$({ docker run --rm --platform linux/amd64 "$DOCKER_ENGINE_BASE_IMAGE" dpkg-query -W -f='${Version}' libc6; } 2>/dev/null || true)"
RESOLVER_BASE_FILES_VERSION="$({ docker run --rm --platform linux/amd64 "$DOCKER_ENGINE_BASE_IMAGE" dpkg-query -W -f='${Version}' base-files; } 2>/dev/null || true)"

{
  echo "format_version:2"
  echo "architecture:amd64"
  echo "ubuntu_release:24.04"
  echo "resolver_base:$RESOLVER_UBUNTU_VERSION"
  echo "resolver_libc6:$RESOLVER_LIBC_VERSION"
  echo "resolver_base_files:$RESOLVER_BASE_FILES_VERSION"
  echo "docker_repo:$DOCKER_ENGINE_REPO"
  echo "packages:${#ENGINE_DEBS[@]}"
  echo ""
  for deb in "${ENGINE_DEBS[@]}"; do
    pkg_name="$(dpkg-deb -f "$deb" Package)"
    pkg_version="$(dpkg-deb -f "$deb" Version)"
    pkg_arch="$(dpkg-deb -f "$deb" Architecture)"
    pkg_sha="$(sha256sum "$deb" | awk '{print $1}')"
    echo "$pkg_name|$pkg_version|$pkg_arch|$(basename "$deb")|$pkg_sha"
  done
} > "$DOCKER_ENGINE_META"

# The imported WSL rootfs is used only as a dependency-resolution reference.
docker rmi -f "$DOCKER_ENGINE_BASE_IMAGE" >/dev/null 2>&1 || true
rm -rf "$DOCKER_ENGINE_WORK_DIR"

echo "  [ok] Docker Engine package bundle prepared from the exact Ubuntu 24.04 WSL rootfs"
echo "  [info] Packages: ${#ENGINE_DEBS[@]}"
echo "  [info] Resolver libc6: ${RESOLVER_LIBC_VERSION:-unknown}"
echo "  [info] Resolver base-files: ${RESOLVER_BASE_FILES_VERSION:-unknown}"

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
  --exclude='scripts/import.ps1' \
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

cat > "$BUNDLE_DIR/scripts/import.ps1" <<'PS1'
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
PS1

if [ ! -s "$BUNDLE_DIR/scripts/import.ps1" ]; then
  echo "[error] Refactored scripts/import.ps1 was not generated."
  exit 1
fi

if ! grep -q "docker.exe load -i" "$BUNDLE_DIR/scripts/import.ps1" ||
   ! grep -q "DOCKER_HOST=unix:///run/devbox-docker.sock" "$BUNDLE_DIR/scripts/import.ps1" ||
   ! grep -q "docker load -i" "$BUNDLE_DIR/scripts/import.ps1" ||
   ! grep -q "prebuilt" "$BUNDLE_DIR/scripts/import.ps1" ||
   ! grep -q "projects/DevBox-Lite" "$BUNDLE_DIR/scripts/import.ps1"; then
  echo "[error] Refactored import.ps1 dual-daemon restore validation failed."
  exit 1
fi

echo "  [ok] import.ps1 (dual Docker daemon restore)"

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
        @{ Path = (Join-Path $PackageRoot 'scripts\check-docker-restart-required.ps1'); Name = 'check-docker-restart-required.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\wait-docker-install.ps1'); Name = 'wait-docker-install.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\initialize-wsl-user.ps1'); Name = 'initialize-wsl-user.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\install-wsl-docker-engine.ps1'); Name = 'install-wsl-docker-engine.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\restore-wsl-project.ps1'); Name = 'restore-wsl-project.ps1' },
        @{ Path = (Join-Path $PackageRoot 'scripts\install-wsl-docker-engine.sh'); Name = 'install-wsl-docker-engine.sh' }
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

cat > "$BUNDLE_DIR/scripts/wait-docker-install.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [Parameter(Mandatory = $true)]
    [string]$LogPath,
    [int]$TimeoutSeconds = 900,
    [int]$PollSeconds = 2
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
        throw "Docker Desktop installer not found: $InstallerPath"
    }

    $logDir = Split-Path -Parent $LogPath
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    }

    if (Test-Path -LiteralPath $LogPath) {
        Remove-Item -LiteralPath $LogPath -Force -ErrorAction SilentlyContinue
    }

    Write-Host '  Starting Docker Desktop installer...'
    $process = Start-Process -FilePath $InstallerPath `
        -ArgumentList @('install','--accept-license','--backend=wsl-2','--no-windows-containers') `
        -PassThru

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    Write-Host '  Waiting for Docker Desktop installation to complete...'

    do {
        if (Test-Path -LiteralPath $LogPath -PathType Leaf) {
            $tail = Get-Content -LiteralPath $LogPath -Tail 100 -ErrorAction SilentlyContinue

            if ($tail -match 'Installation succeeded') {
                Write-Host '  [OK] Docker Desktop installation completed.'

                if ($process -and -not $process.HasExited) {
                    Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
                }

                exit 0
            }

            if ($tail -match '(?i)Installation failed|fatal error') {
                Write-Host '  [ERROR] Docker Desktop installer reported a failure.'
                exit 1
            }
        }

        if ($process.HasExited -and -not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
            Start-Sleep -Seconds 2
        }

        Start-Sleep -Seconds $PollSeconds
    } while ((Get-Date) -lt $deadline)

    Write-Host "  [ERROR] Docker Desktop installation did not complete within $TimeoutSeconds seconds."
    Write-Host "          Installer log: $LogPath"

    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    exit 1
}
catch {
    Write-Host "[ERROR] Failed while installing Docker Desktop: $($_.Exception.Message)"
    exit 1
}
PS1
echo "  [ok] wait-docker-install.ps1"

cat > "$BUNDLE_DIR/scripts/initialize-wsl-user.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Distribution = 'Ubuntu-24.04'
)

$ErrorActionPreference = 'Stop'

function Get-NormalWslUser {
    param([string]$Distro)

    $result = & wsl.exe -d $Distro -u root -- getent passwd 2>$null
    if ($LASTEXITCODE -ne 0) { return '' }

    foreach ($line in @($result)) {
        $text = $line.ToString().Trim()
        if (-not $text) { continue }

        $fields = $text.Split(':')
        if ($fields.Count -lt 7) { continue }

        $uid = 0
        if (-not [int]::TryParse($fields[2], [ref]$uid)) { continue }
        if ($uid -lt 1000 -or $uid -ge 60000) { continue }

        $shell = $fields[6].Trim().ToLowerInvariant()
        if ($shell -match '/(nologin|false)$') { continue }

        return $fields[0].Trim()
    }

    return ''
}

function Convert-SecureStringToPlainText {
    param([Security.SecureString]$SecureString)

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

try {
    $existingUser = Get-NormalWslUser -Distro $Distribution
    if ($existingUser) {
        Write-Host "  [OK] Ubuntu user is already initialized: $existingUser"
        exit 0
    }

    Write-Host ''
    Write-Host '  Ubuntu-24.04 requires first-run account setup.'
    Write-Host '  The account will be created in this installer window.'
    Write-Host '  Enter the Linux username and password below.'
    Write-Host '  You do not need to open Ubuntu or type exit.'
    Write-Host '  The installer will continue automatically after setup.'
    Write-Host '  The password is used only by Ubuntu and is never stored by DevBox Lite.'
    Write-Host ''

    do {
        $username = (Read-Host '  Linux username').Trim()
        if ($username -notmatch '^[a-z_][a-z0-9_-]*[$]?$') {
            Write-Host '  [ERROR] Invalid username. Use lowercase letters, numbers, _ or -.'
            $username = ''
        }
    } while (-not $username)

    $passwordSecure = Read-Host '  Linux password' -AsSecureString
    $password = Convert-SecureStringToPlainText -SecureString $passwordSecure
    $passwordSecure = $null

    if ([string]::IsNullOrEmpty($password)) {
        throw 'A non-empty Linux password is required.'
    }

    $setupScript = @'
set -euo pipefail
TARGET_USER="$(printf '%s' "$1" | base64 -d)"
PASSWORD_B64="$(cat)"
PASSWORD="$(printf '%s' "$PASSWORD_B64" | base64 -d)"
unset PASSWORD_B64

if id "$TARGET_USER" >/dev/null 2>&1; then
    echo "  [wsl] Existing Linux user detected: $TARGET_USER"
else
    useradd --create-home --shell /bin/bash "$TARGET_USER"
    usermod -aG sudo "$TARGET_USER"
fi

printf '%s:%s\n' "$TARGET_USER" "$PASSWORD" | chpasswd
unset PASSWORD

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "$TARGET_HOME" ]; then
    echo "[error] Could not determine Linux home directory."
    exit 10
fi

cat > /etc/wsl.conf <<EOF
[boot]
systemd=true

[user]
default=$TARGET_USER
EOF

chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME"

echo "  [wsl] Linux user created: $TARGET_USER"
echo "  [wsl] Default WSL user configured: $TARGET_USER"
echo "  [wsl] systemd enabled."
'@

    $scriptB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($setupScript))
    $usernameB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($username))
    $passwordB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($password))
    $password = $null

    # Run WSL directly from this installer window. No separate Ubuntu window is opened.
    $command = "echo '$scriptB64' | base64 -d | bash -s -- '$usernameB64'"
    $passwordB64 | & wsl.exe -d $Distribution -u root -- bash -lc $command
    $rc = $LASTEXITCODE
    $passwordB64 = $null

    if ($rc -ne 0) {
        $hexRc = ('0x{0:X8}' -f ([uint32]$rc))
        throw "Ubuntu first-run account setup failed with code $rc ($hexRc)."
    }

    Write-Host '  [INFO] Waiting for Ubuntu user database synchronization...'
    $existingUser = ''
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        Start-Sleep -Seconds 2
        $existingUser = Get-NormalWslUser -Distro $Distribution
        if ($existingUser) {
            break
        }
        Write-Host "  [INFO] Checking Ubuntu user... attempt $attempt/10"
    }

    if (-not $existingUser) {
        Write-Host '  [DEBUG] Current Ubuntu passwd entries:'
        & wsl.exe -d $Distribution -u root -- cat /etc/passwd 2>$null | Write-Host
        throw 'Ubuntu account setup completed, but no normal Linux user account was detected after retry.'
    }

    if ($existingUser -ne $username) {
        throw "Ubuntu account setup created '$existingUser' instead of '$username'."
    }

    Write-Host "  [OK] Ubuntu user initialized: $existingUser"
    Write-Host '  [OK] Installer will continue automatically.'
    exit 0
}
catch {
    $password = $null
    $passwordSecure = $null
    $passwordB64 = $null
    Write-Host "[ERROR] Ubuntu first-run user initialization failed: $($_.Exception.Message)"
    exit 1
}
PS1
echo "  [ok] initialize-wsl-user.ps1"

cat > "$BUNDLE_DIR/scripts/restore-wsl-project.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$Distribution = 'Ubuntu-24.04'
)

$ErrorActionPreference = 'Stop'

try {
    $projectTarWin = Join-Path $PackageRoot 'project-src.tar.gz'
    if (-not (Test-Path -LiteralPath $projectTarWin -PathType Leaf)) {
        throw "Project source archive not found: $projectTarWin"
    }

    # Do not pass a raw Windows path through wsl.exe command-line parsing.
    # Backslashes can be consumed before wslpath receives the value.
    # Encode the Windows path in PowerShell and decode it inside WSL first.
    $projectTarWinB64 = [Convert]::ToBase64String(
        [Text.Encoding]::UTF8.GetBytes($projectTarWin)
    )

    $restoreScript = @'
set -euo pipefail
archive_win_b64="$1"
distro="$2"

archive_win="$(printf '%s' "$archive_win_b64" | base64 -d)"
archive="$(wslpath -u "$archive_win")"

if [ -z "${archive:-}" ] || [ ! -f "$archive" ]; then
  echo "[error] Could not resolve project source archive inside WSL."
  echo "        Windows path: $archive_win"
  exit 10
fi

TARGET_USER=""
if [ -f /etc/wsl.conf ]; then
  TARGET_USER="$(awk '
    BEGIN { section="" }
    /^\[user\][[:space:]]*$/ { section="user"; next }
    /^\[/ { section="" }
    section == "user" && $0 ~ /^[[:space:]]*default[[:space:]]*=/ { sub(/^[[:space:]]*default[[:space:]]*=[[:space:]]*/, ""); gsub(/[[:space:]]/, ""); print; exit }
  ' /etc/wsl.conf)"
fi

if [ -n "${TARGET_USER:-}" ]; then
  getent passwd "$TARGET_USER" >/dev/null 2>&1 || TARGET_USER=""
fi

if [ -z "${TARGET_USER:-}" ]; then
  TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')"
fi

if [ -z "${TARGET_USER:-}" ]; then
  echo "[error] No normal Ubuntu user account was found (UID 1000+)."
  echo "        Launch Ubuntu once to create the user, then run setup-offline again."
  exit 2
fi

TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
if [ -z "${TARGET_HOME:-}" ] || [ ! -d "$TARGET_HOME" ]; then
  echo "[error] Could not resolve home directory for WSL user: $TARGET_USER"
  exit 3
fi

TARGET_DIR="$TARGET_HOME/projects/DevBox-Lite"
mkdir -p "$TARGET_HOME/projects"
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

tar -xzf "$archive" -C "$TARGET_DIR"
chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_DIR"

printf '  [ok] WSL project source restored: %s\n' "$TARGET_DIR"
printf '  [info] WSL user: %s\n' "$TARGET_USER"
printf '  [info] Windows UNC: \\\\wsl.localhost\\%s%s\n' "$distro" "${TARGET_DIR//\//\\}"
'@

    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($restoreScript))
    $command = "echo '$encoded' | base64 -d | bash -s -- '$projectTarWinB64' '$Distribution'"

    Write-Host '  [wsl] Restoring project source inside Ubuntu-24.04...'
    & wsl.exe -d $Distribution -u root -- bash -lc $command
    if ($LASTEXITCODE -ne 0) {
        throw "WSL project restore exited with code $LASTEXITCODE."
    }

    Write-Host '  [OK] Project source restored inside the WSL home directory.'
    exit 0
}
catch {
    Write-Host "[ERROR] Failed to restore project source inside WSL: $($_.Exception.Message)"
    exit 1
}
PS1
echo "  [ok] restore-wsl-project.ps1"

cat > "$BUNDLE_DIR/scripts/install-wsl-docker-engine.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

DEB_DIR="${1:-}"

if [ -z "$DEB_DIR" ] || [ ! -d "$DEB_DIR" ]; then
  echo "[error] Docker Engine package directory not found: $DEB_DIR"
  exit 1
fi

if ! compgen -G "$DEB_DIR/*.deb" >/dev/null; then
  echo "[error] No offline Docker Engine .deb packages found in: $DEB_DIR"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "  [wsl-engine] Installing offline Docker Engine and Ubuntu Mono packages..."

if ! apt-get install -y --no-download --no-install-recommends "$DEB_DIR"/*.deb >/tmp/devbox-docker-engine-apt.log 2>&1; then
  echo "  [wsl-engine] apt local install did not complete cleanly; retrying with dpkg..."
  dpkg -i "$DEB_DIR"/*.deb >/tmp/devbox-docker-engine-dpkg.log 2>&1 || true
  dpkg --configure -a >/tmp/devbox-docker-engine-configure.log 2>&1 || {
    echo "[error] Offline Docker Engine package configuration failed."
    cat /tmp/devbox-docker-engine-apt.log 2>/dev/null || true
    cat /tmp/devbox-docker-engine-dpkg.log 2>/dev/null || true
    cat /tmp/devbox-docker-engine-configure.log 2>/dev/null || true
    exit 1
  }
fi

# A normal user must already exist because Ubuntu first-run is handled before this stage.
TARGET_USER="$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')"
if [ -z "${TARGET_USER:-}" ]; then
  echo "[error] No normal Ubuntu user exists. Complete Ubuntu first-run before installing Docker Engine."
  exit 2
fi

# WSL supports systemd, but it must be explicitly enabled in the distro config.
WSL_CONF=/etc/wsl.conf
if [ ! -f "$WSL_CONF" ]; then
  printf '%s\n' '[boot]' 'systemd=true' > "$WSL_CONF"
elif ! grep -qE '^systemd[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$WSL_CONF"; then
  if grep -qE '^\[boot\][[:space:]]*$' "$WSL_CONF"; then
    awk '
      BEGIN { done=0 }
      /^\[boot\][[:space:]]*$/ { print; if (!done) { print "systemd=true"; done=1 } ; next }
      { print }
      END { if (!done) print "systemd=true" }
    ' "$WSL_CONF" > "${WSL_CONF}.tmp"
    mv -f "${WSL_CONF}.tmp" "$WSL_CONF"
  else
    printf '%s\n' '' '[boot]' 'systemd=true' >> "$WSL_CONF"
  fi
fi

# Make the Ubuntu first-run account the default WSL user.
if ! grep -qE '^\[user\][[:space:]]*$' "$WSL_CONF"; then
  printf '%s\n' '' '[user]' >> "$WSL_CONF"
fi
if grep -qE '^[[:space:]]*default[[:space:]]*=' "$WSL_CONF"; then
  sed -i -E "s/^[[:space:]]*default[[:space:]]*=.*$/default=$TARGET_USER/" "$WSL_CONF"
else
  printf '%s\n' "default=$TARGET_USER" >> "$WSL_CONF"
fi

# The Docker Desktop WSL integration may own /var/run/docker.sock.
# Use a dedicated local Engine socket so both daemons can coexist safely.
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/10-devbox-wsl-engine.conf <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock --host=unix:///run/devbox-docker.sock
EOF

# If systemd is not active yet, the Windows-side helper will restart only
# the Ubuntu distro (not Windows) and run this script again.
if [ ! -d /run/systemd/system ]; then
  echo "  [wsl-engine] systemd has been enabled; restarting Ubuntu-24.04 is required."
  exit 10
fi

systemctl daemon-reload
systemctl enable docker >/dev/null
systemctl restart containerd >/dev/null 2>&1 || true
systemctl restart docker >/dev/null 2>&1 || systemctl start docker

# Configure a dedicated Docker context for the local WSL daemon.
if [ -n "${TARGET_USER:-}" ]; then
  usermod -aG docker "$TARGET_USER" || true
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
  if [ -n "$TARGET_HOME" ]; then
    install -d -m 0755 "$TARGET_HOME/.docker"
    chown "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.docker"
    runuser -u "$TARGET_USER" -- docker context inspect wsl-engine >/dev/null 2>&1 || \
      runuser -u "$TARGET_USER" -- docker context create wsl-engine --docker "host=unix:///run/devbox-docker.sock" >/dev/null
    runuser -u "$TARGET_USER" -- docker context update wsl-engine --docker "host=unix:///run/devbox-docker.sock" >/dev/null 2>&1 || true
    runuser -u "$TARGET_USER" -- docker context use wsl-engine >/dev/null
    chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.docker"
  fi
fi

# Root verification keeps the installer independent of the user's login shell.
DOCKER_HOST=unix:///run/devbox-docker.sock docker version >/dev/null
DOCKER_HOST=unix:///run/devbox-docker.sock docker compose version >/dev/null

fc-cache -f >/dev/null 2>&1 || true

echo "  [wsl-engine] Docker Engine is ready on unix:///run/devbox-docker.sock"
echo "  [wsl-engine] Docker Compose plugin is available."
echo "  [wsl-engine] Ubuntu Mono fonts are installed."
exit 0
SH
chmod +x "$BUNDLE_DIR/scripts/install-wsl-docker-engine.sh"
echo "  [ok] install-wsl-docker-engine.sh"

cat > "$BUNDLE_DIR/scripts/install-wsl-docker-engine.ps1" <<'PS1'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackageRoot,
    [string]$Distribution = 'Ubuntu-24.04'
)

$ErrorActionPreference = 'Stop'

try {
    $scriptWin = Join-Path $PackageRoot 'scripts\install-wsl-docker-engine.sh'
    $debWin = Join-Path $PackageRoot 'docker-engine\debs'

    if (-not (Test-Path -LiteralPath $scriptWin -PathType Leaf)) { throw "WSL Docker Engine installer not found: $scriptWin" }
    if (-not (Test-Path -LiteralPath $debWin -PathType Container)) { throw "Docker Engine package directory not found: $debWin" }

    # Do not pass raw Windows paths through wsl.exe command-line parsing.
    # Backslashes can be stripped before wslpath sees them (for example
    # C:\Users\Vahid\... becoming C:UsersVahid...). Encode the paths first
    # and decode them inside WSL, then run wslpath there.
    $scriptWinB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($scriptWin))
    $debWinB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($debWin))

    $pathBridge = @'
set -euo pipefail
script_win="$(printf '%s' "$1" | base64 -d)"
deb_win="$(printf '%s' "$2" | base64 -d)"
script_wsl="$(wslpath -u "$script_win")"
deb_wsl="$(wslpath -u "$deb_win")"
if [ -z "${script_wsl:-}" ] || [ ! -f "$script_wsl" ]; then
  echo "[error] Could not resolve Docker Engine installer path inside WSL: $script_win"
  exit 11
fi
if [ -z "${deb_wsl:-}" ] || [ ! -d "$deb_wsl" ]; then
  echo "[error] Could not resolve Docker Engine package directory inside WSL: $deb_win"
  exit 12
fi
bash "$script_wsl" "$deb_wsl"
'@

    function Invoke-EngineInstall {
        param([string]$ScriptB64, [string]$DebB64)
        $bridgeB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pathBridge))
        $command = "echo '$bridgeB64' | base64 -d | bash -s -- '$ScriptB64' '$DebB64'"
        # Send WSL stdout directly to the console. Do not let it enter the
        # PowerShell success stream, otherwise function output becomes an
        # array and $rc is no longer a scalar exit code.
        & wsl.exe -d $Distribution -u root -- bash -lc $command | Out-Host
        $exitCode = [int]$LASTEXITCODE
        return $exitCode
    }

    Write-Host '  [wsl-engine] Installing Docker Engine inside Ubuntu-24.04...'
    $rc = Invoke-EngineInstall -ScriptB64 $scriptWinB64 -DebB64 $debWinB64

    if ($rc -eq 10) {
        Write-Host '  [wsl-engine] Restarting Ubuntu-24.04 to activate systemd...'
        & wsl.exe --terminate $Distribution
        if ($LASTEXITCODE -ne 0) { throw 'Could not terminate Ubuntu-24.04 for systemd activation.' }

        Start-Sleep -Seconds 2
        & wsl.exe -d $Distribution -u root -- true
        if ($LASTEXITCODE -ne 0) { throw 'Could not restart Ubuntu-24.04 after enabling systemd.' }

        $rc = Invoke-EngineInstall -ScriptB64 $scriptWinB64 -DebB64 $debWinB64
    }

    if ($rc -ne 0) { throw "WSL Docker Engine installer exited with code $rc." }

    Write-Host '  [OK] Docker Engine is installed inside Ubuntu-24.04.'
    Write-Host '  [OK] Ubuntu Mono fonts are installed.'
    Write-Host '  [OK] Local WSL Docker context: wsl-engine'
    exit 0
}
catch {
    Write-Host "[ERROR] Failed to install Docker Engine inside WSL: $($_.Exception.Message)"
    exit 1
}
PS1
echo "  [ok] install-wsl-docker-engine.ps1"

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
if /I "%STAGE%"=="UBUNTU_INSTALLED" goto :stage_wsl_user
if /I "%STAGE%"=="UBUNTU_USER_INITIALIZED" goto :stage_wsl_project
if /I "%STAGE%"=="WSL_PROJECT_INSTALLED" goto :stage_wsl_engine
if /I "%STAGE%"=="WSL_ENGINE_INSTALLED" goto :stage_docker
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

goto :stage_wsl_user

:stage_wsl_user
set "STAGE=INITIALIZE_UBUNTU_USER"
call :initialize_wsl_user
if errorlevel 1 goto :fail
call :save_stage UBUNTU_USER_INITIALIZED
if errorlevel 1 goto :fail
goto :stage_wsl_project

:stage_wsl_project
set "STAGE=RESTORE_WSL_PROJECT"
call :restore_wsl_project
if errorlevel 1 goto :fail
call :save_stage WSL_PROJECT_INSTALLED
if errorlevel 1 goto :fail
goto :stage_wsl_engine

:stage_wsl_engine
set "STAGE=INSTALL_WSL_ENGINE"
call :install_wsl_engine
if errorlevel 1 goto :fail
call :save_stage WSL_ENGINE_INSTALLED
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
echo [1/9] Validating Windows and offline package...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\validate-offline.ps1" -PackageRoot "%PACKAGE_ROOT%"
if errorlevel 1 exit /b 1
exit /b 0

:enable_wsl_features
echo.
echo [2/9] Checking Windows WSL2 components...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\manage-wsl-features.ps1"
exit /b %errorlevel%

:install_wsl
echo.
echo [3/9] Installing WSL from the offline MSI...

where wsl.exe >nul 2>&1
if errorlevel 1 goto :wsl_command_missing

set "WSL_INSTALLED_NOW=0"

wsl.exe --version >nul 2>&1
if errorlevel 1 goto :wsl_install_msi

wsl.exe --status >nul 2>&1
if errorlevel 1 goto :wsl_install_msi

wsl.exe --list --quiet >nul 2>&1
if errorlevel 1 goto :wsl_install_msi

goto :wsl_ready

:wsl_install_msi
echo   Installing WSL MSI...
msiexec.exe /i "%WSL_MSI%" /passive /norestart
set "WSL_MSI_RC=%errorlevel%"
if "%WSL_MSI_RC%"=="3010" exit /b 3010
if not "%WSL_MSI_RC%"=="0" goto :wsl_install_error
set "WSL_INSTALLED_NOW=1"

:wsl_ready
wsl.exe --set-default-version 2 >nul 2>&1
if errorlevel 1 goto :wsl_default_error

rem Only check for a pending Windows restart after a fresh WSL MSI installation.
if not "%WSL_INSTALLED_NOW%"=="1" goto :wsl_restart_check_done

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-restart-required.ps1"
set "WSL_RESTART_RC=%errorlevel%"
if "%WSL_RESTART_RC%"=="3010" exit /b 3010
if not "%WSL_RESTART_RC%"=="0" goto :wsl_install_error

:wsl_restart_check_done
echo   [OK] WSL2 is installed and default version is 2.
exit /b 0

:ensure_wsl_ready
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-wsl-ready.ps1" -TimeoutSeconds 90 -PollSeconds 3
exit /b %errorlevel%

:install_ubuntu
echo.
echo [4/9] Installing Ubuntu 24.04 offline...
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

:initialize_wsl_user
echo.
echo [5/9] Initializing Ubuntu-24.04 first-run user...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\initialize-wsl-user.ps1" -Distribution "Ubuntu-24.04"
if errorlevel 1 goto :wsl_user_init_error
exit /b 0

:restore_wsl_project
echo.
echo [6/9] Copying DevBox source into Ubuntu-24.04 WSL...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\restore-wsl-project.ps1" -PackageRoot "%PACKAGE_ROOT%" -Distribution "Ubuntu-24.04"
if errorlevel 1 goto :wsl_project_restore_error
exit /b 0

:install_wsl_engine
echo.
echo [7/9] Installing Docker Engine inside Ubuntu-24.04...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\install-wsl-docker-engine.ps1" -PackageRoot "%PACKAGE_ROOT%" -Distribution "Ubuntu-24.04"
if errorlevel 1 goto :wsl_engine_install_error
exit /b 0

:install_docker
echo.
echo [8/9] Installing Docker Desktop offline...
set "DOCKER_EXE=%PACKAGE_ROOT%\offline-deps\Docker Desktop Installer.exe"
set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"
set "DOCKER_RESTART_STATE=%STATE_DIR%\docker-hyperv.state"
set "DOCKER_INSTALL_LOG=%ProgramData%\DockerDesktop\install-log-admin.txt"

if exist "%DOCKER_DESKTOP_EXE%" goto :docker_start

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-docker-restart-required.ps1" -Mode Begin -StatePath "%DOCKER_RESTART_STATE%"
if errorlevel 1 goto :docker_install_error

call :wait_for_docker_install
set "DOCKER_WAIT_RC=%errorlevel%"
if not "%DOCKER_WAIT_RC%"=="0" goto :docker_install_error

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\check-docker-restart-required.ps1" -Mode Check -StatePath "%DOCKER_RESTART_STATE%"
set "DOCKER_RESTART_RC=%errorlevel%"
if "%DOCKER_RESTART_RC%"=="3010" exit /b 3010
if not "%DOCKER_RESTART_RC%"=="0" goto :docker_install_error

:wait_for_docker_install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%\scripts\wait-docker-install.ps1" -InstallerPath "%DOCKER_EXE%" -LogPath "%DOCKER_INSTALL_LOG%" -TimeoutSeconds 900 -PollSeconds 2
exit /b %errorlevel%

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
echo [9/9] Restoring DevBox Lite to:
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

wsl.exe -d Ubuntu-24.04 -u root -- bash -lc "DOCKER_HOST=unix:///run/devbox-docker.sock docker version >/dev/null 2>&1 && DOCKER_HOST=unix:///run/devbox-docker.sock docker compose version >/dev/null 2>&1"
if errorlevel 1 goto :verify_wsl_engine_missing

wsl.exe -d Ubuntu-24.04 -u root -- bash -lc "TARGET_USER=; if [ -f /etc/wsl.conf ]; then TARGET_USER=\"$(awk 'BEGIN { section=\"\" } /^\[user\][[:space:]]*$/ { section=\"user\"; next } /^\[/ { section=\"\" } section == \"user\" && $0 ~ /^[[:space:]]*default[[:space:]]*=/ { sub(/^[[:space:]]*default[[:space:]]*=[[:space:]]*/, \"\"); gsub(/[[:space:]]/, \"\"); print; exit }' /etc/wsl.conf)\"; fi; if [ -z \"$TARGET_USER\" ]; then TARGET_USER=\"$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1; exit}')\"; fi; TARGET_HOME=\"$(getent passwd \"$TARGET_USER\" | cut -d: -f6)\"; test -f \"$TARGET_HOME/projects/DevBox-Lite/docker/compose/docker-compose.yml\""
if errorlevel 1 goto :verify_wsl_project_missing

docker version >nul 2>&1
if errorlevel 1 goto :verify_docker_missing

if not exist "%DEST_PATH%\docker\compose\docker-compose.yml" goto :verify_project_missing

echo   [OK] WSL2
echo   [OK] Ubuntu 24.04
echo   [OK] Docker Engine inside WSL (wsl-engine)
echo   [OK] Docker Desktop / Docker Engine
echo   [OK] DevBox project files
exit /b 0

:schedule_restart
set "RESUME_WRAPPER=%STATE_DIR%\resume-offline-setup.cmd"
set "RESUME_LOCK=%STATE_DIR%\resume-offline-setup.lock"
set "SETUP_FULL_PATH=%~f0"
set "TASK_START=DevBoxLite-OfflineSetup-Startup"
set "TASK_LOGON=DevBoxLite-OfflineSetup-Logon"
set "RESUME_LOG=%STATE_DIR%\resume.log"

echo.
echo   Windows restart is required before installation can continue.
echo   The installer will resume automatically after Windows starts or the user logs on.
echo.

rem The wrapper is self-contained and records diagnostics for automatic resume.
>"%RESUME_WRAPPER%" echo @echo off
>>"%RESUME_WRAPPER%" echo setlocal EnableExtensions DisableDelayedExpansion
>>"%RESUME_WRAPPER%" echo set "STATE_FILE=%STATE_FILE%"
>>"%RESUME_WRAPPER%" echo set "RESUME_LOCK=%RESUME_LOCK%"
>>"%RESUME_WRAPPER%" echo set "RESUME_LOG=%RESUME_LOG%"
>>"%RESUME_WRAPPER%" echo if not exist "%%STATE_FILE%%" exit /b 0
>>"%RESUME_WRAPPER%" echo if exist "%%RESUME_LOCK%%" exit /b 0
>>"%RESUME_WRAPPER%" echo mkdir "%%RESUME_LOCK%%" ^>nul 2^>^&1
>>"%RESUME_WRAPPER%" echo if errorlevel 1 exit /b 0
>>"%RESUME_WRAPPER%" echo ^>^>"%%RESUME_LOG%%" echo [%%date%% %%time%%] Resume trigger started.
>>"%RESUME_WRAPPER%" echo set "RESUME_RC=1"
>>"%RESUME_WRAPPER%" echo for /l %%%%N in ^(1,1,5^) do ^(
>>"%RESUME_WRAPPER%" echo   ^>^>"%%RESUME_LOG%%" echo [%%date%% %%time%%] Resume attempt %%%%N of 5.
>>"%RESUME_WRAPPER%" echo   call "%SETUP_FULL_PATH%" /resume ^>^>"%%RESUME_LOG%%" 2^>^&1
>>"%RESUME_WRAPPER%" echo   set "RESUME_RC=%%%%errorlevel%%%%"
>>"%RESUME_WRAPPER%" echo   if "%%%%RESUME_RC%%%%"=="0" goto :resume_done
>>"%RESUME_WRAPPER%" echo   if %%%%N LSS 5 timeout /t 30 /nobreak ^>nul
>>"%RESUME_WRAPPER%" echo ^)
>>"%RESUME_WRAPPER%" echo :resume_done
>>"%RESUME_WRAPPER%" echo ^>^>"%%RESUME_LOG%%" echo [%%date%% %%time%%] Resume exited with code %%RESUME_RC%%.
>>"%RESUME_WRAPPER%" echo rmdir "%%RESUME_LOCK%%" ^>nul 2^>^&1
>>"%RESUME_WRAPPER%" echo endlocal ^& exit /b %%RESUME_RC%%

if not exist "%RESUME_WRAPPER%" goto :resume_task_error
if not exist "%STATE_FILE%" goto :resume_task_error

rem Remove stale tasks before recreating them.
schtasks /delete /tn "%TASK_START%" /f >nul 2>&1
schtasks /delete /tn "%TASK_LOGON%" /f >nul 2>&1

rem Startup trigger handles reboot continuation even before interactive logon.
schtasks /create /tn "%TASK_START%" /sc onstart /delay 0001:00 /ru SYSTEM /rl HIGHEST /tr "%ComSpec% /d /c ""%RESUME_WRAPPER%""" /f >"%STATE_DIR%\resume-task-startup-create.txt" 2>&1
if errorlevel 1 goto :resume_task_error

rem Logon trigger is a second safety net when startup runs before services are ready.
schtasks /create /tn "%TASK_LOGON%" /sc onlogon /delay 0000:30 /ru SYSTEM /rl HIGHEST /tr "%ComSpec% /d /c ""%RESUME_WRAPPER%""" /f >"%STATE_DIR%\resume-task-logon-create.txt" 2>&1
if errorlevel 1 goto :resume_task_error

schtasks /query /tn "%TASK_START%" /fo LIST /v >"%STATE_DIR%\resume-task-startup.txt" 2>&1
if errorlevel 1 goto :resume_task_error
schtasks /query /tn "%TASK_LOGON%" /fo LIST /v >"%STATE_DIR%\resume-task-logon.txt" 2>&1
if errorlevel 1 goto :resume_task_error

findstr /I /C:"TaskName:" "%STATE_DIR%\resume-task-startup.txt" >nul 2>&1
if errorlevel 1 goto :resume_task_error
findstr /I /C:"TaskName:" "%STATE_DIR%\resume-task-logon.txt" >nul 2>&1
if errorlevel 1 goto :resume_task_error

set "TASK_REGISTERED=1"
echo   [OK] Automatic resume tasks created and verified.
echo   [INFO] Startup task : %TASK_START%
echo   [INFO] Logon task   : %TASK_LOGON%
echo   [INFO] Resume log   : %RESUME_LOG%
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
schtasks /delete /tn "DevBoxLite-OfflineSetup-Startup" /f >nul 2>&1
schtasks /delete /tn "DevBoxLite-OfflineSetup-Logon" /f >nul 2>&1
if exist "%STATE_FILE%" del /f /q "%STATE_FILE%" >nul 2>&1
if exist "%STATE_DIR%\resume-offline-setup.cmd" del /f /q "%STATE_DIR%\resume-offline-setup.cmd" >nul 2>&1
if exist "%STATE_DIR%\resume-offline-setup.lock" rmdir /s /q "%STATE_DIR%\resume-offline-setup.lock" >nul 2>&1
if exist "%STATE_DIR%\resume-task-startup.txt" del /f /q "%STATE_DIR%\resume-task-startup.txt" >nul 2>&1
if exist "%STATE_DIR%\resume-task-logon.txt" del /f /q "%STATE_DIR%\resume-task-logon.txt" >nul 2>&1
if exist "%STATE_DIR%\resume-task-startup-create.txt" del /f /q "%STATE_DIR%\resume-task-startup-create.txt" >nul 2>&1
if exist "%STATE_DIR%\resume-task-logon-create.txt" del /f /q "%STATE_DIR%\resume-task-logon-create.txt" >nul 2>&1
if exist "%STATE_DIR%\resume.log" del /f /q "%STATE_DIR%\resume.log" >nul 2>&1
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

:wsl_user_init_error
echo [ERROR] Ubuntu first-run user initialization failed.
echo         Launch Ubuntu-24.04, create the Linux user, and run setup-offline.bat again.
exit /b 1

:wsl_project_restore_error
echo [ERROR] Failed to restore project source inside Ubuntu-24.04 WSL.
exit /b 1

:wsl_engine_install_error
echo [ERROR] Docker Engine installation inside Ubuntu-24.04 failed.
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

:verify_wsl_engine_missing
echo [ERROR] Docker Engine inside Ubuntu-24.04 is not available on wsl-engine.
exit /b 1

:verify_wsl_project_missing
echo [ERROR] DevBox source was not restored inside Ubuntu-24.04 WSL.
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
if /I "%RESUME_MODE%"=="1" exit /b %FAIL_CODE%
pause
exit /b %FAIL_CODE%
BAT

# ------------------------------------------------------------
# Normalize generated Windows batch file to CRLF line endings.
# cmd.exe can fail to resolve CALL/GOTO labels in LF-only batch
# files, especially when labels are used across subroutines.
# The generated installer is consumed by Windows, so enforce CRLF.
# ------------------------------------------------------------
python3 - "$ABS_OUT/setup-offline.bat" <<'PY_EOL'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()

# Normalize all existing line endings, then write canonical Windows CRLF.
data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
path.write_bytes(data.replace(b"\n", b"\r\n"))

# Verify there are no lone LF line endings.
check = path.read_bytes()
if check.replace(b"\r\n", b"").find(b"\n") != -1:
    raise SystemExit(
        "Generated BAT line-ending validation failed: lone LF line ending detected."
    )

print("  [ok] setup-offline.bat normalized to Windows CRLF line endings")
PY_EOL

# Validate the offline Docker Engine dependency collector itself.
if ! grep -q 'apt-cache depends' "$0" ||
   ! grep -q 'RESOLVED_ENGINE_PACKAGES' "$0" ||
   ! grep -q -- '--reinstall' "$0" ||
   ! grep -q 'Pre-.*Depends' "$0"; then
  echo "[error] Export validation failed: complete Docker dependency collection is missing."
  exit 1
fi

echo "  [ok] Docker Engine dependency collector validation passed"

# Validate generated files before package creation continues.
python3 - "$ABS_OUT/setup-offline.bat" "$BUNDLE_DIR/scripts/validate-offline.ps1" "$BUNDLE_DIR/scripts/manage-wsl-features.ps1" "$BUNDLE_DIR/scripts/check-wsl-distro.ps1" "$BUNDLE_DIR/scripts/check-wsl-ready.ps1" "$BUNDLE_DIR/scripts/check-restart-required.ps1" "$BUNDLE_DIR/scripts/check-docker-restart-required.ps1" "$BUNDLE_DIR/scripts/wait-docker-install.ps1" "$BUNDLE_DIR/scripts/initialize-wsl-user.ps1" "$BUNDLE_DIR/scripts/install-wsl-docker-engine.ps1" "$BUNDLE_DIR/scripts/install-wsl-docker-engine.sh" "$BUNDLE_DIR/scripts/restore-wsl-project.ps1" "$BUNDLE_DIR/scripts/import.ps1" <<'PY'
from pathlib import Path
import re
import sys

EXPECTED_VALIDATOR_ARGS = 13
actual_validator_args = len(sys.argv) - 1
if actual_validator_args != EXPECTED_VALIDATOR_ARGS:
    raise SystemExit(
        'Generated BAT validation failed: expected '
        f'{EXPECTED_VALIDATOR_ARGS} validator arguments, got {actual_validator_args}.'
    )

bat = Path(sys.argv[1])
validate = Path(sys.argv[2])
features = Path(sys.argv[3])
distro = Path(sys.argv[4])
ready = Path(sys.argv[5])
restart = Path(sys.argv[6])
docker_restart = Path(sys.argv[7])
wait_docker = Path(sys.argv[8])
initialize_wsl_user = Path(sys.argv[9])
install_engine_ps1 = Path(sys.argv[10])
install_engine_sh = Path(sys.argv[11])
restore_wsl_project = Path(sys.argv[12])
import_ps1 = Path(sys.argv[13])

bat_bytes = bat.read_bytes()
if b"\r\n" not in bat_bytes:
    raise SystemExit('Generated BAT validation failed: setup-offline.bat must use CRLF line endings.')
if bat_bytes.replace(b"\r\n", b"").find(b"\n") != -1:
    raise SystemExit('Generated BAT validation failed: lone LF line ending detected.')

bat_text = bat_bytes.decode('utf-8')
# Normalize line endings for structural parsing.
# Keep bat_bytes unchanged above so CRLF validation remains strict.
normalized_bat_text = bat_text.replace('\r\n', '\n').replace('\r', '\n')
validate_text = validate.read_text(encoding='utf-8')
features_text = features.read_text(encoding='utf-8')
distro_text = distro.read_text(encoding='utf-8')
ready_text = ready.read_text(encoding='utf-8')
restart_text = restart.read_text(encoding='utf-8')
docker_restart_text = docker_restart.read_text(encoding='utf-8')
wait_docker_text = wait_docker.read_text(encoding='utf-8')
initialize_wsl_user_text = initialize_wsl_user.read_text(encoding='utf-8')
install_engine_ps1_text = install_engine_ps1.read_text(encoding='utf-8')
install_engine_sh_text = install_engine_sh.read_text(encoding='utf-8')
restore_wsl_project_text = restore_wsl_project.read_text(encoding='utf-8')
import_text = import_ps1.read_text(encoding='utf-8')
dual_import_requirements = [
    'docker.exe load -i',
    'DOCKER_HOST=unix:///run/devbox-docker.sock',
    'docker load -i',
    'docker.exe volume create',
    'docker volume create',
    'projects/DevBox-Lite',
    'prebuilt',
    'compose -p',
]
missing_import_requirements = [x for x in dual_import_requirements if x not in import_text]
if missing_import_requirements:
    raise SystemExit(
        'Generated import.ps1 validation failed: missing dual-restore requirements: '
        + ', '.join(missing_import_requirements)
    )

required_labels = [
    'main', 'resume', 'require_admin', 'validate_package',
    'enable_wsl_features', 'install_wsl', 'install_ubuntu',
    'install_docker', 'initialize_wsl_user', 'install_wsl_engine', 'restore_wsl_project', 'restore_devbox', 'verify', 'verify_wsl_engine_missing', 'verify_wsl_project_missing', 'schedule_restart',
    'save_stage', 'load_state_line', 'apply_state', 'cleanup_success', 'save_stage_error', 'resume_task_error', 'restart_schedule_error',
    'fail', 'features_restart', 'wsl_msi_restart', 'docker_restart', 'ubuntu_readiness_restart',
]
required_calls = [
    'call :validate_package',
    'call :enable_wsl_features',
    'call :install_wsl',
    'call :install_ubuntu',
    'call :install_docker',
    'call :initialize_wsl_user',
    'call :install_wsl_engine',
    'call :restore_wsl_project',
    'call :restore_devbox',
    'call :verify',
    'call :schedule_restart',
]

labels = re.findall(r'^\s*:([A-Za-z0-9_]+)\s*$', normalized_bat_text, re.M)
label_set = set(labels)
if len(labels) != len(label_set):
    duplicates = sorted({x for x in labels if labels.count(x) > 1})
    raise SystemExit('Generated BAT validation failed: duplicate labels: ' + ', '.join(duplicates))

# Validate every actual CALL/GOTO label reference, not just a fixed allowlist.
# This prevents missing-label regressions such as ensure_wsl_ready.
call_refs = re.findall(r'\bcall\s+:([A-Za-z0-9_]+)', normalized_bat_text, re.I)
goto_refs = re.findall(r'\bgoto\s+:([A-Za-z0-9_]+)', normalized_bat_text, re.I)
referenced_labels = sorted(set(call_refs + goto_refs))
missing_refs = [name for name in referenced_labels if name.lower() not in {'eof', 'resume_done'} and name not in label_set]
if missing_refs:
    raise SystemExit('Generated BAT validation failed: unresolved labels: ' + ', '.join(missing_refs))

if 'docker_wait_loop' in normalized_bat_text and ':docker_wait_loop' not in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: docker_wait_loop label is malformed.')

save_stage_marker = ':save_stage\n'
save_stage_error_marker = ':save_stage_error\n'
if save_stage_marker not in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: :save_stage label not found.')
if save_stage_error_marker not in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: :save_stage_error label not found.')

save_stage_block = (
    normalized_bat_text.split(save_stage_marker, 1)[1]
    .split(save_stage_error_marker, 1)[0]
)
if 'echo DEST_PATH=' in save_stage_block and 'if errorlevel 1 goto :save_stage_error' in save_stage_block.split('>>', 1)[0]:
    raise SystemExit('Generated BAT validation failed: save_stage must not test stale ERRORLEVEL after ECHO redirection.')

missing = [x for x in required_labels if x not in label_set]
if missing:
    raise SystemExit('Generated BAT validation failed: missing labels: ' + ', '.join(missing))

missing = [x for x in required_calls if x not in normalized_bat_text]
if missing:
    raise SystemExit('Generated BAT validation failed: missing calls: ' + ', '.join(missing))

resume_requirements = [
    'DevBoxLite-OfflineSetup-Startup',
    'DevBoxLite-OfflineSetup-Logon',
    'schtasks /create /tn "%TASK_START%" /sc onstart',
    'schtasks /create /tn "%TASK_LOGON%" /sc onlogon',
    'resume-offline-setup.lock',
    'resume.log',
    'offline-setup.state',
]
missing_resume = [x for x in resume_requirements if x not in normalized_bat_text]
if missing_resume:
    raise SystemExit('Generated BAT validation failed: automatic resume requirements are missing: ' + ', '.join(missing_resume))

if 'goto :eof' in normalized_bat_text.lower():
    raise SystemExit('Generated BAT validation failed: goto :eof is not permitted.')

if 'ubuntu_registration_wait' in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: obsolete ubuntu_registration_wait label detected.')

if 'wsl.exe -l -q 2>nul | findstr /I /X "Ubuntu-24.04"' in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: obsolete Ubuntu findstr detection detected.')

if 'validate-offline.ps1' not in normalized_bat_text or 'manage-wsl-features.ps1' not in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: required PowerShell scripts are not referenced.')

if 'check-wsl-distro.ps1' not in normalized_bat_text or 'check-wsl-ready.ps1' not in normalized_bat_text or 'check-restart-required.ps1' not in normalized_bat_text or 'check-docker-restart-required.ps1' not in normalized_bat_text or 'wait-docker-install.ps1' not in normalized_bat_text or 'initialize-wsl-user.ps1' not in normalized_bat_text or 'install-wsl-docker-engine.ps1' not in normalized_bat_text or 'restore-wsl-project.ps1' not in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: helper PowerShell scripts are not referenced.')
def find_label_line(text, label):
    match = re.search(rf'(?m)^:{re.escape(label)}\s*$', text)
    return match.start() if match else -1

install_wsl_start = find_label_line(normalized_bat_text, 'install_wsl')
install_ubuntu_start = find_label_line(normalized_bat_text, 'install_ubuntu')
if install_wsl_start == -1 or install_ubuntu_start == -1 or install_ubuntu_start <= install_wsl_start:
    raise SystemExit('Generated BAT validation failed: install_wsl/install_ubuntu sections could not be located.')
install_wsl_text = normalized_bat_text[install_wsl_start:install_ubuntu_start]
if 'WSL_INSTALLED_NOW=0' not in install_wsl_text or 'if not "%WSL_INSTALLED_NOW%"=="1" goto :wsl_restart_check_done' not in install_wsl_text or ':wsl_restart_check_done' not in install_wsl_text:
    raise SystemExit('Generated BAT validation failed: WSL restart check must only run after a fresh WSL MSI installation.')

if 'call :save_stage START' in normalized_bat_text:
    raise SystemExit('Generated BAT validation failed: startup must not depend on save_stage START.')

if re.search(r'for\s+/f[^\n]*powershell\.exe', normalized_bat_text, re.I):
    raise SystemExit('Generated BAT validation failed: inline PowerShell for /f parser pattern detected.')

if 'param(' not in validate_text or '-LiteralPath' not in validate_text:
    raise SystemExit('Generated validation script check failed.')
import_text = import_ps1.read_text(encoding='utf-8')
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

if 'Installation succeeded' not in wait_docker_text or 'Start-Process' not in wait_docker_text or 'TimeoutSeconds' not in wait_docker_text:
    raise SystemExit('Generated Docker install waiter validation failed.')

if (
        'Ubuntu-24.04 requires first-run account setup.' not in initialize_wsl_user_text or
        'The account will be created in this installer window.' not in initialize_wsl_user_text or
        'You do not need to open Ubuntu or type exit.' not in initialize_wsl_user_text or
        'Installer will continue automatically.' not in initialize_wsl_user_text or
        'Read-Host' not in initialize_wsl_user_text or
        'chpasswd' not in initialize_wsl_user_text or
        'wsl.exe -d $Distribution -u root' not in initialize_wsl_user_text or
        'Start-Process -FilePath' in initialize_wsl_user_text or
        'A separate Ubuntu terminal will open now.' in initialize_wsl_user_text
):
    raise SystemExit('Generated Ubuntu first-run helper validation failed: first-run must stay in the installer window and continue automatically.')

if ('systemd=true' not in install_engine_sh_text or
        'wsl-engine' not in install_engine_sh_text or
        'devbox-docker.sock' not in install_engine_sh_text or
        'apt-get install -y --no-download --no-install-recommends' not in install_engine_sh_text):
    raise SystemExit('Generated WSL Docker Engine installer validation failed: offline package install mechanism is incomplete.')
if ('wsl-engine' not in install_engine_ps1_text or
        'install-wsl-docker-engine.sh' not in install_engine_ps1_text or
        'ToBase64String' not in install_engine_ps1_text or
        'wslpath -u' not in install_engine_ps1_text or
        'base64 -d' not in install_engine_ps1_text):
    raise SystemExit('Generated WSL Docker Engine PowerShell helper validation failed: Windows-to-WSL path bridge is incomplete.')
if ('project-src.tar.gz' not in restore_wsl_project_text or
        'projects/DevBox-Lite' not in restore_wsl_project_text or
        'getent passwd' not in restore_wsl_project_text or
        'chown -R' not in restore_wsl_project_text or
        'ToBase64String' not in restore_wsl_project_text or
        'base64 -d' not in restore_wsl_project_text or
        'wslpath -u' not in restore_wsl_project_text):
    raise SystemExit('Generated WSL project restore helper validation failed.')

install_docker_start = find_label_line(normalized_bat_text, 'install_docker')
restore_start = find_label_line(normalized_bat_text, 'restore_devbox')
if install_docker_start == -1 or restore_start == -1 or restore_start <= install_docker_start:
    raise SystemExit('Generated BAT validation failed: install_docker/restore_devbox sections could not be located.')
install_docker_text = normalized_bat_text[install_docker_start:restore_start]
if 'start /wait' in install_docker_text.lower() and 'docker desktop installer' in install_docker_text.lower():
    raise SystemExit('Generated BAT validation failed: Docker installer must not block on start /wait.')
if 'wait_for_docker_install' not in install_docker_text:
    raise SystemExit('Generated BAT validation failed: Docker installation waiter is not used.')

engine_start = find_label_line(normalized_bat_text, 'install_wsl_engine')
if engine_start == -1 or install_docker_start == -1 or install_docker_start <= engine_start:
    raise SystemExit('Generated BAT validation failed: install_wsl_engine/install_docker sections could not be located.')
engine_text = normalized_bat_text[engine_start:install_docker_start]
if 'install-wsl-docker-engine.ps1' not in engine_text:
    raise SystemExit('Generated BAT validation failed: WSL Docker Engine installer is not invoked.')

if 'RebootPending' not in restart_text and 'RebootRequired' not in restart_text:
    raise SystemExit('Generated restart helper validation failed.')

if ('wsl.exe --status' not in install_wsl_text or
        'wsl.exe --list --quiet' not in install_wsl_text or
        'WSL_INSTALLED_NOW=0' not in install_wsl_text):
    raise SystemExit('Generated WSL installer validation failed: existing WSL detection is incomplete.')

print('  [ok] Generated setup-offline.bat structural validation passed')
print('  [ok] Generated PowerShell validation scripts passed')
PY

echo "  [ok] setup-offline.bat"

# ------------------------------------------------------------
# Clear Windows Mark-of-the-Web metadata from the generated offline package
# ------------------------------------------------------------
# Windows SmartScreen can show "Windows protected your PC" when files carry
# the Zone.Identifier alternate data stream. Remove that metadata from the
# package while it is still on the export machine. This does not disable
# SmartScreen globally and does not affect unrelated files on Windows.
if command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  OUT_WIN_PATH="$(wslpath -w "$ABS_OUT" 2>/dev/null || true)"
  if [ -n "$OUT_WIN_PATH" ]; then
    echo ""
    echo "[export] Clearing Windows Mark-of-the-Web metadata..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \
      "\$root = '$OUT_WIN_PATH'; Get-ChildItem -LiteralPath \$root -Recurse -Force -File | Unblock-File -ErrorAction SilentlyContinue" \
      >/dev/null 2>&1 || true
    echo "  [ok] Mark-of-the-Web metadata cleared from generated package files"
  else
    echo "  [warn] Could not resolve Windows output path; SmartScreen metadata was not cleared."
  fi
else
  echo "  [warn] powershell.exe/wslpath unavailable; SmartScreen metadata was not cleared."
fi


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
  echo "wsl_docker_engine:enabled"
  echo "wsl_docker_engine_socket:unix:///run/devbox-docker.sock"
  echo "wsl_docker_engine_context:wsl-engine"
  echo "wsl_docker_engine_package_dir:docker-engine/debs"
  echo "docker-engine-package-count:$(find "$DOCKER_ENGINE_DEB_DIR" -maxdepth 1 -type f -name '*.deb' | wc -l)"
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
  while IFS='|' read -r pkg_name pkg_version pkg_arch deb_name deb_sha; do
    [ -n "$deb_sha" ] || continue
    echo "docker-engine/$deb_name:$deb_sha"
  done < "$DOCKER_ENGINE_META"
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
  "$BUNDLE_DIR/scripts/wait-docker-install.ps1"
  "$BUNDLE_DIR/scripts/initialize-wsl-user.ps1"
  "$BUNDLE_DIR/scripts/install-wsl-docker-engine.ps1"
  "$BUNDLE_DIR/scripts/install-wsl-docker-engine.sh"
  "$BUNDLE_DIR/scripts/restore-wsl-project.ps1"
  "$BUNDLE_DIR/docker-engine/packages.txt"
)

if ! compgen -G "$BUNDLE_DIR/docker-engine/debs/*.deb" > /dev/null; then
  echo "[error] Docker Engine .deb package bundle is missing or empty."
  exit 1
fi

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
    'wsl_docker_engine:',
    'wsl_docker_engine_socket:',
    'wsl_docker_engine_context:',
    'wsl_docker_engine_package_dir:',
    'docker-engine-package-count:',
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
    entries[key] = value

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

engine_meta = bundle / 'docker-engine' / 'packages.txt'
engine_dir = bundle / 'docker-engine' / 'debs'
if not engine_meta.exists():
    raise SystemExit('Manifest validation failed: Docker Engine package metadata is missing')
engine_lines = []
for line in engine_meta.read_text(encoding='utf-8').splitlines():
    parts = line.split('|')
    if len(parts) == 5 and all(parts):
        engine_lines.append(line)
engine_count = len(engine_lines)
expected_count_text = entries.get('docker-engine-package-count', '')
try:
    expected_count = int(expected_count_text)
except ValueError:
    raise SystemExit(f'Manifest validation failed: invalid Docker Engine package count: {expected_count_text!r}')
actual_deb_files = sorted(engine_dir.glob('*.deb'))
actual_file_count = len(actual_deb_files)
if expected_count != engine_count or expected_count != actual_file_count:
    raise SystemExit(
        'Manifest validation failed: Docker Engine package count mismatch '
        f'(manifest={expected_count}, metadata={engine_count}, files={actual_file_count})'
    )
for line in engine_meta.read_text(encoding='utf-8').splitlines():
    parts = line.split('|')
    if len(parts) != 5:
        continue
    _pkg, _ver, _arch, deb_name, expected_sha = parts
    if not deb_name.endswith('.deb'):
        continue
    deb_path = engine_dir / deb_name
    if not deb_path.exists():
        raise SystemExit(f'Manifest validation failed: Docker Engine package missing: {deb_name}')
    actual = sha256(deb_path)
    if actual != expected_sha:
        raise SystemExit(f'Manifest validation failed: Docker Engine SHA256 mismatch: {deb_name}')

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
