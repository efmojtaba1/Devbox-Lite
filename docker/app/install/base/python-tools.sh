#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Python Development Tools"

export PATH="/root/.local/bin:$PATH"

# Retry helper for flaky network
retry() {
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        if "$@"; then
            return 0
        fi
        echo "Attempt $attempt failed, retrying in 5s..."
        sleep 5
        attempt=$((attempt + 1))
    done
    echo "All $max_attempts attempts failed for: $*"
    return 1
}

# Use pip3 to install pipx if python3-pipx is not available
if ! command -v pipx &>/dev/null; then
    pip3 install --break-system-packages pipx 2>/dev/null || pip3 install pipx 2>/dev/null || true
fi

retry pipx install poetry
retry pipx install black
retry pipx install ruff
retry pipx install pytest
# jupyter is a metapackage with no app entry point — install via pip instead of pipx
pip3 install --break-system-packages jupyter 2>/dev/null || pip3 install jupyter || true

poetry --version
black --version
ruff --version
pytest --version
jupyter --version 2>/dev/null || echo "Jupyter installed via pip"
