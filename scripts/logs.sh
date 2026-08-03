#!/bin/bash
# DevBox Lite - View logs

source "$(dirname "$0")/common.sh"

docker compose -f "$COMPOSE_FILE" logs -f
