#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Python ${PYTHON_VERSION}"

# Configure pip mirror (if PIP_MIRROR build arg is provided)
if [ -n "$PIP_MIRROR" ]; then
    mkdir -p /root/.config/pip
    cat > /root/.config/pip/pip.conf << EOF
[global]
index-url = $PIP_MIRROR
trusted-host = $(echo "$PIP_MIRROR" | sed 's|https\?://||' | sed 's|/.*||')
EOF
    echo "Using pip mirror: $PIP_MIRROR"
else
    echo "Using default PyPI"
fi

# Enable universe repository for python3-venv
add-apt-repository universe -y 2>/dev/null || true
apt-get update -qq

apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip

# Install pipx via pip (not available as apt package in Ubuntu 24.04)
pip3 install --break-system-packages pipx 2>/dev/null || pip3 install pipx || true

ln -sf /usr/bin/python${PYTHON_VERSION} /usr/local/bin/python

python --version
pip3 --version 2>/dev/null || true
pipx --version 2>/dev/null || true
