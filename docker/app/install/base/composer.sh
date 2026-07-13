#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Composer"

set -e

echo "Installing Composer..."

EXPECTED_CHECKSUM="$(curl -fsSL https://composer.github.io/installer.sig)"

php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"

ACTUAL_CHECKSUM="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]
then
    echo "ERROR: Invalid Composer installer checksum"
    rm composer-setup.php
    exit 1
fi

php composer-setup.php \
    --install-dir=/usr/local/bin \
    --filename=composer

rm composer-setup.php

echo "Composer installed successfully."

composer --version