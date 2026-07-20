#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Database Clients"

# NOTE: apt-get update is done once before all tools in Dockerfile stage

apt-get install -y --no-install-recommends \
    default-mysql-client \
    postgresql-client \
    redis-tools 2>/dev/null || \
apt-get install -y --no-install-recommends \
    mysql-client \
    postgresql-client \
    redis 2>/dev/null || true

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

mysql --version 2>/dev/null || echo "MySQL client not installed"
psql --version 2>/dev/null || echo "PostgreSQL client not installed"
redis-cli --version 2>/dev/null || echo "Redis CLI not installed"
