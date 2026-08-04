#!/bin/bash

source "$(dirname "$0")/../common.sh"[cite: 4]

log "Installing Python ${PYTHON_VERSION}"[cite: 4]

# Ensure local wheels cache directory exists for offline-first support
mkdir -p /root/.cache/pip/wheels /root/.config/pip

# Configure pip mirror or fallback defaults
if [ -n "$PIP_MIRROR" ]; then[cite: 4]
    cat > /root/.config/pip/pip.conf << EOF
[global]
index-url = $PIP_MIRROR
trusted-host = $(echo "$PIP_MIRROR" | sed 's|https\?://||' | sed 's|/.*||')
find-links = /root/.cache/pip/wheels
EOF[cite: 4]
    echo "Using pip mirror: $PIP_MIRROR"[cite: 4]
else
    cat > /root/.config/pip/pip.conf << EOF
[global]
find-links = /root/.cache/pip/wheels
EOF
    echo "Using default PyPI with local wheels cache fallback"
fi

# Enable universe repository for python3-venv
add-apt-repository universe -y 2>/dev/null || true[cite: 4]
apt-get update -qq[cite: 4]

apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python3-pip[cite: 4]

# Install pipx via pip (not available as apt package in Ubuntu 24.04)
pip3 install --break-system-packages pipx 2>/dev/null || pip3 install pipx || true[cite: 4]

ln -sf /usr/bin/python${PYTHON_VERSION} /usr/local/bin/python[cite: 4]

python --version[cite: 4]
pip3 --version 2>/dev/null || true[cite: 4]
pipx --version 2>/dev/null || true[cite: 4]
