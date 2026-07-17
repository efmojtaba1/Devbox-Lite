#!/bin/bash
# DevBox Lite - Shared functions for Bash scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"
CONTAINER_NAME="devbox-lite"
IMAGE_NAME="devbox-lite"

# Load .env file if exists
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        export "$key=$value"
    done < "$ENV_FILE"
fi

Show-Header() {
    local title="$1"
    echo ""
    echo "========================================="
    echo "$title"
    echo "========================================="
    echo ""
}

Show-Success() {
    local message="$1"
    echo ""
    echo "✓ $message"
}

Show-Error() {
    local message="$1"
    echo ""
    echo "✗ $message"
}

Test-Result() {
    local success_message="$1"
    local error_message="$2"

    if [ $? -eq 0 ]; then
        Show-Success "$success_message"
    else
        Show-Error "$error_message"
        exit 1
    fi
}
