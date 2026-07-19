#!/bin/bash
# DevBox Lite - Scan workspace for projects

source "$(dirname "$0")/common.sh"

Show-Header "Scanning Workspace Projects"

WORKSPACE_DIR="$PROJECT_ROOT/workspace"

if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Workspace folder not found."
    echo "Create projects in: $WORKSPACE_DIR"
    exit 0
fi

projects=()
for dir in "$WORKSPACE_DIR"/*/; do
    [ -d "$dir" ] || continue
    name=$(basename "$dir")

    # Detect project type
    type=""
    if [ -f "$dir/artisan" ]; then type="laravel"
    elif ls "$dir"/next.config* 1>/dev/null 2>&1; then type="nextjs"
    elif [ -f "$dir/manage.py" ]; then type="django"
    elif [ -f "$dir/requirements.txt" ] || [ -f "$dir/pyproject.toml" ] || ls "$dir"/*.py 1>/dev/null 2>&1; then type="python"
    elif [ -f "$dir/package.json" ] && grep -q '"react"' "$dir/package.json" 2>/dev/null; then type="react"
    elif [ -f "$dir/package.json" ]; then type="node"
    fi

    if [ -n "$type" ]; then
        projects+=("$name|$type")
    fi
done

if [ ${#projects[@]} -eq 0 ]; then
    echo "No projects found in workspace."
    echo "Create a project first, then run 'setup-deps' to start database services."
    exit 0
fi

echo ""
echo "Found ${#projects[@]} project(s):"
echo ""

for item in "${projects[@]}"; do
    name="${item%%|*}"
    type="${item##*|}"

    case "$type" in
        laravel)  desc="Laravel (PHP + MySQL + Redis)" ;;
        nextjs)   desc="Next.js (React + TypeScript)" ;;
        django)   desc="Django (Python + PostgreSQL + Redis)" ;;
        python)   desc="Python (PostgreSQL)" ;;
        react)    desc="React (JavaScript)" ;;
        node)     desc="Node.js (JavaScript)" ;;
        *)        desc="$type" ;;
    esac

    echo "  - $name"
    echo "    Type: $desc"
    echo ""
done

echo "Run 'setup-deps' to start database services for detected projects."
