#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Docker CLI Tools"

# NOTE: apt-get update is done once before all tools in Dockerfile stage

apt-get install -y --no-install-recommends \
    docker.io \
    docker-compose-v2 \
    docker-buildx

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

docker --version

docker compose version

docker buildx version
