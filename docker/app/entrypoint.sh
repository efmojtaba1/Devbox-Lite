#!/bin/bash

# Handle graceful shutdown
cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT

# Source bashrc for database management shortcuts
[ -f /root/.bashrc ] && source /root/.bashrc

exec "$@"
