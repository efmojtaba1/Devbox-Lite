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
DOCKER_DESKTOP_VERSION="4.86.0"
DOCKER_DESKTOP_URL="https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe?utm_source=docker&utm_medium=webreferral&utm_campaign=docs-driven-download-win-amd64"
echo "========================================="
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
OFFLINE_DEPS_DIR="$ABS_OUT/offline-deps"

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
    python3 - "$WSL_RELEASE_JSON" <<'PY'
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
PY
  )"

  echo "  [info] WSL MSI URL:"
  echo "         $WSL_ASSET_URL"

  download_resumable "$WSL_ASSET_URL" "$WSL_MSI" "WSL x64 MSI"
fi

WSL_MSI_SHA256="$(sha256sum "$WSL_MSI" | awk '{print $1}')"
echo "  [ok] WSL MSI SHA256: $WSL_MSI_SHA256"

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

echo "  [ok] Ubuntu 24.04 WSL SHA256 verified."

# ------------------------------------------------------------
# Docker Desktop installer
# ------------------------------------------------------------
echo ""
echo "[export] Preparing Docker Desktop Windows x64 installer..."

DOCKER_INSTALLER="$OFFLINE_DEPS_DIR/Docker Desktop Installer.exe"
DOCKER_INSTALLER_SHA_FILE="$OFFLINE_DEPS_DIR/docker-desktop.sha256"

if [ -s "$DOCKER_INSTALLER" ] && [ -s "$DOCKER_INSTALLER_SHA_FILE" ]; then
  CACHED_DOCKER_SHA256="$(awk 'NF {print $1; exit}' "$DOCKER_INSTALLER_SHA_FILE")"
  CURRENT_DOCKER_SHA256="$(sha256sum "$DOCKER_INSTALLER" | awk '{print $1}')"

  if [ "$CURRENT_DOCKER_SHA256" = "$CACHED_DOCKER_SHA256" ]; then
    echo "  [ok] Existing Docker Desktop installer verified."
  else
    echo "  [warn] Existing Docker Desktop installer checksum mismatch."
    echo "  [info] Removing invalid cached installer."
    rm -f "$DOCKER_INSTALLER"
  fi
fi

download_resumable   "$DOCKER_DESKTOP_URL"   "$DOCKER_INSTALLER"   "Docker Desktop $DOCKER_DESKTOP_VERSION"

if [ ! -s "$DOCKER_INSTALLER" ]; then
  echo "[error] Docker Desktop installer is missing or empty."
  exit 1
fi

DOCKER_INSTALLER_SHA256="$(sha256sum "$DOCKER_INSTALLER" | awk '{print $1}')"

printf '%s  %s\n'   "$DOCKER_INSTALLER_SHA256"   "$(basename "$DOCKER_INSTALLER")"   > "$DOCKER_INSTALLER_SHA_FILE"

echo "  [ok] Docker Desktop installer SHA256: $DOCKER_INSTALLER_SHA256"

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
docker save -o "$ABS_OUT/image.tar" "$IMAGE_NAME"

if [ ! -s "$ABS_OUT/image.tar" ]; then
  echo "[error] image.tar was not created correctly."
  exit 1
fi

IMAGE_SHA256="$(sha256sum "$ABS_OUT/image.tar" | awk '{print $1}')"
echo "  [ok] image.tar"
echo "       SHA256: $IMAGE_SHA256"

# ------------------------------------------------------------
# Docker volumes
# ------------------------------------------------------------
echo ""
echo "[export] Exporting Docker volumes..."

declare -A ACTUAL_VOLUMES

for logical_volume in "${VOLUMES[@]}"; do
  actual_volume="$(resolve_volume "$logical_volume" || true)"

  if [ -z "$actual_volume" ]; then
    echo "[error] Docker volume not found: $logical_volume"
    echo "        Start DevBox Lite once and make sure all volumes exist."
    exit 1
  fi

  ACTUAL_VOLUMES["$logical_volume"]="$actual_volume"

  archive="$ABS_OUT/vol-${logical_volume}.tar.gz"
  rm -f "$archive"

  docker run --rm \
    --mount "type=volume,source=${actual_volume},target=/volume,readonly" \
    --mount "type=bind,source=${ABS_OUT},target=/backup" \
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
  echo "       SHA256: $sha"
