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
        nextjs)           echo "" ;;
        react)            echo "" ;;
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
        nextjs|react)             echo "" ;;
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
    if ls "$dir"/next.config* 1>/dev/null 2>&1 || [ -d "$dir/.next" ]; then echo "nextjs"; return; fi
    if [ -f "$dir/pubspec.yaml" ]; then echo "flutter"; return; fi
    if [ -f "$dir/package.json" ]; then
        if grep -q '"react"' "$dir/package.json" 2>/dev/null; then
            echo "react"; return
        else
            echo "express"; return
        fi
    fi
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

# Start databases and GUI tools, print connection info
start_deps() {
    local dbs="$1"
    local guis="$2"

    if [ -n "$dbs" ]; then
        echo ""
        echo "Starting databases..."
        for db in $dbs; do
            ensure_db "$db"
        done
    fi

    if [ -n "$guis" ]; then
        echo ""
        echo "Starting GUI tools..."
        for gui in $guis; do
            ensure_gui "$gui"
        done
    fi

    echo ""
    echo "========================================="
    if [ -z "$dbs" ] && [ -z "$guis" ]; then
        echo "No database dependencies needed for this project."
        echo "You can start developing right away!"
    else
        echo "Dependencies ready!"
    fi
    echo "========================================="

    if [ -n "$dbs" ]; then
        echo ""
        echo "Connection info:"
        for db in $dbs; do
            case "$db" in
                mysql)    echo "  MySQL:      host=mysql    port=3306  (no auth)" ;;
                postgres) echo "  PostgreSQL: host=postgres port=5432  (no auth)" ;;
                redis)    echo "  Redis:      host=redis    port=6379  (no auth)" ;;
            esac
        done
    fi
}

# Setup a single template
setup_template() {
    local template="$1"
    local dbs
    local guis

    dbs=$(get_deps "$template")
    guis=$(get_guis "$template")

    echo ""
    echo "========================================="
    echo "Setting up: $template"
    echo "========================================="

    start_deps "$dbs" "$guis"
}

# Scan directory and return "name type" pairs for all detected projects
scan_directory() {
    local dir="$1"
    local name type

    type=$(detect_project_type "$dir")
    if [ -n "$type" ]; then
        name=$(basename "$dir")
        echo "$name $type"
    fi

    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] || continue
        type=$(detect_project_type "$subdir")
        if [ -n "$type" ]; then
            name=$(basename "$subdir")
            echo "$name $type"
        fi
    done
}

# Show interactive menu for project selection
show_menu() {
    local projects="$1"
    local count
    count=$(echo "$projects" | wc -l)
    local i=1

    # Display menu to stderr so it's not captured by $()
    echo "" >&2
    echo "=========================================" >&2
    echo "Detected projects in workspace:" >&2
    echo "=========================================" >&2
    echo "" >&2

    while IFS= read -r line; do
        local name
        local type
        name=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        printf "  %d) %s (%s)\n" "$i" "$name" "$type" >&2
        i=$((i + 1))
    done <<< "$projects"

    echo "" >&2
    echo "  a) All projects" >&2
    echo "" >&2

    # Selection goes to stdout (captured by caller)
    while true; do
        read -r -p "Select project (1-$count or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            echo "$projects" | awk '{print $2}'
            return
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            echo "$projects" | sed -n "${choice}p" | awk '{print $2}'
            return
        fi
        echo "Invalid choice. Enter 1-$count or a." >&2
    done
}

# Main
main() {
    local project_dir="${1:-.}"
    local template="${2:-}"

    # Default to /workspace/workspace if no dir specified
    if [ "$project_dir" = "." ] && [ -z "$template" ]; then
        if [ -d "/workspace/workspace" ]; then
            project_dir="/workspace/workspace"
        fi
    fi

    if [ -n "$template" ]; then
        # Explicit template — single project mode
        setup_template "$template"
        return
    fi

    # Auto-detect all projects
    local projects
    projects=$(scan_directory "$project_dir")

    if [ -z "$projects" ]; then
        echo "Could not detect any projects in: $project_dir"
        echo "Usage: setup-deps [project-dir] [template-name]"
        echo "Templates: laravel, django, fastapi, symfony, express, rails, go, phoenix, ai-stack, ml-pipeline, microservices, multiuser, fullstack, fullstack-minio, nextjs, react"
        return 1
    fi

    local count
    count=$(echo "$projects" | wc -l)
    local selected

    if [ "$count" -eq 1 ]; then
        # Only one project — use it directly
        selected=$(echo "$projects" | awk '{print $2}')
    else
        # Multiple projects — show selection menu
        selected=$(show_menu "$projects")
    fi

    # Setup each selected template
    while IFS= read -r t; do
        [ -z "$t" ] && continue
        setup_template "$t"
    done <<< "$selected"
}

main "$@"
