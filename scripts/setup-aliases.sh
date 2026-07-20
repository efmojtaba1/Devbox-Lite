#!/bin/bash
# DevBox Lite - Setup aliases for WSL2
# Run this once: ./scripts/setup-aliases.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ALIASES="
# DevBox Lite aliases
alias up='cd $PROJECT_ROOT && ./scripts/devbox.sh up'
alias down='cd $PROJECT_ROOT && ./scripts/devbox.sh down'
alias down-v='cd $PROJECT_ROOT && ./scripts/down-v.sh'
alias shell='cd $PROJECT_ROOT && ./scripts/devbox.sh shell'
alias build='cd $PROJECT_ROOT && ./scripts/devbox.sh build'
alias rebuild='cd $PROJECT_ROOT && ./scripts/devbox.sh rebuild'
alias logs='cd $PROJECT_ROOT && ./scripts/devbox.sh logs'
alias restart='cd $PROJECT_ROOT && ./scripts/devbox.sh restart'
alias status='cd $PROJECT_ROOT && ./scripts/devbox.sh status'
alias clean='cd $PROJECT_ROOT && ./scripts/devbox.sh clean'
alias setup-deps='cd $PROJECT_ROOT && ./scripts/devbox.sh setup'
"

# Check if aliases already exist
if grep -q "# DevBox Lite aliases" ~/.bashrc 2>/dev/null; then
    echo "DevBox aliases already exist in ~/.bashrc"
else
    echo "$ALIASES" >> ~/.bashrc
    echo "✓ DevBox aliases added to ~/.bashrc"
    echo ""
    echo "Run 'source ~/.bashrc' or open a new terminal to use:"
    echo "  up, down, down-v, shell, build, rebuild, logs, restart, status, clean, setup-deps"
fi
