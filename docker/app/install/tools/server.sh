#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Server Management Tools"

set -e

# Nginx
echo "Installing Nginx..."
apt install -y --no-install-recommends nginx

# Supervisor
echo "Installing Supervisor..."
apt install -y --no-install-recommends supervisor

# PM2
echo "Installing PM2..."
npm install -g pm2

echo "Server management tools installed successfully."

echo "Nginx:"
nginx -v

echo "Supervisor:"
supervisord --version

echo "PM2:"
pm2 --version
