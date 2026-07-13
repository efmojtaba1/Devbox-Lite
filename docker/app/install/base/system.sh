#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing System Tools"

set -e

echo "Installing system tools..."

apt update

apt install -y --no-install-recommends \
    git \
    curl \
    wget \
    unzip \
    zip \
    nano \
    vim \
    tree \
    htop \
    jq \
    ripgrep \
    fd-find \
    fzf \
    less \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential

echo "System tools installed successfully."
