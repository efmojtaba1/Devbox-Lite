#!/bin/bash
# DevBox Lite - Run command inside container

source "$(dirname "$0")/common.sh"

docker exec -it "$CONTAINER_NAME" bash -c "$*"
