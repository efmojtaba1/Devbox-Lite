#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Node.js ${NODE_VERSION}"

curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash -

apt install -y --no-install-recommends nodejs

npm install -g pnpm

node --version
npm --version
pnpm --version
