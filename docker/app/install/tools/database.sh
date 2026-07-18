#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Database Clients"

apt-get update -qq

apt-get install -y --no-install-recommends \
    default-mysql-client \
    postgresql-client \
    redis-tools 2>/dev/null || \
apt-get install -y --no-install-recommends \
    mysql-client \
    postgresql-client \
    redis 2>/dev/null || true

apt-get clean && rm -rf /var/lib/apt/lists/*

mysql --version 2>/dev/null || echo "MySQL client not installed"
psql --version 2>/dev/null || echo "PostgreSQL client not installed"
redis-cli --version 2>/dev/null || echo "Redis CLI not installed"
