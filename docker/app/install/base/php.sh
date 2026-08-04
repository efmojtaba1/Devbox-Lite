#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing PHP ${PHP_VERSION}"

set -e

echo "Installing PHP ${PHP_VERSION}..."

# تلاش برای افزودن مخزن Ondrej PHP با قابلیت Fallback در صورت خطای DNS/Launchpad
if ! add-apt-repository ppa:ondrej/php -y 2>/dev/null; then
    echo "⚠️  add-apt-repository failed (Launchpad API unreachable)."
    echo "🔄 Attempting direct repository configuration..."

    UBUNTU_CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME)

    # دریافت مستقیم کلید GPG و ساخت فایل repo
    mkdir -p /etc/apt/keyrings
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x14AA70EC30811E2D14002220E5267A6C262A1754" | gpg --dearmor -o /etc/apt/keyrings/ondrej-php.gpg 2>/dev/null || true

    echo "deb [signed-by=/etc/apt/keyrings/ondrej-php.gpg] http://ppa.launchpad.net/ondrej/php/ubuntu $UBUNTU_CODENAME main" > /etc/apt/sources.list.d/ondrej-php.list
fi

apt-get update

apt-get install -y --no-install-recommends \
    php${PHP_VERSION} \
    php${PHP_VERSION}-cli \
    php${PHP_VERSION}-fpm \
    php${PHP_VERSION}-common \
    php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-pgsql \
    php${PHP_VERSION}-sqlite3 \
    php${PHP_VERSION}-redis \
    php${PHP_VERSION}-curl \
    php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml \
    php${PHP_VERSION}-zip \
    php${PHP_VERSION}-gd \
    php${PHP_VERSION}-intl \
    php${PHP_VERSION}-bcmath \
    php${PHP_VERSION}-soap \
    php${PHP_VERSION}-readline \
    php${PHP_VERSION}-opcache

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

echo "PHP ${PHP_VERSION} installed successfully."

php -v
