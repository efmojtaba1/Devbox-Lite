#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Configuring APT Mirror & Installing System Tools"

set -e

# ۱. خواندن متغیرها از فایل .env در صورت وجود
if [ -f /tmp/.env ]; then
    export $(grep -v '^#' /tmp/.env | xargs 2>/dev/null)
elif [ -f .env ]; then
    export $(grep -v '^#' .env | xargs 2>/dev/null)
fi

# ۲. منوی تعاملی برای انتخاب میرور (در صورت عدم وجود متغیر APT_MIRROR)
if [ -z "$APT_MIRROR" ]; then
    if [ -t 0 ]; then
        echo "=========================================="
        echo "  Select APT Mirror for Ultra-Fast Download:"
        echo "  1) ArvanCloud (Iran - Ultra Fast)"
        echo "  2) Shiraz University (Iran)"
        echo "  3) Ubuntu Official (Default)"
        echo "=========================================="
        read -p "Enter choice [1-3] (Default: 3): " MIRROR_CHOICE

        case $MIRROR_CHOICE in
            1) APT_MIRROR="http://mirror.arvancloud.ir/ubuntu" ;;
            2) APT_MIRROR="http://mirror.shirazu.ac.ir/ubuntu" ;;
            *) APT_MIRROR="" ;;
        esac
    fi
fi

# ۳. اعمال میرور روی سیستم‌عامل
if [ -n "$APT_MIRROR" ]; then
    log "Applying APT Mirror: $APT_MIRROR"

    # برای Ubuntu 24.04 به بالا (فرمت deb822)
    if [ -f /etc/apt/sources.list.d/ubuntu.sources ]; then
        sed -i "s|URIs: http://.*archive.ubuntu.com/ubuntu/|URIs: $APT_MIRROR|g" /etc/apt/sources.list.d/ubuntu.sources
        sed -i "s|URIs: http://security.ubuntu.com/ubuntu/|URIs: $APT_MIRROR|g" /etc/apt/sources.list.d/ubuntu.sources
    fi

    # برای فرمت‌های کلاسیک (sources.list)
    if [ -f /etc/apt/sources.list ]; then
        UBUNTU_CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME)
        cat <<EOF > /etc/apt/sources.list
deb $APT_MIRROR $UBUNTU_CODENAME main restricted universe multiverse
deb $APT_MIRROR $UBUNTU_CODENAME-updates main restricted universe multiverse
deb $APT_MIRROR $UBUNTU_CODENAME-backports main restricted universe multiverse
deb $APT_MIRROR $UBUNTU_CODENAME-security main restricted universe multiverse
EOF
    fi
else
    log "Using default Ubuntu mirrors"
fi

echo "Installing system tools..."

apt-get update

apt-get install -y --no-install-recommends \
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

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

echo "System tools installed successfully."
