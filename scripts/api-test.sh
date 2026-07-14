#!/bin/bash

set -euo pipefail

COLLECTIONS_DIR="/workspace/workspace/postman-collections"

show_help() {
    echo ""
    echo "========================================="
    echo "API Testing Tools"
    echo "========================================="
    echo ""
    echo "  bruno    - Open Bruno API client (GUI)"
    echo "  postman  - Open Postman (GUI via VNC)"
    echo ""
    echo "Collections directory: $COLLECTIONS_DIR"
    echo ""
}

case "${1:-help}" in
    bruno)
        /usr/local/bin/start-bruno "${@:2}"
        ;;
    postman)
        /usr/local/bin/start-postman "${@:2}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
