#!/usr/bin/env bash
set -euo pipefail

# Export devbox image + named volumes for offline distribution
# Usage: ./scripts/export-offline.sh [out-dir] [image-name]

OUT_DIR="${1:-./devbox-offline}"
IMAGE_NAME="${2:-devbox-lite:latest}"

# Volumes used by compose that we want to capture
VOLUMES=(example-templates pnpm-store composer-cache devbox-deps bruno-config bruno-collections)

mkdir -p "$OUT_DIR"
ABS_OUT="$(cd "$OUT_DIR" && pwd)"

echo "[export] Saving Docker image: $IMAGE_NAME -> $ABS_OUT/image.tar"
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "[error] Image $IMAGE_NAME not found locally. Run 'docker images' to verify." >&2
  exit 1
fi
docker save -o "$ABS_OUT/image.tar" "$IMAGE_NAME"

echo "[export] Exporting volumes to $ABS_OUT"
for v in "${VOLUMES[@]}"; do
  echo "[export] Volume: $v"
  docker run --rm -v "${v}":/volume -v "$ABS_OUT":/backup alpine sh -c "cd /volume 2>/dev/null || true; tar czf /backup/vol-${v}.tar.gz -C /volume . || tar czf /backup/vol-${v}.tar.gz --files-from /dev/null"
  if [ -f "$ABS_OUT/vol-${v}.tar.gz" ]; then
    echo "  [ok] $v -> vol-${v}.tar.gz"
  else
    echo "  [warn] vol-${v}.tar.gz not created (volume may be empty)"
  fi
done

cat > "$ABS_OUT/manifest.txt" <<EOF
image:$IMAGE_NAME
volumes:${VOLUMES[*]}
generated_at:$(date --utc +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[done] Exported offline package to: $ABS_OUT"
echo "Compress for transport: tar czf devbox-offline.tar.gz -C $(dirname "$ABS_OUT") $(basename "$ABS_OUT")"
