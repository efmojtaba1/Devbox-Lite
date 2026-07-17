#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Laravel Development Tools"

# Retry up to 3 times for network issues
installed=false
for i in 1 2 3; do
    if composer global require laravel/installer 2>/dev/null; then
        installed=true
        break
    fi
    echo "Attempt $i failed, retrying in 5 seconds..."
    sleep 5
done

if [ "$installed" = false ]; then
    echo "ERROR: Laravel installer installation failed after 3 attempts."
    exit 1
fi

laravel --version
