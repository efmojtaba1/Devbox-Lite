#!/bin/bash

if [ -f "/tmp/.env" ]; then
    set -a
    source /tmp/.env
    set +a
fi

# Source bashrc for database management shortcuts
[ -f /root/.bashrc ] && source /root/.bashrc

exec "$@"
