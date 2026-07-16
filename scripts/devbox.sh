#!/bin/bash
# DevBox Lite - All-in-one command
# Usage: devbox <command> [args]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/compose/docker-compose.yml"

case "${1:-help}" in
    up|start)
        echo "Starting DevBox Lite..."
        docker compose -f "$COMPOSE_FILE" up -d
        echo "✓ DevBox Lite started. Use 'devbox shell' to enter."
        ;;
    down|stop)
        echo "Stopping DevBox Lite..."
        docker compose -f "$COMPOSE_FILE" down
        echo "✓ DevBox Lite stopped."
        ;;
    shell|sh)
        docker exec -it devbox-lite bash
        ;;
    build)
        echo "Building DevBox..."
        docker compose -f "$COMPOSE_FILE" build
        echo "✓ Build complete."
        ;;
    rebuild)
        echo "Rebuilding DevBox (no cache)..."
        docker compose -f "$COMPOSE_FILE" build --no-cache
        echo "✓ Rebuild complete."
        ;;
    logs|log)
        docker compose -f "$COMPOSE_FILE" logs -f devbox
        ;;
    restart)
        echo "Restarting DevBox Lite..."
        docker compose -f "$COMPOSE_FILE" restart devbox
        echo "✓ DevBox Lite restarted."
        ;;
    status|st)
        docker compose -f "$COMPOSE_FILE" ps
        ;;
    clean)
        echo "Cleaning DevBox..."
        docker compose -f "$COMPOSE_FILE" down
        docker rmi devbox-lite 2>/dev/null
        echo "✓ DevBox cleaned."
        ;;
    setup|deps)
        docker exec -it devbox-lite bash -c "/workspace/scripts/setup-deps.sh $2"
        ;;
    run)
        shift
        docker exec -it devbox-lite bash -c "$*"
        ;;
    help|--help|-h|"")
        echo "DevBox Lite - Usage: devbox <command>"
        echo ""
        echo "Commands:"
        echo "  up/start      Start the container"
        echo "  down/stop     Stop the container"
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
        echo "Unknown command: $1"
        echo "Run 'devbox help' for usage."
        exit 1
        ;;
esac
