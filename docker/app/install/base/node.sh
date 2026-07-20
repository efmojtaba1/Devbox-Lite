#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Node.js ${NODE_VERSION}"

curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt-get install -y --no-install-recommends nodejs

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

npm install -g pnpm

# Configure pnpm: use volume-mounted store and allow build scripts
pnpm config set store-dir /root/.local/share/pnpm/store
pnpm config set dangerouslyAllowAllBuilds true

node --version
npm --version
pnpm --version
