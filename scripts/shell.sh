#!/bin/bash
# DevBox Lite - Open container shell

source "$(dirname "$0")/common.sh"

docker exec -it "$CONTAINER_NAME" bash
