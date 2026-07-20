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
        nextjs|react)           echo "postgres" ;;
        python)           echo "postgres" ;;
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
        nextjs|react|python)      echo "adminer" ;;
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
    if [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/Pipfile" ]; then
        echo "python"; return
    fi
    if ls "$dir"/*.py 1>/dev/null 2>&1; then
        echo "python"; return
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
                mysql)    echo "  MySQL:      host=devbox-mysql port=3306  (no auth)" ;;
                postgres) echo "  PostgreSQL: host=devbox-postgres port=5432  (no auth)" ;;
                redis)    echo "  Redis:      host=devbox-redis port=6379  (no auth)" ;;
            esac
        done
    fi

    if [ -n "$guis" ]; then
        echo ""
        echo "GUI tools:"
        for gui in $guis; do
            case "$gui" in
                phpmyadmin) echo "  phpMyAdmin: http://localhost:8081" ;;
                adminer)    echo "  Adminer:    http://localhost:8082" ;;
                pgadmin)    echo "  pgAdmin:    http://localhost:8083" ;;
            esac
        done
    fi
}

# Configure Laravel .env file with DevBox settings
configure_laravel_env() {
    local project_dir="$1"
    local env_file="$project_dir/.env"
    local has_redis="${2:-false}"

    if [ ! -f "$project_dir/artisan" ]; then
        return 0
    fi

    if [ ! -f "$env_file" ]; then
        echo "  [skip] No .env file found in Laravel project"
        return 0
    fi

    echo ""
    echo "Configuring Laravel .env..."

    # Update DB_HOST to devbox-mysql
    if grep -q "^DB_HOST=.*" "$env_file"; then
        sed -i 's/^DB_HOST=.*/DB_HOST=devbox-mysql/' "$env_file"
        echo "  [ok] DB_HOST set to devbox-mysql"
    fi

    # Update REDIS_HOST to devbox-redis
    if grep -q "^REDIS_HOST=.*" "$env_file"; then
        sed -i 's/^REDIS_HOST=.*/REDIS_HOST=devbox-redis/' "$env_file"
        echo "  [ok] REDIS_HOST set to devbox-redis"
    fi

    # Configure Redis-based settings if Redis is available
    if [ "$has_redis" = "true" ]; then
        # Set CACHE_STORE to redis
        if grep -q "^CACHE_STORE=.*" "$env_file"; then
            sed -i 's/^CACHE_STORE=.*/CACHE_STORE=redis/' "$env_file"
            echo "  [ok] CACHE_STORE set to redis"
        fi

        # Set QUEUE_CONNECTION to redis
        if grep -q "^QUEUE_CONNECTION=.*" "$env_file"; then
            sed -i 's/^QUEUE_CONNECTION=.*/QUEUE_CONNECTION=redis/' "$env_file"
            echo "  [ok] QUEUE_CONNECTION set to redis"
        fi

        # Set SESSION_DRIVER to redis
        if grep -q "^SESSION_DRIVER=.*" "$env_file"; then
            sed -i 's/^SESSION_DRIVER=.*/SESSION_DRIVER=redis/' "$env_file"
            echo "  [ok] SESSION_DRIVER set to redis"
        fi
    fi

    # Generate APP_KEY if empty
    local app_key
    app_key=$(grep '^APP_KEY=' "$env_file" | cut -d'=' -f2)
    if [ -z "$app_key" ] || [ "$app_key" = "" ]; then
        if (cd "$project_dir" && php artisan key:generate --force 2>/dev/null); then
            echo "  [ok] APP_KEY generated"
        else
            echo "  [warn] Could not generate APP_KEY, run 'php artisan key:generate' manually"
        fi
    else
        echo "  [skip] APP_KEY already set"
    fi

    echo "  [done] Laravel .env configured"
}

