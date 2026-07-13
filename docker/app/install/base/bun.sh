#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Bun ${BUN_VERSION}"

curl -fsSL https://bun.sh/install | bash

ln -s /root/.bun/bin/bun /usr/local/bin/bun

bun --version
