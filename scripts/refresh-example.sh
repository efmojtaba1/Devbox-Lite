#!/bin/bash
# DevBox Lite - Refresh example templates with latest versions
# Run this to update example/ with new framework versions, then rebuild.
# Usage: ./scripts/refresh-example.sh [template]
#   no args  = refresh all templates
#   laravel  = refresh only Laravel
#   next-js  = refresh only Next.js
#   python   = refresh only Python

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
EXAMPLE_DIR="$PROJECT_ROOT/example"
WORKSPACE_DIR="$PROJECT_ROOT/workspace"

TEMPLATES="${1:-all}"

refresh_laravel() {
    echo ""
    echo "========================================="
    echo "Refreshing Laravel template"
    echo "========================================="

    # Remove old template
    rm -rf "$EXAMPLE_DIR/laravel"

    # Check if workspace has a Laravel project to copy from
    if [ -d "$WORKSPACE_DIR/laravel" ] && [ -f "$WORKSPACE_DIR/laravel/artisan" ]; then
        echo "[copy] Copying from workspace/laravel..."
        # Copy source files only (no deps)
        rsync -a --exclude='node_modules' --exclude='vendor' --exclude='venv' \
            --exclude='.next' --exclude='.env' \
            "$WORKSPACE_DIR/laravel/" "$EXAMPLE_DIR/laravel/"
        echo "[ok] Laravel template updated from workspace."
    else
        echo "[create] No workspace/laravel found, creating fresh skeleton..."
        mkdir -p "$EXAMPLE_DIR/laravel"
        # Create minimal Laravel structure
        cat > "$EXAMPLE_DIR/laravel/composer.json" << 'EOF'
{
    "name": "laravel/laravel",
    "type": "project",
    "description": "The Laravel Framework.",
    "require": {
        "php": "^8.2",
        "laravel/framework": "^11.0",
        "laravel/tinker": "^2.9"
    },
    "require-dev": {
        "fakerphp/faker": "^1.23",
        "laravel/pint": "^1.0",
        "laravel/sail": "^1.26",
        "mockery/mockery": "^1.6",
        "nunomaduro/collision": "^8.0",
        "phpunit/phpunit": "^11.0",
        "spatie/laravel-ignition": "^2.4"
    },
    "autoload": {
        "psr-4": {
            "App\\": "app/",
            "Database\\Factories\\": "database/factories/",
            "Database\\Seeders\\": "database/seeders/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "Tests\\": "tests/"
        }
    },
    "scripts": {
        "post-autoload-dump": [
            "Illuminate\\Foundation\\ComposerScripts::postAutoloadDump",
            "@php artisan package:discover --ansi"
        ],
        "post-update-cmd": [
            "@php artisan vendor:publish --tag=laravel-assets --ansi --force"
        ],
        "post-root-package-install": [
            "@php -r \"file_exists('.env') || copy('.env.example', '.env');\""
        ],
        "post-create-project-cmd": [
            "@php artisan key:generate --ansi",
            "@php -r \"file_exists('database/database.sqlite') || touch('database/database.sqlite');\"",
            "@php artisan migrate --graceful --ansi"
        ]
    },
    "extra": {
        "laravel": {
            "dont-discover": []
        }
    },
    "config": {
        "optimize-autoloader": true,
        "preferred-install": "dist",
        "sort-packages": true,
        "allow-plugins": {
            "pestphp/pest-plugin": true,
            "php-http/discovery": true
        }
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
EOF
        echo "[ok] Laravel skeleton created. Run 'composer install' after build."
    fi
}

refresh_nextjs() {
    echo ""
    echo "========================================="
    echo "Refreshing Next.js template"
    echo "========================================="

    rm -rf "$EXAMPLE_DIR/next-js"

    if [ -d "$WORKSPACE_DIR/next-js" ] && [ -f "$WORKSPACE_DIR/next-js/package.json" ]; then
        echo "[copy] Copying from workspace/next-js..."
        rsync -a --exclude='node_modules' --exclude='.next' --exclude='.env' \
            "$WORKSPACE_DIR/next-js/" "$EXAMPLE_DIR/next-js/"
        echo "[ok] Next.js template updated from workspace."
    else
        echo "[create] No workspace/next-js found, creating fresh skeleton..."
        mkdir -p "$EXAMPLE_DIR/next-js/src/app"
        cat > "$EXAMPLE_DIR/next-js/package.json" << 'EOF'
{
  "name": "next-app",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "latest",
    "react": "latest",
    "react-dom": "latest"
  },
  "devDependencies": {
    "@types/node": "latest",
    "@types/react": "latest",
    "@types/react-dom": "latest",
    "typescript": "latest"
  }
}
EOF
        echo "[ok] Next.js skeleton created. Run 'pnpm install' after build."
    fi
}

refresh_python() {
    echo ""
    echo "========================================="
    echo "Refreshing Python template"
    echo "========================================="

    rm -rf "$EXAMPLE_DIR/python"

    if [ -d "$WORKSPACE_DIR/python" ]; then
        echo "[copy] Copying from workspace/python..."
        rsync -a --exclude='venv' --exclude='.venv' --exclude='__pycache__' \
            "$WORKSPACE_DIR/python/" "$EXAMPLE_DIR/python/"
        echo "[ok] Python template updated from workspace."
    else
        echo "[create] Creating fresh Python skeleton..."
        mkdir -p "$EXAMPLE_DIR/python"
        cat > "$EXAMPLE_DIR/python/app.py" << 'EOF'
from flask import Flask

app = Flask(__name__)

@app.route('/')
def home():
    return {'message': 'Hello from DevBox Lite!'}

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5001)
EOF
        cat > "$EXAMPLE_DIR/python/requirements.txt" << 'EOF'
flask>=3.0
EOF
        echo "[ok] Python skeleton created. Run 'pip install' after build."
    fi
}