# Install and build frontend assets if Vite is detected
setup_laravel_frontend() {
    local project_dir="$1"

    if [ ! -f "$project_dir/artisan" ]; then
        return 0
    fi

    # Check if package.json exists with vite dependency
    if [ ! -f "$project_dir/package.json" ]; then
        return 0
    fi

    if ! grep -q '"vite"' "$project_dir/package.json" 2>/dev/null; then
        return 0
    fi

    echo ""
    echo "Setting up Laravel frontend (Vite)..."

    # Check if node_modules exists
    if [ -d "$project_dir/node_modules" ]; then
        echo "  [skip] node_modules already exists"
    else
        echo "  [install] Installing frontend dependencies..."
        if (cd "$project_dir" && pnpm install 2>/dev/null); then
            echo "  [ok] Frontend dependencies installed"
        elif (cd "$project_dir" && npm install 2>/dev/null); then
            echo "  [ok] Frontend dependencies installed (npm)"
        else
            echo "  [warn] Could not install frontend dependencies, run 'pnpm install' manually"
            return 0
        fi
    fi

    # Start Vite dev server in background
    echo "  [dev] Starting Vite dev server..."
    (cd "$project_dir" && nohup pnpm dev > /dev/null 2>&1 &)
    echo "  [ok] Vite dev server started (access via php artisan serve)"
}

# Offline-first dependency installation
# Tries to copy from /example/ templates, falls back to online install
install_deps_offline_first() {
    local project_dir="$1"
    local project_type="$2"
    local example_dir="/example-data"

    echo ""
    echo "Installing dependencies (offline-first)..."

    case "$project_type" in
        laravel)
            # vendor
            if [ -d "$project_dir/vendor" ]; then
                echo "  [skip] vendor already present"
            elif [ -d "$example_dir/laravel/vendor" ]; then
                echo "  [offline] Copying vendor from example..."
                cp -a "$example_dir/laravel/vendor" "$project_dir/vendor" 2>/dev/null && \
                    echo "  [ok] vendor copied from example" || \
                    echo "  [warn] copy failed, falling back to online"
            fi
            # composer install as fallback
            if [ ! -d "$project_dir/vendor" ] && [ -f "$project_dir/composer.json" ]; then
                echo "  [online] Running composer install..."
                (cd "$project_dir" && composer install --no-interaction 2>/dev/null) || \
                    echo "  [warn] composer install failed"
            fi
            # node_modules
            if [ -d "$project_dir/node_modules" ]; then
                echo "  [skip] node_modules already present"
            elif [ -d "$example_dir/laravel/node_modules" ]; then
                echo "  [offline] Copying node_modules from example..."
                cp -a "$example_dir/laravel/node_modules" "$project_dir/node_modules" 2>/dev/null && \
                    echo "  [ok] node_modules copied from example" || \
                    echo "  [warn] copy failed, falling back to online"
            fi
            if [ ! -d "$project_dir/node_modules" ] && [ -f "$project_dir/package.json" ]; then
                echo "  [online] Running pnpm install..."
                (cd "$project_dir" && pnpm install 2>/dev/null) || \
                    echo "  [warn] pnpm install failed"
            fi
            ;;
        next-js)
            if [ -d "$project_dir/node_modules" ]; then
                echo "  [skip] node_modules already present"
            elif [ -d "$example_dir/next-js/node_modules" ]; then
                echo "  [offline] Copying node_modules from example..."
                cp -a "$example_dir/next-js/node_modules" "$project_dir/node_modules" 2>/dev/null && \
                    echo "  [ok] node_modules copied from example" || \
                    echo "  [warn] copy failed, falling back to online"
            fi
            if [ ! -d "$project_dir/node_modules" ] && [ -f "$project_dir/package.json" ]; then
                echo "  [online] Running pnpm install..."
                (cd "$project_dir" && pnpm install 2>/dev/null) || \
                    echo "  [warn] pnpm install failed"
            fi
            ;;
        react)
            if [ -d "$project_dir/node_modules" ]; then
                echo "  [skip] node_modules already present"
            elif [ -d "$example_dir/react/node_modules" ]; then
                echo "  [offline] Copying node_modules from example..."
                cp -a "$example_dir/react/node_modules" "$project_dir/node_modules" 2>/dev/null && \
                    echo "  [ok] node_modules copied from example" || \
                    echo "  [warn] copy failed, falling back to online"
            fi
            if [ ! -d "$project_dir/node_modules" ] && [ -f "$project_dir/package.json" ]; then
                echo "  [online] Running pnpm install..."
                (cd "$project_dir" && pnpm install 2>/dev/null) || \
                    echo "  [warn] pnpm install failed"
            fi
            ;;
        python)
            if [ -d "$project_dir/venv" ]; then
                echo "  [skip] venv already present"
            elif [ -d "$example_dir/python/venv" ]; then
                echo "  [offline] Copying venv from example..."
                cp -a "$example_dir/python/venv" "$project_dir/venv" 2>/dev/null && \
                    echo "  [ok] venv copied from example" || \
                    echo "  [warn] copy failed, falling back to online"
            fi
            if [ ! -d "$project_dir/venv" ] && [ -f "$project_dir/requirements.txt" ]; then
                echo "  [online] Creating venv and installing..."
                (cd "$project_dir" && python3 -m venv venv 2>/dev/null && \
                    . venv/bin/activate && pip install -r requirements.txt 2>/dev/null) || \
                    echo "  [warn] Python setup failed"
            fi
            ;;
        *)
            echo "  [skip] No offline templates for '$project_type'"
            ;;
    esac
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

    # Create .deps structure for this project if it doesn't exist
    local deps_dir="/workspace/.deps"
    mkdir -p "$deps_dir"

    start_deps "$dbs" "$guis"
}

