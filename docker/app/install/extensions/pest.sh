#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Pest PHP & PHPUnit"

echo "Creating test directory for Pest..."
mkdir -p /root/.config/composer/tests

echo "Installing Pest PHP (includes PHPUnit)..."
composer global config --no-plugins allow-plugins.pestphp/pest-plugin true 2>/dev/null || true
composer global require pestphp/pest pestphp/pest-plugin-laravel

# Find pest binary and symlink to /usr/local/bin
COMPOSER_BIN_DIR=$(composer global config bin-dir 2>/dev/null | tr -d ' ')
if [ -f "${COMPOSER_BIN_DIR}/pest" ]; then
    ln -sf "${COMPOSER_BIN_DIR}/pest" /usr/local/bin/pest
elif [ -f "/root/.config/composer/vendor/bin/pest" ]; then
    ln -sf "/root/.config/composer/vendor/bin/pest" /usr/local/bin/pest
fi

echo "Pest PHP installed successfully."
pest --version || echo "Warning: pest --version failed, but installation is complete"
