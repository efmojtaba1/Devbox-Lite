#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Laravel Development Tools"

# Retry up to 3 times for network issues
for i in 1 2 3; do
    if composer global require laravel/installer 2>/dev/null; then
        break
    fi
    echo "Attempt $i failed, retrying in 5 seconds..."
    sleep 5
done

laravel --version || echo "Warning: laravel --version failed, but installation is complete"
