#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OUT_DIR="/mnt/d/devbox-project"
DEFAULT_IMAGE="devbox-lite:latest"

echo "========================================="
echo " Full Project & Docker Export (Offline Ready)"
echo "========================================="

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"

if [ ! -f "$COMPOSE_FILE" ]; then
  echo "[error] docker-compose.yml not found:"
  echo "        $COMPOSE_FILE"
  exit 1
fi

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
      --filter "label=com.docker.compose.volume=${logical_name}" \
      | head -n 1
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
    exit 1
  fi

  ACTUAL_VOLUMES["$logical_volume"]="$ACTUAL_VOLUME"
  echo "  [info] Actual Docker volume: $ACTUAL_VOLUME"

  ARCHIVE="$ABS_OUT/vol-${logical_volume}.tar.gz"
  rm -f "$ARCHIVE"

  docker run --rm \
    --mount "type=volume,source=${ACTUAL_VOLUME},target=/volume,readonly" \
    --mount "type=bind,source=${ABS_OUT},target=/backup" \
    "$IMAGE_NAME" \
    sh -c "tar czf /backup/vol-${logical_volume}.tar.gz -C /volume ."

  if [ ! -f "$ARCHIVE" ] || [ ! -s "$ARCHIVE" ]; then
    echo "  [error] Archive is missing or empty: $ARCHIVE"
    exit 1
  fi

  ARCHIVE_BYTES="$(stat -c '%s' "$ARCHIVE")"
  ARCHIVE_SIZE="$(du -h "$ARCHIVE" | cut -f1)"

  if ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
    echo "  [error] Generated archive is invalid: $ARCHIVE"
    exit 1
  fi

  echo "  [ok] $logical_volume -> vol-${logical_volume}.tar.gz (${ARCHIVE_SIZE}, ${ARCHIVE_BYTES} bytes)"

done

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

echo "  [ok] project source code -> project-src.tar.gz"

rm -rf "$ABS_OUT/scripts"
mkdir -p "$ABS_OUT/scripts"
cp -r "$PROJECT_ROOT/scripts/"* "$ABS_OUT/scripts/"
echo "  [ok] project scripts copied."

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

echo ""
echo "========================================="
echo "[done] Full self-contained package exported successfully."
echo "========================================="