done

# ------------------------------------------------------------
# Project source
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
  -C "$PROJECT_ROOT" .

if [ ! -s "$ABS_OUT/project-src.tar.gz" ]; then
  echo "[error] project-src.tar.gz was not created."
  exit 1
fi

PROJECT_SHA256="$(sha256sum "$ABS_OUT/project-src.tar.gz" | awk '{print $1}')"
echo "  [ok] project-src.tar.gz"
echo "       SHA256: $PROJECT_SHA256"

# ------------------------------------------------------------
# Prebuilt
# ------------------------------------------------------------
if [ -d "$PROJECT_ROOT/prebuilt" ]; then
  echo ""
  echo "[export] Packaging prebuilt directory..."
  rm -f "$ABS_OUT/prebuilt.tar.gz"
  tar czf "$ABS_OUT/prebuilt.tar.gz" -C "$PROJECT_ROOT" prebuilt

  PREBUILT_SHA256="$(sha256sum "$ABS_OUT/prebuilt.tar.gz" | awk '{print $1}')"
  echo "  [ok] prebuilt.tar.gz"
  echo "       SHA256: $PREBUILT_SHA256"
else
  rm -f "$ABS_OUT/prebuilt.tar.gz"
  echo ""
  echo "[info] prebuilt directory not found; skipping."
fi

# ------------------------------------------------------------
# Copy installer scripts
# ------------------------------------------------------------
echo ""
echo "[export] Copying offline installer scripts..."

rm -rf "$ABS_OUT/scripts"
mkdir -p "$ABS_OUT/scripts"

cp "$PROJECT_ROOT/scripts/import.ps1" "$ABS_OUT/scripts/import.ps1"

if [ ! -f "$PROJECT_ROOT/scripts/import.ps1" ]; then
  echo "[error] scripts/import.ps1 not found in project."
  exit 1
fi

# Generate setup-offline.bat below so the exported package always
# contains the exact orchestrator matching this export format.
cat > "$ABS_OUT/setup-offline.bat" <<'BAT'
@echo off
setlocal EnableExtensions DisableDelayedExpansion

title DevBox Lite - Offline Installer
color 0A

set "PACKAGE_ROOT=%~dp0"
set "STATE_DIR=%ProgramData%\DevBoxLite"
set "STATE_FILE=%STATE_DIR%\offline-setup.state"
set "TASK_NAME=DevBoxLite-OfflineSetup"

if /I "%~1"=="/resume" goto :resume

echo ============================================================
echo   DevBox Lite - Offline Installer
echo   WSL2 + Ubuntu 24.04 + Docker Desktop + DevBox
echo ============================================================
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [ERROR] Administrator privileges are required.
    echo         Right-click setup-offline.bat and choose:
    echo         Run as administrator
    echo.
    pause
    exit /b 1
)

if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1

set "DEST_PATH="
set /p "DEST_PATH=Enter destination path for project setup [Default: D:\devbox-project]: "
if not defined DEST_PATH set "DEST_PATH=D:\devbox-project"

> "%STATE_FILE%" echo DEST_PATH=%DEST_PATH%
>>"%STATE_FILE%" echo STAGE=START

goto :main

:resume
echo ============================================================
echo   DevBox Lite - Resuming Offline Installation
echo ============================================================
echo.

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo [ERROR] Administrator privileges are required.
    pause
    exit /b 1
)

if not exist "%STATE_FILE%" (
    echo [ERROR] Resume state was not found:
    echo         %STATE_FILE%
    echo.
    echo Run setup-offline.bat normally instead.
    pause
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%STATE_FILE%") do (
    if /I "%%A"=="DEST_PATH" set "DEST_PATH=%%B"
    if /I "%%A"=="STAGE" set "STAGE=%%B"
)

