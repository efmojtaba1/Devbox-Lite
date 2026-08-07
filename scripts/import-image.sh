#!/usr/bin/env bash
set -euo pipefail

DEFAULT_INPUT="/mnt/d/devbox-image"
DEFAULT_COMPOSE="docker/compose/docker-compose.yml"

echo "========================================="
echo " Import Configuration"
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

COMPOSE_FILE="$DEFAULT_COMPOSE"

if [ -f "$INPUT" ] && ([[ "$INPUT" == *.tar.gz ]] || [[ "$INPUT" == *.tgz ]]); then
  TMPDIR="$(mktemp -d)"
  echo "[import] Extracting archive $INPUT -> $TMPDIR"
  tar xzf "$INPUT" -C "$TMPDIR"
  WORKDIR="$TMPDIR"
elif [ -d "$INPUT" ]; then
  WORKDIR="$(cd "$INPUT" && pwd)"
else
  echo "Error: Path or archive not found: $INPUT" >&2
  exit 1
fi

if [ -f "$WORKDIR/image.tar" ]; then
  echo "[import] Loading image from $WORKDIR/image.tar"
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

if [ -f "$COMPOSE_FILE" ]; then
  echo "[ok] Volumes restored. Starting compose: $COMPOSE_FILE"
  docker compose -f "$COMPOSE_FILE" up -d
  echo "[ok] docker compose up started"
else
  echo "[warn] Compose file $COMPOSE_FILE not found. Start containers manually." >&2
fi

echo "[done] Import finished."
