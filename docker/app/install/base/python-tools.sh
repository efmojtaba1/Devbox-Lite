#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Python Development Tools"

export PATH="/root/.local/bin:$PATH"

export PATH="/root/.local/bin:$PATH"

pipx install poetry

pipx install black

pipx install ruff

pipx install pytest

pipx install jupyter --include-deps

export PATH="/root/.local/bin:$PATH"

poetry --version
black --version
ruff --version
pytest --version
jupyter --version