if not defined DEST_PATH set "DEST_PATH=D:\devbox-project"

:main

call :validate_package
echo [1/6] Validating Windows and offline package...

for /f "delims=" %%B in ('powershell.exe -NoProfile -Command "$os=Get-CimInstance Win32_OperatingSystem; $b=[int]$os.BuildNumber; $c=$os.Caption; if((($c -match 'Windows 10') -and ($b -ge 19045)) -or (($c -match 'Windows 11') -and ($b -ge 22631))){'OK'}else{'FAIL:Unsupported Windows build '+$c+' build '+$b}"') do set "WIN_CHECK=%%B"

if /I not "%WIN_CHECK%"=="OK" (
    echo [ERROR] Unsupported Windows version.
    echo         Docker Desktop currently requires at least:
    echo         Windows 10 22H2 build 19045, or
    echo         Windows 11 23H2 build 22631.
    echo         Detected: %WIN_CHECK%
    exit /b 1
)

for /f "delims=" %%B in ('powershell.exe -NoProfile -Command "if([Environment]::Is64BitOperatingSystem){'OK'}else{'FAIL'}"') do set "ARCH_CHECK=%%B"

if /I not "%ARCH_CHECK%"=="OK" (
    echo [ERROR] A 64-bit Windows installation is required.
    exit /b 1
)

for /f "delims=" %%B in ('powershell.exe -NoProfile -Command "$r=(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory; if($r -ge 8GB){'OK'}else{'FAIL:Less than 8GB RAM'}"') do set "RAM_CHECK=%%B"

if /I not "%RAM_CHECK%"=="OK" (
    echo [ERROR] At least 8 GB of RAM is required for the target Docker Desktop setup.
    echo         Detected: %RAM_CHECK%
    exit /b 1
)

for /f "delims=" %%B in ('powershell.exe -NoProfile -Command "$v=(Get-CimInstance Win32_Processor | Select-Object -First 1 -ExpandProperty VirtualizationFirmwareEnabled -ErrorAction SilentlyContinue); if($v -eq $false){'FAIL:Virtualization disabled in firmware'}else{'OK'}"') do set "VIRT_CHECK=%%B"

if /I not "%VIRT_CHECK%"=="OK" (
    echo [ERROR] Hardware virtualization is disabled in BIOS/UEFI.
    echo         Enable Intel VT-x / AMD-V (SVM) and run setup again.
    exit /b 1
)

set "WSL_MSI="
for %%F in ("%PACKAGE_ROOT%offline-deps\wsl*.msi") do (
    if exist "%%~fF" set "WSL_MSI=%%~fF"
)

if not defined WSL_MSI (
    echo [ERROR] WSL MSI not found in offline-deps.
    exit /b 1
)

if not exist "%PACKAGE_ROOT%offline-deps\ubuntu-24.04.4-wsl-amd64.wsl" (
    echo [ERROR] Ubuntu 24.04 WSL package not found.
    exit /b 1
)

if not exist "%PACKAGE_ROOT%offline-deps\Docker Desktop Installer.exe" (
    echo [ERROR] Docker Desktop installer not found.
    exit /b 1
)

if not exist "%PACKAGE_ROOT%image.tar" (
    echo [ERROR] image.tar not found.
    exit /b 1
)

if not exist "%PACKAGE_ROOT%scripts\import.ps1" (
    echo [ERROR] scripts/import.ps1 not found.
    exit /b 1
)

echo   [OK] Windows prerequisites.
echo   [OK] Required offline packages found.
exit /b 0

:enable_wsl_features
echo.
echo [2/6] Checking Windows WSL2 components...

dism.exe /online /get-featureinfo /featurename:Microsoft-Windows-Subsystem-Linux > "%TEMP%\devbox-wsl-feature.txt" 2>&1
findstr /I /C:"State : Enabled" "%TEMP%\devbox-wsl-feature.txt" >nul
set "WSL_FEATURE_ENABLED=%errorlevel%"

