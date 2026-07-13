#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Database Clients"

apt install -y --no-install-recommends \
    mysql-client \
    postgresql-client \
    redis-tools

mysql --version

psql --version

redis-cli --version
