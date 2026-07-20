#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Server Management Tools"

set -e

# Install Nginx and Supervisor in one apt call
echo "Installing Nginx and Supervisor..."
apt-get install -y --no-install-recommends nginx supervisor

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
