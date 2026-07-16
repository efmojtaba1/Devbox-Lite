#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Node.js ${NODE_VERSION}"

curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt install -y --no-install-recommends nodejs

npm install -g pnpm

# Configure pnpm: use volume-mounted store and allow build scripts
cat > /root/.npmrc << 'EOF'
store-dir=/root/.local/share/pnpm/store
EOF

# pnpm 11: allow all build scripts (safe for dev container)
mkdir -p ~/.config/pnpm
echo 'dangerouslyAllowAllBuilds: true' > ~/.config/pnpm/config.yaml

node --version
npm --version
pnpm --version
