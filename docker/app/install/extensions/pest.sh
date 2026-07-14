#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Pest PHP & PHPUnit"

echo "Creating test directory for Pest..."
mkdir -p /root/.config/composer/tests

echo "Installing Pest PHP (includes PHPUnit)..."
composer global config --no-plugins allow-plugins.pestphp/pest-plugin true 2>/dev/null || true

# Retry up to 3 times for network issues
for i in 1 2 3; do
    if composer global require pestphp/pest pestphp/pest-plugin-laravel 2>/dev/null; then
        break
    fi
    echo "Attempt $i failed, retrying in 5 seconds..."
    sleep 5
done

# Find pest binary and symlink to /usr/local/bin
COMPOSER_BIN_DIR=$(composer global config bin-dir 2>/dev/null | tr -d ' ')
if [ -f "${COMPOSER_BIN_DIR}/pest" ]; then
    ln -sf "${COMPOSER_BIN_DIR}/pest" /usr/local/bin/pest
elif [ -f "/root/.config/composer/vendor/bin/pest" ]; then
    ln -sf "/root/.config/composer/vendor/bin/pest" /usr/local/bin/pest
fi

if command -v pest &>/dev/null; then
    echo "Pest PHP installed successfully."
    pest --version
else
    echo "Warning: Pest installation failed (network issue). You can install it later with:"
    echo "  composer global require pestphp/pest pestphp/pest-plugin-laravel"
fi
