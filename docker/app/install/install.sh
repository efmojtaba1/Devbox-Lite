#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$INSTALL_DIR/common.sh"

run_step() {

    local NAME="$1"
    local SCRIPT="$2"

    echo
    echo "========================================="
    echo "$NAME"
    echo "========================================="

    START=$(date +%s)

    bash "$SCRIPT"

    END=$(date +%s)

    echo "$NAME finished in $((END-START)) seconds"
}

# Base
run_step "System"         "$INSTALL_DIR/base/system.sh"
run_step "Python"         "$INSTALL_DIR/base/python.sh"
run_step "Python Tools"   "$INSTALL_DIR/base/python-tools.sh"
run_step "Node"           "$INSTALL_DIR/base/node.sh"
run_step "Bun"            "$INSTALL_DIR/base/bun.sh"
run_step "PHP"            "$INSTALL_DIR/base/php.sh"
run_step "Composer"       "$INSTALL_DIR/base/composer.sh"

# Frameworks
run_step "Laravel"        "$INSTALL_DIR/frameworks/laravel.sh"

# Tools
run_step "Database"       "$INSTALL_DIR/tools/database.sh"
run_step "GitHub"         "$INSTALL_DIR/tools/github.sh"
run_step "Docker"         "$INSTALL_DIR/tools/docker.sh"
run_step "Server"         "$INSTALL_DIR/tools/server.sh"

# Extensions
run_step "Xdebug"         "$INSTALL_DIR/extensions/xdebug.sh"
run_step "Pest"           "$INSTALL_DIR/extensions/pest.sh"

# Cleanup
run_step "Cleanup"        "$INSTALL_DIR/cleanup.sh"

echo
echo "========================================="
echo "DevBox Lite installation completed"
echo "========================================="