dism.exe /online /get-featureinfo /featurename:VirtualMachinePlatform > "%TEMP%\devbox-vmp-feature.txt" 2>&1
findstr /I /C:"State : Enabled" "%TEMP%\devbox-vmp-feature.txt" >nul
set "VMP_FEATURE_ENABLED=%errorlevel%"

if "%WSL_FEATURE_ENABLED%"=="0" if "%VMP_FEATURE_ENABLED%"=="0" (
    echo   [OK] WSL and Virtual Machine Platform are already enabled.
    exit /b 0
)

echo   Enabling Windows Subsystem for Linux...
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
if errorlevel 1 (
    echo [ERROR] Failed to enable Windows Subsystem for Linux.
    exit /b 1
)

echo   Enabling Virtual Machine Platform...
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
if errorlevel 1 (
    echo [ERROR] Failed to enable Virtual Machine Platform.
    exit /b 1
)

> "%STATE_FILE%" echo DEST_PATH=%DEST_PATH%
>>"%STATE_FILE%" echo STAGE=FEATURES_ENABLED

echo.
echo   A Windows restart is required before WSL can be installed.
echo   The installer will resume automatically after login.
echo.

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /create /tn "%TASK_NAME%" /sc onlogon /rl HIGHEST /tr "\"%~f0\" /resume" /f >nul 2>&1

if errorlevel 1 (
    echo [ERROR] Could not create automatic resume task.
    echo         Please run setup-offline.bat again after restart.
    exit /b 1
)

shutdown /r /t 10 /c "DevBox Lite Offline Setup requires a restart to continue WSL2 installation."
exit /b 0

:install_wsl
echo.
echo [3/6] Installing WSL from the offline MSI...

where wsl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] wsl.exe is still unavailable after enabling WSL.
    echo         A restart may be required. Run setup-offline.bat /resume after restart.
    exit /b 1
)

wsl.exe --version >nul 2>&1
if errorlevel 1 (
    echo   Installing WSL MSI...
    msiexec.exe /i "%WSL_MSI%" /passive /norestart
    if errorlevel 1 (
        echo [ERROR] WSL MSI installation failed.
        exit /b 1
    )
)

wsl.exe --set-default-version 2 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Could not set WSL default version to 2.
    exit /b 1
)

echo   [OK] WSL2 is installed and default version is 2.
exit /b 0

:install_ubuntu
echo.
echo [4/6] Installing Ubuntu 24.04 offline...

set "UBUNTU_WSL=%PACKAGE_ROOT%offline-deps\ubuntu-24.04.4-wsl-amd64.wsl"

wsl.exe -l -q 2>nul | findstr /I /X "Ubuntu-24.04" >nul
if "%errorlevel%"=="0" (
    echo   [OK] Ubuntu-24.04 is already installed.
    exit /b 0
)

echo   Installing Ubuntu from:
echo     %UBUNTU_WSL%

wsl.exe --install --from-file "%UBUNTU_WSL%" --no-launch
if errorlevel 1 (
    echo [ERROR] Failed to install Ubuntu 24.04 from the offline .wsl file.
    exit /b 1
)

wsl.exe --set-version Ubuntu-24.04 2 >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Ubuntu-24.04 could not be set to WSL2.
    exit /b 1
)

wsl.exe --set-default Ubuntu-24.04 >nul 2>&1

echo   [OK] Ubuntu-24.04 installed as WSL2 and set as default distro.
exit /b 0

:install_docker
echo.
echo [5/6] Installing Docker Desktop offline...

set "DOCKER_EXE=%PACKAGE_ROOT%offline-deps\Docker Desktop Installer.exe"

if exist "%ProgramFiles%\Docker\Docker\Docker Desktop.exe" (
    echo   [OK] Docker Desktop is already installed.
    goto :docker_start
)

