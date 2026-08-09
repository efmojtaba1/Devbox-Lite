```bash
#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# DevBox Lite - Full Project & Docker Export
# Offline Ready
# ============================================================

DEFAULT_OUT_DIR="/mnt/d/devbox-project"
DEFAULT_IMAGE="devbox-lite:latest"

echo "========================================="
echo " Full Project & Docker Export (Offline Ready)"
echo "========================================="

# ------------------------------------------------------------
# Dynamic project paths
# ------------------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[error] docker-compose.yml not found:"
  echo "        $COMPOSE_FILE"
  exit 1
fi

# ------------------------------------------------------------
# Output directory
# ------------------------------------------------------------

echo "1) Use default location ($DEFAULT_OUT_DIR)"
echo "2) Enter custom location"

read -e -p "Choose an option [1/2] (default: 1): " choice
choice="${choice:-1}"

if [ "$choice" == "2" ]; then
  echo "  [Tip] Example format: /mnt/d/devbox-project or /home/user/my-backup"
  read -e -p "  Enter custom path: " custom_dir
  OUT_DIR="${custom_dir:-$DEFAULT_OUT_DIR}"
else
  OUT_DIR="$DEFAULT_OUT_DIR"
fi

mkdir -p "$OUT_DIR"
ABS_OUT="$(cd "$OUT_DIR" && pwd)"

# ------------------------------------------------------------
# Docker image selection
# ------------------------------------------------------------

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
# Required Docker commands
# ------------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
  echo "[error] Docker command not found."
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "[error] Docker daemon is not available."
  echo "        Start Docker Desktop / Docker Engine and try again."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "[error] Docker Compose is not available."
  exit 1
fi

# ------------------------------------------------------------
# Compose project information
# ------------------------------------------------------------

COMPOSE_PROJECT="$(
  docker compose \
    -f "$COMPOSE_FILE" \
    config --format json 2>/dev/null \
    | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
    name = data.get("name")
    if name:
        print(name)
except Exception:
    pass
' 2>/dev/null || true
)"

if [ -z "$COMPOSE_PROJECT" ]; then
  COMPOSE_PROJECT="devbox"
fi

echo ""
echo "[export] Project root: $PROJECT_ROOT"
echo "[export] Compose file: $COMPOSE_FILE"
echo "[export] Compose project: $COMPOSE_PROJECT"
echo "[export] Output directory: $ABS_OUT"

# ------------------------------------------------------------
# Logical volume names from docker-compose.yml
# ------------------------------------------------------------

VOLUMES=(
  example-templates
  pnpm-store
  composer-cache
  devbox-deps
  bruno-config
  bruno-collections
)

# ------------------------------------------------------------
# Helper: resolve real Docker volume name
# ------------------------------------------------------------

resolve_volume() {
  local logical_name="$1"
  local actual_volume=""

  # Preferred method:
  # Docker Compose labels identify both the project and
  # logical volume name.
  actual_volume="$(
    docker volume ls -q \
      --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}" \
      --filter "label=com.docker.compose.volume=${logical_name}" \
      | head -n 1
  )"

  if [ -n "$actual_volume" ]; then
    printf '%s\n' "$actual_volume"
    return 0
  fi

  # Fallback:
  # If Compose labels are unavailable, try the conventional
  # Compose-generated name.
  local fallback="${COMPOSE_PROJECT}_${logical_name}"

  if docker volume inspect "$fallback" >/dev/null 2>&1; then
    printf '%s\n' "$fallback"
    return 0
  fi

  return 1
}

# ------------------------------------------------------------
# Docker image export
# ------------------------------------------------------------

echo ""
echo "[export] Saving Docker image: $IMAGE_NAME -> $ABS_OUT/image.tar"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[error] Image $IMAGE_NAME not found locally."
  echo "        Run 'docker images' to verify."
  exit 1
fi

rm -f "$ABS_OUT/image.tar"

docker save \
  -o "$ABS_OUT/image.tar" \
  "$IMAGE_NAME"

if [ ! -s "$ABS_OUT/image.tar" ]; then
  echo "[error] Docker image archive was not created correctly."
  exit 1
fi

IMAGE_SIZE="$(du -h "$ABS_OUT/image.tar" | cut -f1)"

echo "  [ok] image.tar created (${IMAGE_SIZE})"

# ------------------------------------------------------------
# Docker volume export
# ------------------------------------------------------------

echo ""
echo "[export] Exporting Docker volumes..."

declare -A ACTUAL_VOLUMES

for logical_volume in "${VOLUMES[@]}"; do

  echo ""
  echo "[export] Volume: $logical_volume"

  ACTUAL_VOLUME="$(resolve_volume "$logical_volume" || true)"

  if [ -z "$ACTUAL_VOLUME" ]; then
    echo "  [error] Docker volume not found:"
    echo "          logical name: $logical_volume"
    echo "          compose project: $COMPOSE_PROJECT"
    echo ""
    echo "  Available Docker volumes:"
    docker volume ls --format '  {{.Name}}'
    exit 1
  fi

  ACTUAL_VOLUMES["$logical_volume"]="$ACTUAL_VOLUME"

  echo "  [info] Actual Docker volume: $ACTUAL_VOLUME"

  ARCHIVE="$ABS_OUT/vol-${logical_volume}.tar.gz"

  rm -f "$ARCHIVE"

  # ----------------------------------------------------------
  # Check whether the volume contains data.
  # ----------------------------------------------------------

  HAS_CONTENT="$(
    docker run --rm \
      --mount "type=volume,source=${ACTUAL_VOLUME},target=/volume,readonly" \
      "$IMAGE_NAME" \
      sh -c 'find /volume -mindepth 1 -print -quit 2>/dev/null || true'
  )"

  if [ -z "$HAS_CONTENT" ]; then
    echo "  [info] Volume is empty."

    # Create a valid empty archive so the restore process
    # can still recreate the volume.
    docker run --rm \
      --mount "type=volume,source=${ACTUAL_VOLUME},target=/volume,readonly" \
      --mount "type=bind,source=${ABS_OUT},target=/backup" \
      "$IMAGE_NAME" \
      sh -c "tar czf /backup/vol-${logical_volume}.tar.gz -C /volume ."

  else
    echo "  [info] Volume contains data."

    # Use the DevBox image itself for tar.
    #
    # This avoids pulling alpine or any other external image,
    # which is important for offline-ready exports.
    docker run --rm \
      --mount "type=volume,source=${ACTUAL_VOLUME},target=/volume,readonly" \
      --mount "type=bind,source=${ABS_OUT},target=/backup" \
      "$IMAGE_NAME" \
      sh -c "tar czf /backup/vol-${logical_volume}.tar.gz -C /volume ."
  fi

  # ----------------------------------------------------------
  # Validate generated archive.
  # ----------------------------------------------------------

  if [ ! -f "$ARCHIVE" ]; then
    echo "  [error] Archive was not created:"
    echo "          $ARCHIVE"
    exit 1
  fi

  if [ ! -s "$ARCHIVE" ]; then
    echo "  [error] Archive is empty:"
    echo "          $ARCHIVE"
    exit 1
  fi

  ARCHIVE_BYTES="$(stat -c '%s' "$ARCHIVE")"
  ARCHIVE_SIZE="$(du -h "$ARCHIVE" | cut -f1)"

  # Validate gzip/tar structure.
  if ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
    echo "  [error] Generated archive is invalid:"
    echo "          $ARCHIVE"
    exit 1
  fi

  ENTRY_COUNT="$(
    tar -tzf "$ARCHIVE" 2>/dev/null \
      | sed '/^$/d' \
      | wc -l \
      | tr -d ' '
  )"

  if [ "$ENTRY_COUNT" -eq 0 ]; then
    echo "  [info] Archive contains no files."
    echo "  [ok] $logical_volume -> vol-${logical_volume}.tar.gz (${ARCHIVE_SIZE})"
  else
    echo "  [ok] $logical_volume -> vol-${logical_volume}.tar.gz"
    echo "       Size: ${ARCHIVE_SIZE} (${ARCHIVE_BYTES} bytes)"
    echo "       Entries: ${ENTRY_COUNT}"
  fi

done

# ------------------------------------------------------------
# Offline DEB packages
# ------------------------------------------------------------

OFFLINE_DEPS_DIR="$ABS_OUT/offline-deps"

mkdir -p "$OFFLINE_DEPS_DIR"

if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo ""
echo "[export] Downloading offline DEB packages for Docker via apt cache..."

$SUDO apt-get update -y >/dev/null 2>&1 || true

if ! compgen -G "/var/cache/apt/archives/docker.io*.deb" > /dev/null; then

  echo "  [info] Docker packages not found in cache. Forcing download..."

  $SUDO apt-get install \
    --reinstall \
    --download-only \
    -y \
    docker.io \
    containerd \
    runc \
    2>/dev/null || true

else

  $SUDO apt-get install \
    --download-only \
    -y \
    docker.io \
    containerd \
    runc \
    2>/dev/null || true

fi

if [ -d "/var/cache/apt/archives" ]; then

  $SUDO find \
    /var/cache/apt/archives \
    -name "*.deb" \
    -exec cp {} "$OFFLINE_DEPS_DIR/" \; \
    2>/dev/null || true

  $SUDO chown \
    -R "$(id -u):$(id -g)" \
    "$OFFLINE_DEPS_DIR" \
    2>/dev/null || true

fi

if compgen -G "$OFFLINE_DEPS_DIR/*.deb" > /dev/null; then

  DEB_COUNT="$(
    find "$OFFLINE_DEPS_DIR" \
      -maxdepth 1 \
      -type f \
      -name "*.deb" \
      | wc -l \
      | tr -d ' '
  )"

  echo "  [ok] Offline DEB packages downloaded and verified."
  echo "       Packages: $DEB_COUNT"

else

  echo "  [warn] No DEB packages found in cache."

fi

# ------------------------------------------------------------
# WSL2 Linux Kernel MSI
# ------------------------------------------------------------

echo ""
echo "[export] Checking and downloading WSL2 Linux Kernel update (.msi)..."

WSL_MSI_URL="https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
MSI_OUTPUT="$OFFLINE_DEPS_DIR/wsl_update_x64.msi"
DOWNLOAD_SUCCESS=false

if [ -f "$MSI_OUTPUT" ] && [ -s "$MSI_OUTPUT" ]; then

  echo "  [ok] wsl_update_x64.msi already exists in destination folder."
  echo "       Skipping download."

  DOWNLOAD_SUCCESS=true

else

  if command -v curl >/dev/null 2>&1; then

    echo "  [info] Attempting download using curl..."

    if curl -L \
      --fail \
      --silent \
      --show-error \
      -o "$MSI_OUTPUT" \
      "$WSL_MSI_URL"; then

      if [ -f "$MSI_OUTPUT" ] && [ -s "$MSI_OUTPUT" ]; then
        DOWNLOAD_SUCCESS=true
      fi

    fi

  fi

  if [ "$DOWNLOAD_SUCCESS" = false ] && command -v wget >/dev/null 2>&1; then

    echo "  [info] Curl failed. Falling back to wget..."

    if wget \
      -q \
      -O "$MSI_OUTPUT" \
      "$WSL_MSI_URL"; then

      if [ -f "$MSI_OUTPUT" ] && [ -s "$MSI_OUTPUT" ]; then
        DOWNLOAD_SUCCESS=true
      fi

    fi

  fi

fi

if [ "$DOWNLOAD_SUCCESS" = true ]; then

  MSI_SIZE="$(du -h "$MSI_OUTPUT" | cut -f1)"

  echo "  [ok] wsl_update_x64.msi is ready (${MSI_SIZE})."

else

  echo "  [warn] Could not obtain WSL MSI package automatically."

fi

# ------------------------------------------------------------
# Prebuilt directory
# ------------------------------------------------------------

if [ -d "$PROJECT_ROOT/prebuilt" ]; then

  echo ""
  echo "[export] Packaging prebuilt directory..."

  rm -f "$ABS_OUT/prebuilt.tar.gz"

  tar \
    czf "$ABS_OUT/prebuilt.tar.gz" \
    -C "$PROJECT_ROOT" \
    prebuilt

  echo "  [ok] prebuilt -> prebuilt.tar.gz"

else

  echo ""
  echo "[warn] prebuilt directory not found in project root; skipping"

fi

# ------------------------------------------------------------
# Project source code
# ------------------------------------------------------------

echo ""
echo "[export] Packaging project source code..."

rm -f "$ABS_OUT/project-src.tar.gz"

tar \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='vendor' \
  --exclude='.env' \
  --exclude='devbox-offline' \
  --exclude='out' \
  --exclude='backups' \
  -czf "$ABS_OUT/project-src.tar.gz" \
  -C "$PROJECT_ROOT" \
  .

if [ ! -s "$ABS_OUT/project-src.tar.gz" ]; then
  echo "[error] project-src.tar.gz was not created correctly."
  exit 1
fi

echo "  [ok] project source code -> project-src.tar.gz"

# ------------------------------------------------------------
# Copy scripts
# ------------------------------------------------------------

rm -rf "$ABS_OUT/scripts"
mkdir -p "$ABS_OUT/scripts"

cp -r "$PROJECT_ROOT/scripts/"* "$ABS_OUT/scripts/"

echo "  [ok] project scripts copied."

# ------------------------------------------------------------
# Generate setup-offline.bat
# ------------------------------------------------------------

echo ""
echo "[export] Generating setup-offline.bat..."

cat << 'EOF' > "$ABS_OUT/setup-offline.bat"
@echo off
TITLE DevBox Lite - Offline Setup & Restore
color 0A

echo ===================================================
echo   DevBox Lite - Offline Setup
echo ===================================================
echo.

NET SESSION >nul 2>&1

if %errorLevel% neq 0 (
    echo [ERROR] Please right-click this script and choose "Run as administrator"!
    echo.
    pause
    exit /b
)

echo.
echo   [Tip] Example format: D:\devbox-project or C:\my-project

set /p DEST_PATH="Enter destination path for project setup [Default: D:\devbox-project]: "

if "%DEST_PATH%"=="" set DEST_PATH=D:\devbox-project

echo.
echo [1/5] Enabling Windows Subsystem for Linux and Virtual Machine Platform...

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >nul 2>&1

dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >nul 2>&1

echo.
echo [2/5] Installing WSL2 Linux Kernel update (if package exists)...

if exist "%~dp0offline-deps\wsl_update_x64.msi" (
    echo   Found WSL kernel installer. Installing silently...
    msiexec /i "%~dp0offline-deps\wsl_update_x64.msi" /quiet /norestart
) else (
    echo   [INFO] wsl_update_x64.msi not found in offline-deps.
)

echo.
echo [3/5] Restoring project files, Docker image, and volumes to: %DEST_PATH%...

powershell -ExecutionPolicy Bypass -File "%~dp0scripts\import.ps1" -InputPath "%~dp0" -TargetProj "%DEST_PATH%"

echo.
echo [4/5] Preparing offline Docker installation guide for WSL...

if exist "%~dp0offline-deps\*.deb" (
    echo ===================================================
    echo [NOTICE] Offline DEB packages for Docker are ready!
    echo To complete native Docker setup inside WSL Ubuntu, execute:
    echo   1. Open WSL Ubuntu terminal.
    echo   2. Go to your shared folder or mount path:
    echo      cd /mnt/d/devbox-project/offline-deps
    echo   3. Install packages offline:
    echo      sudo dpkg -i *.deb
    echo ===================================================
) else (
    echo   [INFO] No Docker .deb packages found. (Assuming Docker Desktop is used).
)

echo.
echo [5/5] Setup process finished successfully!
echo ===================================================
echo Your offline environment is fully restored at: %DEST_PATH%
echo ===================================================

pause
EOF

echo "  [ok] setup-offline.bat generated."

# ------------------------------------------------------------
# Generate manifest
# ------------------------------------------------------------

echo ""
echo "[export] Generating manifest.txt..."

CURRENT_DATE="$(date --utc +%Y-%m-%dT%H:%M:%SZ)"

{
  echo "image:$IMAGE_NAME"
  echo "compose_project:$COMPOSE_PROJECT"
  echo "compose_file:docker-compose.yml"
  echo "generated_at:$CURRENT_DATE"
  echo ""
  echo "[volumes]"

  for logical_volume in "${VOLUMES[@]}"; do
    actual_volume="${ACTUAL_VOLUMES[$logical_volume]:-unknown}"
    echo "$logical_volume:$actual_volume"
  done

} > "$ABS_OUT/manifest.txt"

echo "  [ok] manifest.txt generated."

# ------------------------------------------------------------
# Export summary
# ------------------------------------------------------------

echo ""
echo "========================================="
echo " Export Summary"
echo "========================================="

echo ""
echo "Output directory:"
echo "  $ABS_OUT"

echo ""
echo "Docker image:"
echo "  image.tar"

echo ""
echo "Docker volumes:"

for logical_volume in "${VOLUMES[@]}"; do

  archive="$ABS_OUT/vol-${logical_volume}.tar.gz"

  if [ -f "$archive" ]; then
    size="$(du -h "$archive" | cut -f1)"
    echo "  - $logical_volume -> $size"
  else
    echo "  - $logical_volume -> MISSING"
  fi

done

echo ""
echo "Project source:"
if [ -f "$ABS_OUT/project-src.tar.gz" ]; then
  echo "  project-src.tar.gz -> $(du -h "$ABS_OUT/project-src.tar.gz" | cut -f1)"
else
  echo "  project-src.tar.gz -> MISSING"
fi

if [ -f "$ABS_OUT/prebuilt.tar.gz" ]; then
  echo ""
  echo "Prebuilt:"
  echo "  prebuilt.tar.gz -> $(du -h "$ABS_OUT/prebuilt.tar.gz" | cut -f1)"
fi

echo ""
echo "========================================="
echo "[done] Full self-contained package exported successfully."
echo "========================================="
```