# Scan directory and return "fullpath name type" triples for all detected projects
scan_directory() {
    local dir="$1"
    local name type

    type=$(detect_project_type "$dir")
    if [ -n "$type" ]; then
        name=$(basename "$dir")
        echo "$dir $name $type"
    fi

    for subdir in "$dir"/*/; do
        [ -d "$subdir" ] || continue
        type=$(detect_project_type "$subdir")
        if [ -n "$type" ]; then
            name=$(basename "$subdir")
            echo "$subdir $name $type"
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
        name=$(echo "$line" | awk '{print $2}')
        type=$(echo "$line" | awk '{print $3}')
        printf "  %d) %s (%s)\n" "$i" "$name" "$type" >&2
        i=$((i + 1))
    done <<< "$projects"

    echo "" >&2
    echo "  a) All projects" >&2
    echo "" >&2

    # Selection goes to stdout (captured by caller) — returns "fullpath type" pairs
    while true; do
        read -r -p "Select project (1-$count or a): " choice
        if [ "$choice" = "a" ] || [ "$choice" = "A" ]; then
            echo "$projects" | awk '{print $1 " " $3}'
            return
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
            echo "$projects" | sed -n "${choice}p" | awk '{print $1 " " $3}'
            return
        fi
        echo "Invalid choice. Enter 1-$count or a." >&2
    done
}

# Main
main() {
    local project_dir="${1:-.}"
    local template="${2:-}"
    local auto_all="${3:-}"

    # Default to /workspace/workspace if no dir specified
    if [ "$project_dir" = "." ] && [ -z "$template" ]; then
        if [ -d "/workspace/workspace" ]; then
            project_dir="/workspace/workspace"
        fi
    fi

    if [ -n "$template" ]; then
        # Explicit template — single project mode
        setup_template "$template"
        install_deps_offline_first "$project_dir" "$template"
        if [ "$template" = "laravel" ]; then
            configure_laravel_env "$project_dir"
        fi
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
        # Only one project — use it directly (path + type)
        selected=$(echo "$projects" | awk '{print $1 " " $3}')
    elif [ "$auto_all" = "all" ] || [ ! -t 0 ]; then
        # Non-interactive mode or "all" flag — select all projects
        selected=$(echo "$projects" | awk '{print $1 " " $3}')
        echo ""
        echo "Detected $count project(s), setting up all..."
    else
        # Multiple projects — show selection menu (returns "fullpath type" pairs)
        selected=$(show_menu "$projects")
    fi

    # Setup each selected project and cd to last one
    local last_dir=""
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        local dir_path
        local tmpl
        local tmpl_dbs
        local has_redis="false"
        dir_path=$(echo "$line" | awk '{print $1}')
        tmpl=$(echo "$line" | awk '{print $2}')
        tmpl_dbs=$(get_deps "$tmpl")
        if echo "$tmpl_dbs" | grep -q "redis"; then
            has_redis="true"
        fi
        setup_template "$tmpl"
        install_deps_offline_first "$dir_path" "$tmpl"
        configure_laravel_env "$dir_path" "$has_redis"
        setup_laravel_frontend "$dir_path"
        last_dir="$dir_path"
    done <<< "$selected"

    # Cd to the last selected project directory
    if [ -n "$last_dir" ] && [ -d "$last_dir" ]; then
        cd "$last_dir" || true
        # Show relative path from /workspace for cleaner display
        local rel_path="${last_dir#/workspace/}"
        echo ""
        echo "========================================="
        echo "Project ready: $rel_path"
        echo "========================================="
        echo ""
        echo "To work on this project, use 'shell' then:"
        echo "  cd /workspace/$rel_path"
    fi
}

main "$@"
