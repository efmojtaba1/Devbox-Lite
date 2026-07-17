#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Python Development Tools"

export PATH="/root/.local/bin:$PATH"

# Use pip3 to install pipx if python3-pipx is not available
if ! command -v pipx &>/dev/null; then
    pip3 install --break-system-packages pipx 2>/dev/null || pip3 install pipx 2>/dev/null || true
fi

pipx install poetry
pipx install black
pipx install ruff
pipx install pytest
pipx install jupyter --include-deps

poetry --version
black --version
ruff --version
pytest --version
jupyter --version
