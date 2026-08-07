#!/usr/bin/env bash
set -euo pipefail

DEFAULT_OUT_DIR="/mnt/d/devbox-image"
DEFAULT_IMAGE="devbox-lite:latest"

echo "========================================="
echo " Full Project & Docker Export"
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

cat > "$ABS_OUT/manifest.txt" <<EOF
image:$IMAGE_NAME
volumes:${VOLUMES[*]}
generated_at:$(date --utc +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[done] Full self-contained package exported successfully to: $ABS_OUT"
