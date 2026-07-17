#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Database Clients"

apt-get install -y --no-install-recommends \
    mysql-client \
    postgresql-client \
    redis-tools

apt-get clean && rm -rf /var/lib/apt/lists/*

mysql --version

psql --version

redis-cli --version
