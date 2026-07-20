#!/bin/bash
# DevBox Lite - All-in-one command
# Usage: devbox <command> [args]

source "$(dirname "$0")/common.sh"

case "${1:-help}" in
    up|start)
        Show-Header "Starting DevBox Lite"
        docker compose -f "$COMPOSE_FILE" up -d
        Test-Result "DevBox Lite started. Use 'devbox shell' to enter." "Failed to start DevBox Lite."
        # Check if example templates are initialized
        sleep 3
        if ! docker exec "$CONTAINER_NAME" bash -c "test -d /example-data/laravel" 2>/dev/null; then
            echo "Example templates not found. Initializing..."
            docker exec "$CONTAINER_NAME" bash -c "/scripts/init-example.sh" 2>/dev/null || \
                echo "[warn] init-example failed. Run 'devbox init-example' manually."
        fi
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
    down-v)
        Show-Header "Stopping DevBox Lite (with volumes)"
        # Stop database containers first
        db_containers=$(docker ps -a --format '{{.Names}}' | grep -E '^devbox-' | grep -v "^${CONTAINER_NAME}$" || true)
        if [ -n "$db_containers" ]; then
            for container in $db_containers; do
                echo "  Stopping $container..."
                docker stop "$container" 2>/dev/null
                docker rm "$container" 2>/dev/null
            done
        fi
        docker compose -f "$COMPOSE_FILE" down -v
        Test-Result "DevBox Lite stopped and volumes removed." "Failed to stop DevBox Lite."
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
        docker exec -it "$CONTAINER_NAME" bash -c "/scripts/setup-deps.sh $2"
        ;;
    run)
        shift
        docker exec -it "$CONTAINER_NAME" bash -c "$*"
        ;;
    new-project|new)
        docker exec -it "$CONTAINER_NAME" bash -c "/workspace/scripts/new-project.sh ${2:-} ${3:-}"
        ;;
    setup-example|check-example)
        Show-Header "Verifying example templates"
        docker exec -it "$CONTAINER_NAME" bash -c "/scripts/setup-example.sh"
        ;;
    init-example)
        Show-Header "Initializing example templates (one-time)"
        docker exec -it "$CONTAINER_NAME" bash -c "/scripts/init-example.sh"
        ;;
    refresh-example)
        Show-Header "Refreshing example templates"
        bash "$SCRIPT_DIR/refresh-example.sh" "${2:-all}"
        ;;
    help|--help|-h|"")
        echo "DevBox Lite - Usage: devbox <command>"
        echo ""
        echo "Commands:"
        echo "  up/start      Start the container"
        echo "  down/stop     Stop the container and database sidecars"
        echo "  down-v        Stop container and remove all volumes"
        echo "  shell/sh      Open container shell"
        echo "  build         Build the image"
        echo "  rebuild       Rebuild image (no cache)"
        echo "  logs/log      View container logs"
        echo "  restart       Restart the container"
        echo "  status/st     Check container status"
        echo "  clean         Remove image and containers"
        echo "  new-project   Create new project from template (offline-first)"
        echo "  setup-example Verify example templates"
        echo "  refresh-example Update examples to latest framework versions"
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
