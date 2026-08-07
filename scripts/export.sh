#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OUT_DIR="/mnt/d/devbox-image"
DEFAULT_IMAGE="devbox-lite:latest"

echo "========================================="
echo " Full Project & Docker Export (Offline Ready)"
echo "========================================="
echo "1) Use default location ($DEFAULT_OUT_DIR)"
echo "2) Enter custom location"
read -e -p "Choose an option [1/2] (default: 1): " choice
choice="${choice:-1}"

if [ "$choice" == "2" ]; then
  echo "  [Tip] Example format: /mnt/d/devbox-image or /home/user/my-backup"
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

# جمع‌آوری پکیج‌های آفلاین داکر و هسته WSL برای سیستم‌های بدون اینترنت مقصد
OFFLINE_DEPS_DIR="$ABS_OUT/offline-deps"
mkdir -p "$OFFLINE_DEPS_DIR"

echo "[export] Downloading offline DEB packages for Docker (if internet is available)..."
apt-get update -y >/dev/null 2>&1 || true
apt-get download docker.io docker-compose-v2 containerd.io docker-buildx 2>/dev/null || true
if compgen -G "*.deb" > /dev/null; then
  mv *.deb "$OFFLINE_DEPS_DIR/"
  echo "  [ok] Offline DEB packages saved."
else
  echo "  [warn] Could not download offline debs automatically."
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
  echo "  [warn] Could not download WSL MSI package automatically (internet required)."
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

# ساخت خودکار فایل setup-offline.bat پیشرفته در ریشه پوشه خروجی
echo "[export] Generating ultimate setup-offline.bat..."
cat << 'EOF' > "$ABS_OUT/setup-offline.bat"
@echo off
TITLE DevBox Lite - Ultimate Offline Setup & Restore
color 0A
echo ===================================================
echo   DevBox Lite - Ultimate Offline Setup
echo ===================================================
echo.

:: 1. Check Administrator Rights
NET SESSION >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Please right-click this script and choose "Run as administrator"!
    echo Administrator rights are required to install WSL features and packages.
    echo.
    pause
    exit /b
)

echo [1/5] Enabling Windows Subsystem for Linux and Virtual Machine Platform...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >nul 2>&1
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >nul 2>&1

echo [2/5] Installing WSL2 Linux Kernel update (if package exists)...
if exist "%~dp0offline-deps\wsl_update_x64.msi" (
    echo   Found WSL kernel installer. Installing silently...
    msiexec /i "%~dp0offline-deps\wsl_update_x64.msi" /quiet /norestart
) else (
    echo   [INFO] wsl_update_x64.msi not found in offline-deps (Skipping kernel install).
)

echo.
echo [3/5] Restoring project files, Docker image, and volumes...
powershell -ExecutionPolicy Bypass -File "%~dp0scripts\import.ps1" -InputPath "%~dp0"

echo.
echo [4/5] Preparing offline Docker installation guide for WSL...
if exist "%~dp0offline-deps\*.deb" (
    echo ===================================================
    echo [NOTICE] Offline DEB packages for Docker are ready!
    echo To complete native Docker setup inside WSL Ubuntu, execute:
    echo   1. Open WSL Ubuntu terminal.
    echo   2. Go to your shared folder or mount path:
    echo      cd /mnt/e/devbox-backup/offline-deps
    echo   3. Install packages offline:
    echo      sudo dpkg -i *.deb
    echo ===================================================
) else (
    echo   [INFO] No Docker .deb packages found in offline-deps. (Assuming Docker Desktop is used).
)

echo.
echo [5/5] Setup process finished successfully!
echo ===================================================
echo Your offline environment is fully restored.
echo ===================================================
pause
EOF

cat > "$ABS_OUT/manifest.txt" <<EOF
image:$IMAGE_NAME
volumes:${VOLUMES[*]}
generated_at:$(date --utc +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[done] Full self-contained package exported successfully to: $ABS_OUT"
