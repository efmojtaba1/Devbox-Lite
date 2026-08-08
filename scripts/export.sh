#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OUT_DIR="/mnt/d/devbox-project"
DEFAULT_IMAGE="devbox-lite:latest"

echo "========================================="
echo " Full Project & Docker Export (Offline Ready)"
echo "========================================="
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

echo ""
echo "1) Use default image ($DEFAULT_IMAGE)"
echo "2) Enter custom image name"
read -e -p "Choose an option [1/2] (default: 1): " img_choice
img_choice="${img_choice:-1}"

if [ "$img_choice" == "2" ]; then
  read -e -p "  Enter image name to save: " custom_image
  IMAGE_NAME="${custom_image:-$DEFAULT_IMAGE}"
else
  IMAGE_NAME="$DEFAULT_IMAGE"
fi

VOLUMES=(example-templates pnpm-store composer-cache devbox-deps bruno-config bruno-collections)
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "$OUT_DIR"
ABS_OUT="$(cd "$OUT_DIR" && pwd)"

echo "[export] Saving Docker image: $IMAGE_NAME -> $ABS_OUT/image.tar"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[error] Image $IMAGE_NAME not found locally. Run 'docker images' to verify." >&2
  exit 1
fi
docker save -o "$ABS_OUT/image.tar" "$IMAGE_NAME"

echo "[export] Exporting Docker volumes..."
for v in "${VOLUMES[@]}"; do
  echo "[export] Volume: $v"
  docker run --rm -v "${v}":/volume -v "$ABS_OUT":/backup alpine sh -c "cd /volume 2>/dev/null || true; tar czf /backup/vol-${v}.tar.gz -C /volume . || tar czf /backup/vol-${v}.tar.gz --files-from /dev/null"
  if [ -f "$ABS_OUT/vol-${v}.tar.gz" ]; then
    echo "  [ok] $v -> vol-${v}.tar.gz"
  else
    echo "  [warn] vol-${v}.tar.gz not created (volume may be empty)"
  fi
done

OFFLINE_DEPS_DIR="$ABS_OUT/offline-deps"
mkdir -p "$OFFLINE_DEPS_DIR"

if [ "$EUID" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "[export] Downloading offline DEB packages for Docker via apt cache..."
$SUDO apt-get update -y >/dev/null 2>&1 || true

if ! compgen -G "/var/cache/apt/archives/docker.io*.deb" > /dev/null; then
  echo "  [info] Docker packages not found in cache. Forcing download..."
  $SUDO apt-get install --reinstall --download-only -y docker.io containerd runc 2>/dev/null || true
else
  $SUDO apt-get install --download-only -y docker.io containerd runc 2>/dev/null || true
fi

if [ -d "/var/cache/apt/archives" ]; then
  $SUDO find /var/cache/apt/archives -name "*.deb" -exec cp {} "$OFFLINE_DEPS_DIR/" \; 2>/dev/null || true
  $SUDO chown -R $(id -u):$(id -g) "$OFFLINE_DEPS_DIR" 2>/dev/null || true
fi

if compgen -G "$OFFLINE_DEPS_DIR/*.deb" > /dev/null; then
  echo "  [ok] Offline DEB packages downloaded and verified successfully."
else
  echo "  [warn] No DEB packages found in cache."
fi

echo "[export] Downloading WSL2 Linux Kernel update (.msi) from Microsoft..."
WSL_MSI_URL="https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
if command -v curl >/dev/null 2>&1; then
  curl -L -s -o "$OFFLINE_DEPS_DIR/wsl_update_x64.msi" "$WSL_MSI_URL" || true
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$OFFLINE_DEPS_DIR/wsl_update_x64.msi" "$WSL_MSI_URL" || true
fi

if [ -f "$OFFLINE_DEPS_DIR/wsl_update_x64.msi" ]; then
  echo "  [ok] wsl_update_x64.msi downloaded successfully."
else
  echo "  [warn] Could not download WSL MSI package automatically."
fi

if [ -d "$PROJECT_ROOT/prebuilt" ]; then
  echo "[export] Packaging prebuilt directory..."
  tar czf "$ABS_OUT/prebuilt.tar.gz" -C "$PROJECT_ROOT" prebuilt
  echo "  [ok] prebuilt -> prebuilt.tar.gz"
else
  echo "  [warn] prebuilt directory not found in project root; skipping"
fi

echo "[export] Packaging project source code..."
tar --exclude='.git' \
    --exclude='node_modules' \
    --exclude='vendor' \
    --exclude='.env' \
    --exclude='devbox-offline' \
    --exclude='out' \
    --exclude='backups' \
    -czf "$ABS_OUT/project-src.tar.gz" -C "$PROJECT_ROOT" .
echo "  [ok] project source code -> project-src.tar.gz"

mkdir -p "$ABS_OUT/scripts"
cp -r "$PROJECT_ROOT/scripts/"* "$ABS_OUT/scripts/"

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

cat <<EOF > "$ABS_OUT/manifest.txt"
image:$IMAGE_NAME
volumes:${VOLUMES[*]}
generated_at:$(date --utc +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[done] Full self-contained package exported successfully to: $ABS_OUT"
```[cite: 1]