#!/bin/bash

# Handle graceful shutdown
cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT

# Source bashrc for database management shortcuts
[ -f /root/.bashrc ] && source /root/.bashrc

# Create symlinks from project directories to .deps volume
# This allows performance benefits while avoiding directory conflicts
setup_deps_links() {
    local workspace="/workspace"
    local deps="$workspace/.deps"

    # Create .deps directory structure if it doesn't exist
    mkdir -p "$deps"

    # Find all project directories in workspace
    for project_dir in "$workspace"/*/; do
        [ -d "$project_dir" ] || continue
        local project_name=$(basename "$project_dir")

        # Skip hidden directories and .deps itself
        [[ "$project_name" == .* ]] && continue
        [ "$project_name" = ".deps" ] && continue

        # Create corresponding .deps subdirectory
        mkdir -p "$deps/$project_name"

        # Create symlinks for node_modules, vendor, venv if they exist in .deps
        for subdir in node_modules vendor venv; do
            if [ -d "$deps/$project_name/$subdir" ] && [ ! -e "$project_dir/$subdir" ]; then
                ln -s "$deps/$project_name/$subdir" "$project_dir/$subdir"
            fi
        done
    done
}

# Run setup on startup
setup_deps_links

exec "$@"
