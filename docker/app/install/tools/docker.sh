#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Docker CLI Tools"

apt install -y --no-install-recommends \
    docker.io \
    docker-compose-v2 \
    docker-buildx

docker --version

docker compose version

docker buildx version
