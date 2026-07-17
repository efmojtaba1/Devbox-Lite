#!/bin/bash
# DevBox Lite - All-in-one command
# Usage: devbox <command> [args]

source "$(dirname "$0")/common.sh"

case "${1:-help}" in
    up|start)
        Show-Header "Starting DevBox Lite"
        docker compose -f "$COMPOSE_FILE" up -d
        Test-Result "DevBox Lite started. Use 'devbox shell' to enter." "Failed to start DevBox Lite."
        ;;
    down|stop)
        Show-Header "Stopping DevBox Lite"
        # Stop database containers first
        db_containers=$(docker ps -a --format '{{.Names}}' | grep -E '^devbox-' | grep -v "^${CONTAINER_NAME}$" || true)
        if [ -n "$db_containers" ]; then
            for container in $db_containers; do
                echo "  Stopping $container..."
                docker stop "$container" 2>/dev/null
                docker rm "$container" 2>/dev/null
            done
        fi
        docker compose -f "$COMPOSE_FILE" down
        Test-Result "DevBox Lite stopped." "Failed to stop DevBox Lite."
        ;;
    shell|sh)
        docker exec -it "$CONTAINER_NAME" bash
        ;;
    build)
        Show-Header "Building DevBox"
        docker compose -f "$COMPOSE_FILE" build
        Test-Result "Build complete." "Build failed."
        ;;
    rebuild)
        Show-Header "Rebuilding DevBox (no cache)"
        docker compose -f "$COMPOSE_FILE" build --no-cache
        Test-Result "Rebuild complete." "Rebuild failed."
        ;;
    logs|log)
        docker compose -f "$COMPOSE_FILE" logs -f
        ;;
    restart)
        Show-Header "Restarting DevBox Lite"
        docker compose -f "$COMPOSE_FILE" restart
        Test-Result "DevBox Lite restarted." "Failed to restart DevBox Lite."
        ;;
    status|st)
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    clean)
        Show-Header "Cleaning DevBox"
        # Stop and remove database containers
        db_containers=$(docker ps -a --format '{{.Names}}' | grep -E '^devbox-' | grep -v "^${CONTAINER_NAME}$" || true)
        if [ -n "$db_containers" ]; then
            for container in $db_containers; do
                docker stop "$container" 2>/dev/null
                docker rm "$container" 2>/dev/null
            done
        fi
        docker compose -f "$COMPOSE_FILE" down 2>/dev/null
        docker rmi "$IMAGE_NAME" 2>/dev/null
        Show-Success "DevBox cleaned."
        ;;
    setup|deps)
        docker exec -it "$CONTAINER_NAME" bash -c "/workspace/scripts/setup-deps.sh $2"
        ;;
    run)
        shift
        docker exec -it "$CONTAINER_NAME" bash -c "$*"
        ;;
    help|--help|-h|"")
        echo "DevBox Lite - Usage: devbox <command>"
        echo ""
        echo "Commands:"
        echo "  up/start      Start the container"
        echo "  down/stop     Stop the container and database sidecars"
        echo "  shell/sh      Open container shell"
        echo "  build         Build the image"
        echo "  rebuild       Rebuild image (no cache)"
        echo "  logs/log      View container logs"
        echo "  restart       Restart the container"
        echo "  status/st     Check container status"
        echo "  clean         Remove image and containers"
        echo "  setup/deps    Setup database dependencies"
        echo "  run <cmd>     Run command inside container"
        echo "  help          Show this help message"
        ;;
    *)
        Show-Error "Unknown command: $1"
        echo "Run 'devbox help' for usage."
        exit 1
        ;;
esac