refresh_react() {
    echo ""
    echo "========================================="
    echo "Refreshing React template"
    echo "========================================="

    rm -rf "$EXAMPLE_DIR/react"

    echo "[create] Creating React + Vite skeleton..."
    mkdir -p "$EXAMPLE_DIR/react/src"
    cat > "$EXAMPLE_DIR/react/package.json" << 'EOF'
{
  "name": "react-app",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.3.0",
    "vite": "^6.0.0"
  }
}
EOF
    cat > "$EXAMPLE_DIR/react/vite.config.js" << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
})
EOF
    cat > "$EXAMPLE_DIR/react/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>React App</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF
    cat > "$EXAMPLE_DIR/react/src/main.jsx" << 'EOF'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <App />
  </StrictMode>,
)
EOF
    cat > "$EXAMPLE_DIR/react/src/App.jsx" << 'EOF'
import { useState } from 'react'

function App() {
  const [count, setCount] = useState(0)

  return (
    <div style={{ textAlign: 'center', marginTop: '50px' }}>
      <h1>React + Vite</h1>
      <p>Count: {count}</p>
      <button onClick={() => setCount(count + 1)}>
        Increment
      </button>
    </div>
  )
}

export default App
EOF
    echo "[ok] React skeleton created. Run 'pnpm install' after build."
}

echo ""
echo "========================================="
echo "Refreshing example templates"
echo "========================================="

case "$TEMPLATES" in
    laravel)  refresh_laravel ;;
    next-js)  refresh_nextjs ;;
    python)   refresh_python ;;
    react)    refresh_react ;;
    all)
        refresh_laravel
        refresh_nextjs
        refresh_python
        refresh_react
        ;;
    *)
        echo "Usage: refresh-example.sh [laravel|next-js|python|react|all]"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "Done! Now rebuild the image:"
echo "  devbox rebuild"
echo "========================================="
