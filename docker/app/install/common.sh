#!/bin/bash

set -euo pipefail

CONFIG_FILE="/tmp/.env"

if [ -f "$CONFIG_FILE" ]; then
    set -a
    source "$CONFIG_FILE"
    set +a
fi

log() {

    echo
    echo "========================================="
    echo "$1"
    echo "========================================="

}

info() {
    echo "[INFO] $1"
}

success() {
    echo "[OK] $1"
}

warning() {
    echo "[WARN] $1"
}

error() {
    echo "[ERROR] $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}