echo   Installing Docker Desktop for all users...
start /wait "" "%DOCKER_EXE%" install --accept-license --backend=wsl-2 --no-windows-containers
if errorlevel 1 (
    echo [ERROR] Docker Desktop installation failed.
    exit /b 1
)

:docker_start
echo   Starting Docker Desktop...

set "DOCKER_DESKTOP_EXE=%ProgramFiles%\Docker\Docker\Docker Desktop.exe"

if not exist "%DOCKER_DESKTOP_EXE%" (
    echo [ERROR] Docker Desktop executable was not found.
    exit /b 1
)

start "" "%DOCKER_DESKTOP_EXE%"

echo   Waiting for Docker Engine...
set /a WAIT_COUNT=0

:docker_wait
set /a WAIT_COUNT+=1
timeout /t 5 /nobreak >nul

docker version >nul 2>&1
if not errorlevel 1 (
    echo   [OK] Docker Engine is ready.
    exit /b 0
)

if %WAIT_COUNT% GEQ 60 (
    echo [ERROR] Docker Engine did not become ready within 5 minutes.
    echo         Open Docker Desktop and check its status.
    exit /b 1
)

goto :docker_wait

:restore_devbox
echo.
echo [6/6] Restoring DevBox Lite to:
echo        %DEST_PATH%

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PACKAGE_ROOT%scripts\import.ps1" ^
    -InputPath "%PACKAGE_ROOT%" ^
    -TargetProj "%DEST_PATH%"

if errorlevel 1 (
    echo [ERROR] DevBox restore failed.
    exit /b 1
)

exit /b 0

:verify
echo.
echo [verify] Checking final installation...

where wsl.exe >nul 2>&1
if errorlevel 1 (
    echo [ERROR] wsl.exe is not available.
    exit /b 1
)

wsl.exe -l -v 2>nul | findstr /I "Ubuntu-24.04" >nul
if errorlevel 1 (
    echo [ERROR] Ubuntu-24.04 is not registered.
    exit /b 1
)

docker version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker Engine is not available.
    exit /b 1
)

if not exist "%DEST_PATH%\docker\compose\docker-compose.yml" (
    echo [ERROR] DevBox Compose file was not restored.
    exit /b 1
)

echo   [OK] WSL2
echo   [OK] Ubuntu 24.04
echo   [OK] Docker Desktop / Docker Engine
echo   [OK] DevBox project files
exit /b 0

:fail
echo.
echo ============================================================
echo   DevBox Lite Offline Installation FAILED
echo ============================================================
echo.
echo State file:
echo   %STATE_FILE%
echo.
echo The installer stopped at the failed step.
echo Fix the reported problem and run setup-offline.bat again.
echo.
pause
exit /b 1
BAT


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
  if [ -f "$ABS_OUT/prebuilt.tar.gz" ]; then
    echo "prebuilt.tar.gz:$PREBUILT_SHA256"
  fi
  for logical_volume in "${VOLUMES[@]}"; do
    archive="$ABS_OUT/vol-${logical_volume}.tar.gz"
    echo "$(basename "$archive"):$(sha256sum "$archive" | awk '{print $1}')"
  done
} > "$ABS_OUT/manifest.txt"

echo "  [ok] manifest.txt"

# ------------------------------------------------------------
# Final package verification
# ------------------------------------------------------------
echo ""
echo "[export] Final package verification..."

required_files=(
  "$ABS_OUT/setup-offline.bat"
  "$ABS_OUT/manifest.txt"
  "$ABS_OUT/image.tar"
  "$ABS_OUT/project-src.tar.gz"
  "$ABS_OUT/offline-deps/$(basename "$WSL_MSI")"
  "$ABS_OUT/offline-deps/ubuntu-24.04.4-wsl-amd64.wsl"
  "$ABS_OUT/offline-deps/Docker Desktop Installer.exe"
  "$ABS_OUT/offline-deps/docker-desktop.sha256"
  "$ABS_OUT/scripts/import.ps1"
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
