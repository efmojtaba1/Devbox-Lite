#!/usr/bin/env bash
set -euo pipefail

# Import an offline package produced by export-offline.sh
# Usage: ./scripts/import-offline.sh <package-dir-or-tar.gz> [compose-file]

INPUT="$1"
COMPOSE_FILE="${2:-docker/compose/docker-compose.yml}"

if [ -f "$INPUT" ] && ([[ "$INPUT" == *.tar.gz ]] || [[ "$INPUT" == *.tgz ]]); then
  TMPDIR="$(mktemp -d)"
  echo "[import] Extracting archive $INPUT -> $TMPDIR"
  tar xzf "$INPUT" -C "$TMPDIR"
  WORKDIR="$TMPDIR"
elif [ -d "$INPUT" ]; then
  WORKDIR="$(cd "$INPUT" && pwd)"
else
  echo "Usage: $0 <package-dir-or-tar.gz> [compose-file]" >&2
  exit 1
fi

if [ -f "$WORKDIR/image.tar" ]; then
  echo "[import] Loading image from $WORKDIR/image.tar"
  docker load -i "$WORKDIR/image.tar"
else
  echo "[warn] image.tar not found in package; skipping docker load"
fi

# Restore volumes found as vol-<name>.tar.gz
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

echo "[ok] Volumes restored. Starting compose (if available): $COMPOSE_FILE"
if [ -f "$COMPOSE_FILE" ]; then
  docker compose -f "$COMPOSE_FILE" up -d
  echo "[ok] docker compose up started"
else
  echo "[warn] Compose file $COMPOSE_FILE not found. Start containers manually." >&2
fi

echo "[done] Import finished. You can now run 'docker exec -it devbox-lite bash' and verify /example-data and /prebuilt contents."
