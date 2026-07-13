#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Template → required databases mapping
get_deps() {
    local template="$1"
    case "$template" in
        laravel)          echo "mysql redis" ;;
        symfony)          echo "mysql redis" ;;
        fullstack)        echo "mysql redis" ;;
        django)           echo "postgres redis" ;;
        fastapi)          echo "postgres" ;;
        express)          echo "postgres redis" ;;
        rails)            echo "postgres redis" ;;
        go)               echo "postgres redis" ;;
        phoenix)          echo "postgres" ;;
        ai-stack)         echo "postgres redis" ;;
        ml-pipeline)      echo "postgres" ;;
        microservices)    echo "postgres redis" ;;
        multiuser)        echo "postgres redis" ;;
        fullstack-minio)  echo "mysql" ;;
        *)                echo "" ;;
    esac
}

# Template → recommended GUI tools
get_guis() {
    local template="$1"
    case "$template" in
        laravel|symfony)          echo "phpmyadmin" ;;
        fullstack|fullstack-minio) echo "phpmyadmin" ;;
        django|fastapi|express)   echo "adminer" ;;
        rails|go|phoenix)         echo "adminer" ;;
        ai-stack|ml-pipeline)     echo "adminer" ;;
        *)                        echo "" ;;
    esac
}

# Detect project type from files in current directory
detect_project_type() {
    local dir="$1"
    if [ -f "$dir/artisan" ]; then echo "laravel"; return; fi
    if [ -f "$dir/manage.py" ]; then echo "django"; return; fi
    if ls "$dir"/fastapi* 1>/dev/null 2>&1; then echo "fastapi"; return; fi
    if [ -f "$dir/Gemfile" ]; then echo "rails"; return; fi
    if [ -f "$dir/go.mod" ]; then echo "go"; return; fi
    if [ -f "$dir/mix.exs" ]; then echo "phoenix"; return; fi
    if [ -f "$dir/next.config"* ] 2>/dev/null || [ -d "$dir/.next" ]; then echo "nextjs"; return; fi
    if [ -f "$dir/pubspec.yaml" ]; then echo "flutter"; return; fi
    if [ -f "$dir/package.json" ]; then echo "express"; return; fi
    echo ""
}

# Check if a docker container is already running
is_running() {
    docker ps --format '{{.Names}}' | grep -q "^$1$"
}

# Check if container exists (running or stopped)
container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^$1$"
}

# Start or create a database
ensure_db() {
    local db="$1"
    local name="devbox-${db}"

    if is_running "$name"; then
        echo "  [skip] $db is already running"
        return 0
    fi

    if container_exists "$name"; then
        echo "  [start] $db exists, starting..."
        if docker start "$name" 2>/dev/null; then
            echo "  [ok] $db is running"
            return 0
        else
            echo "  [fix] $db failed to start, recreating..."
            docker rm -f "$name" > /dev/null 2>&1 || true
        fi
    fi

    echo "  [create] $db not found, creating..."
    "$SCRIPT_DIR/db-manager.sh" create "$db"
}

# Start a GUI tool
ensure_gui() {
    local tool="$1"
    local name="devbox-${tool}"

    if is_running "$name"; then
        echo "  [skip] $tool is already running"
        return 0
    fi

    if container_exists "$name"; then
        echo "  [start] $tool exists, starting..."
        if docker start "$name" 2>/dev/null; then
            echo "  [ok] $tool is running"
            return 0
        else
            echo "  [fix] $tool failed to start, recreating..."
            docker rm -f "$name" > /dev/null 2>&1 || true
        fi
    fi

    echo "  [create] $tool not found, creating..."
    "$SCRIPT_DIR/db-manager.sh" "$tool"
}

# Main
main() {
    local project_dir="${1:-.}"
    local template="${2:-}"

    # Auto-detect if no template specified
    if [ -z "$template" ]; then
        template=$(detect_project_type "$project_dir")
    fi

    if [ -z "$template" ]; then
        echo "Could not detect project type in: $project_dir"
        echo "Usage: setup-deps [project-dir] [template-name]"
        echo "Templates: laravel, django, fastapi, symfony, express, rails, go, phoenix, ai-stack, ml-pipeline, microservices, multiuser, fullstack, fullstack-minio"
        return 1
    fi

    echo "========================================="
    echo "Setting up dependencies for: $template"
    echo "========================================="
    echo ""

    # Start required databases
    local dbs
    dbs=$(get_deps "$template")
    if [ -n "$dbs" ]; then
        echo "Starting databases..."
        for db in $dbs; do
            ensure_db "$db"
        done
        echo ""
    else
        echo "No database dependencies for this template."
        echo ""
    fi

    # Start GUI tools
    local guis
    guis=$(get_guis "$template")
    if [ -n "$guis" ]; then
        echo "Starting GUI tools..."
        for gui in $guis; do
            ensure_gui "$gui"
        done
        echo ""
    fi

    echo "========================================="
    echo "Dependencies ready!"
    echo "========================================="

    # Print connection info
    if [ -n "$dbs" ]; then
        echo ""
        echo "Connection info:"
        for db in $dbs; do
            case "$db" in
                mysql)    echo "  MySQL:      host=mysql    port=3306  (no auth)" ;;
                postgres) echo "  PostgreSQL: host=postgres port=5432  (no auth)" ;;
                redis)    echo "  Redis:      host=redis    port=6379  (no auth)" ;;
                mongo)    echo "  MongoDB:    host=mongo    port=27017 (no auth)" ;;
            esac
        done
    fi
}

main "$@"
