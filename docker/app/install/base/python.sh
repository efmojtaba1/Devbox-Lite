#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Python ${PYTHON_VERSION}"

apt install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip \
    pipx

ln -sf /usr/bin/python${PYTHON_VERSION} /usr/local/bin/python

python --version
pip --version
pipx --version
