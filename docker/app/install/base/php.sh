#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing PHP ${PHP_VERSION}"

set -e

echo "Installing PHP ${PHP_VERSION}..."

add-apt-repository ppa:ondrej/php -y

apt install -y --no-install-recommends \
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

echo "PHP ${PHP_VERSION} installed successfully."

php -v
