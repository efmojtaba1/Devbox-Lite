#!/usr/bin/env bash
set -euo pipefail

DEFAULT_INPUT="/mnt/d/devbox-image"

echo "========================================="
echo " Full Self-Contained Import"
echo "========================================="
echo "1) Use default path/directory ($DEFAULT_INPUT)"
echo "2) Enter custom path or archive (.tar.gz)"
read -e -p "Choose an option [1/2] (default: 1): " choice
choice="${choice:-1}"

if [ "$choice" == "2" ]; then
  echo "  [Tip] Example format: /mnt/d/devbox-image or /mnt/d/backup.tar.gz"
  read -e -p "  Enter path: " custom_input
  INPUT="${custom_input:-$DEFAULT_INPUT}"
else
  INPUT="$DEFAULT_INPUT"
fi

CURRENT_DIR="$(pwd)"
DEFAULT_PROJ_DEST="$CURRENT_DIR"
if [[ "$(basename "$CURRENT_DIR")" == "scripts" ]]; then
  DEFAULT_PROJ_DEST="$(dirname "$CURRENT_DIR")"
fi

echo ""
read -e -p "Enter destination path for project setup [Default: $DEFAULT_PROJ_DEST]: " target_proj
PROJECT_ROOT="${target_proj:-$DEFAULT_PROJ_DEST}"
mkdir -p "$PROJECT_ROOT"

if [ -f "$INPUT" ] && ([[ "$INPUT" == *.tar.gz ]] || [[ "$INPUT" == *.tgz ]]); then
  TMPDIR="$(mktemp -d)"
  echo "[import] Extracting package archive $INPUT -> $TMPDIR"
  tar xzf "$INPUT" -C "$TMPDIR"
  WORKDIR="$TMPDIR"
elif [ -d "$INPUT" ]; then
  WORKDIR="$(cd "$INPUT" && pwd)"
else
  echo "Error: Path or archive not found: $INPUT" >&2
  exit 1
fi

if [ -f "$WORKDIR/project-src.tar.gz" ]; then
  echo "[import] Restoring project source code to $PROJECT_ROOT..."
  tar xzf "$WORKDIR/project-src.tar.gz" -C "$PROJECT_ROOT"
  echo "  [ok] Project source code restored."
else
  echo "  [warn] project-src.tar.gz not found; skipping project files restoration."
fi

if [ -f "$WORKDIR/prebuilt.tar.gz" ]; then
  echo "[import] Restoring prebuilt directory..."
  tar xzf "$WORKDIR/prebuilt.tar.gz" -C "$PROJECT_ROOT"
  echo "  [ok] prebuilt folder restored."
else
  echo "  [warn] prebuilt.tar.gz not found in package; skipping"
fi

# ── Ensure Docker daemon is running (offline target) ──
if ! docker info >/dev/null 2>&1; then
    echo "[import] Docker daemon not running. Attempting to start..."
    if command -v service >/dev/null 2>&1; then sudo service docker start 2>/dev/null || true; fi
    if command -v systemctl >/dev/null 2>&1; then sudo systemctl start docker 2>/dev/null || true; fi
    if command -v dockerd >/dev/null 2>&1; then sudo dockerd --iptables=false --bridge=none >/dev/null 2>&1 & sleep 3; fi
    for i in $(seq 1 15); do
        if docker info >/dev/null 2>&1; then break; fi
        sleep 1
    done
fi

if [ -f "$WORKDIR/image.tar" ]; then
  echo "[import] Loading Docker image from $WORKDIR/image.tar"
  docker load -i "$WORKDIR/image.tar"
else
  echo "[warn] image.tar not found in package; skipping docker load"
fi

for f in "$WORKDIR"/vol-*.tar.gz; do
  [ -e "$f" ] || continue
  fname=$(basename "$f")
  volname=${fname#vol-}
  volname=${volname%.tar.gz}
  echo "[import] Restoring volume: $volname from $fname"
  if ! docker volume ls -q | grep -q "^$volname$"; then
    docker volume create "$volname" >/dev/null
  fi
  docker run --rm -i -v "$volname":/volume -v "$WORKDIR":/backup alpine sh -c "cd /volume || mkdir -p /volume; tar xzf /backup/$fname -C /volume || true"
done

COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"
if [ -f "$COMPOSE_FILE" ]; then
  echo "[ok] All assets restored. Starting compose: $COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" up -d
  echo "[ok] docker compose up started successfully."
else
  echo "[warn] Compose file not found at $COMPOSE_FILE. Start containers manually." >&2
fi

echo "[done] Full import finished successfully!"
