#!/bin/bash
# DevBox Lite - Create new project (interactive, offline-first)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

WORKSPACE="/workspace"
TEMPLATES=("laravel" "next-js" "python" "react")

# ─── Helpers ──────────────────────────────────────────────

print_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       DevBox Lite — New Project       ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
    echo ""
}

ask() {
    local prompt="$1"
    local default="${2:-}"
    local result
    if [ -n "$default" ]; then
        read -rp "$prompt [$default]: " result
        echo "${result:-$default}"
    else
        read -rp "$prompt: " result
        echo "$result"
    fi
}

ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")
    echo "" >&2
    echo -e "${CYAN}$prompt${NC}" >&2
    for i in "${!options[@]}"; do
        echo "  $((i+1))) ${options[$i]}" >&2
    done
    echo "" >&2
    while true; do
        read -rp "  → Choose [1-${#options[@]}]: " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            echo "${options[$((choice-1))]}"
            return
        fi
        echo -e "${RED}  Invalid. Enter 1-${#options[@]}.${NC}" >&2
    done
}

ask_yesno() {
    local prompt="$1"
    local default="${2:-y}"
    local hint="Y/n"
    [ "$default" = "n" ] && hint="y/N"
    while true; do
        read -rp "  $prompt [$hint]: " answer
        answer="${answer:-$default}"
        case "$answer" in
            [yY]|[yY][eE][sS]) echo "yes"; return ;;
            [nN]|[nN][oO])     echo "no";  return ;;
            *) echo -e "${RED}  Enter y or n.${NC}" >&2 ;;
        esac
    done
}

validate_name() {
    local name="$1"
    if ! [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}Error: Invalid name '$name'.${NC}"
        return 1
    fi
    if [ -d "$WORKSPACE/$name" ]; then
        echo -e "${RED}Error: '$WORKSPACE/$name' already exists.${NC}"
        return 1
    fi
}

# ─── Template Menus ───────────────────────────────────────

menu_laravel() {
    echo ""
    echo -e "${CYAN}┌─ Laravel Options ─────────────────────┐${NC}"

    STARTER_KIT=$(ask_choice "Starter kit:" \
        "None (bare Laravel)" \
        "Breeze + Blade" \
        "Breeze + React" \
        "Breeze + Vue" \
        "Jetstream + Livewire" \
        "Jetstream + Inertia")

    DB=$(ask_choice "Database:" \
        "SQLite (recommended for dev)" \
        "MySQL" \
        "PostgreSQL" \
        "None")

    TESTING=$(ask_choice "Testing:" \
        "Pest (recommended)" \
        "PHPUnit")

    DARK_MODE=$(ask_yesno "Dark mode?" "y")
    API=$(ask_yesno "API routes?" "n")

    echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
}

menu_nextjs() {
    echo ""
    echo -e "${CYAN}┌─ Next.js Options ─────────────────────┐${NC}"
    TYPESCRIPT=$(ask_yesno "TypeScript?" "y")
    TAILWIND=$(ask_yesno "Tailwind CSS?" "y")
    echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
}

menu_python() {
    echo ""
    echo -e "${CYAN}┌─ Python Options ──────────────────────┐${NC}"
    FRAMEWORK=$(ask_choice "Framework:" "Flask (recommended)" "FastAPI" "None (plain Python)")
    echo -e "${CYAN}└────────────────────────────────────────┘${NC}"
}

# ─── Create Project ───────────────────────────────────────

create_project() {
    local project_dir="$WORKSPACE/$PROJECT_NAME"
    local example_dir="/example-data/$TEMPLATE"

    echo ""
    echo "========================================="
    echo "Creating: $PROJECT_NAME ($TEMPLATE)"
    echo "========================================="

    # ── Step 1: Copy source (offline) or download (online) ──
    if [ -d "$example_dir" ]; then
        echo "[offline] Copying from template..."
        mkdir -p "$project_dir"
        for item in "$example_dir"/*; do
            local name
            name=$(basename "$item")
            case "$name" in
                node_modules|vendor|venv|.next|__pycache__) continue ;;
            esac
            cp -a "$item" "$project_dir/" 2>/dev/null
        done
        echo "[ok] Source copied."

        # Apply framework-specific changes for Python
        if [ "$TEMPLATE" = "python" ]; then
            case "${FRAMEWORK:-}" in
                *"FastAPI"*)
                    cat > "$project_dir/app.py" << 'EOF'
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
def home():
    return {"message": "Hello from DevBox Lite!"}
EOF
                    echo "fastapi>=0.115" > "$project_dir/requirements.txt"
                    echo "uvicorn>=0.30" >> "$project_dir/requirements.txt"
                    echo "[configure] FastAPI"
                    ;;
                *"None"*|*"plain"*)
                    echo 'print("Hello from DevBox Lite!")' > "$project_dir/app.py"
                    rm -f "$project_dir/requirements.txt"
                    echo "[configure] Plain Python"
                    ;;
            esac
        fi
    else
        echo "[online] Downloading..."
        case "$TEMPLATE" in
            laravel)
                local cmd="laravel new $PROJECT_NAME --no-interaction"
                case "${TESTING:-}" in *"PHPUnit"*) cmd="$cmd --phpunit" ;; *) cmd="$cmd --pest" ;; esac
                case "${STARTER_KIT:-}" in
                    *"Breeze + Blade"*)   cmd="$cmd --bladed" ;;
                    *"Breeze + React"*)   cmd="$cmd --react" ;;
                    *"Breeze + Vue"*)     cmd="$cmd --vue" ;;
                    *"Jetstream + Livewire"*) cmd="$cmd --livewire" ;;
                    *"Jetstream + Inertia"*)  cmd="$cmd --inertia" ;;
                esac
                case "${DB:-}" in
                    *"MySQL"*)     cmd="$cmd --database=mysql" ;;
                    *"PostgreSQL"*) cmd="$cmd --database=pgsql" ;;
                esac
                [ "${DARK_MODE:-}" = "yes" ] && cmd="$cmd --dark"
                [ "${API:-}" = "yes" ] && cmd="$cmd --api"
                (cd "$WORKSPACE" && eval "$cmd" 2>/dev/null) || echo "[warn] laravel new failed"
                ;;
            next-js)
                local ts="" tw=""
                [ "${TYPESCRIPT:-}" = "yes" ] && ts="--typescript"
                [ "${TAILWIND:-}" = "yes" ] && tw="--tailwind"
                npx create-next-app@latest "$PROJECT_NAME" $ts $tw --eslint --app --src-dir --import-alias "@/*" --use-pnpm --no-turbopack 2>/dev/null || true
                ;;
            python)
                mkdir -p "$project_dir"
                case "${FRAMEWORK:-}" in
                    *"Flask"*)
                        cat > "$project_dir/app.py" << 'EOF'
from flask import Flask
app = Flask(__name__)
@app.route("/")
def home():
    return {"message": "Hello from DevBox Lite!"}
if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
EOF
                        echo "flask>=3.0" > "$project_dir/requirements.txt"
                        ;;
                    *"FastAPI"*)
                        cat > "$project_dir/app.py" << 'EOF'
from fastapi import FastAPI
app = FastAPI()
@app.get("/")
def home():
    return {"message": "Hello from DevBox Lite!"}
EOF
                        echo -e "fastapi>=0.115\nuvicorn>=0.30" > "$project_dir/requirements.txt"
                        ;;
                    *)
                        echo 'print("Hello from DevBox Lite!")' > "$project_dir/app.py"
                        ;;
                esac
                ;;
            react)
                mkdir -p "$project_dir/src"
                cat > "$project_dir/package.json" << 'EOF'
{"name":"react-app","private":true,"version":"0.1.0","type":"module",
 "scripts":{"dev":"vite","build":"vite build","preview":"vite preview"},
 "dependencies":{"react":"^19.0.0","react-dom":"^19.0.0"},
 "devDependencies":{"@vitejs/plugin-react":"^4.3.0","vite":"^6.0.0"}}
EOF
                cat > "$project_dir/vite.config.js" << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
export default defineConfig({
  plugins: [react()],
  server: { host: '0.0.0.0', port: 5173 },
})
EOF
                cat > "$project_dir/index.html" << 'EOF'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1.0"/>
<title>React App</title></head>
<body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
EOF
                cat > "$project_dir/src/main.jsx" << 'EOF'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App.jsx'
createRoot(document.getElementById('root')).render(<StrictMode><App /></StrictMode>)
EOF
                cat > "$project_dir/src/App.jsx" << 'EOF'
import { useState } from 'react'
export default function App() {
  const [count, setCount] = useState(0)
  return (<div style={{textAlign:'center',marginTop:'50px'}}>
    <h1>React + Vite</h1><p>Count: {count}</p>
    <button onClick={()=>setCount(count+1)}>Increment</button></div>)
}
EOF
                ;;
        esac
    fi

    # ── Step 2: Install dependencies ──
    echo ""
    echo "Installing dependencies..."

    case "$TEMPLATE" in
        laravel)
            if [ ! -d "$project_dir/vendor" ] && [ -f "$project_dir/composer.json" ]; then
                echo "[install] composer install..."
                (cd "$project_dir" && composer install --no-interaction 2>/dev/null) || echo "[warn] composer failed"
            else
                echo "[skip] vendor present"
            fi
            if [ ! -d "$project_dir/node_modules" ] && [ -f "$project_dir/package.json" ]; then
                echo "[install] pnpm install..."
                (cd "$project_dir" && pnpm install 2>/dev/null) || echo "[warn] pnpm failed"
            else
                echo "[skip] node_modules present"
            fi
            # .env + APP_KEY
            [ -f "$project_dir/.env.example" ] && [ ! -f "$project_dir/.env" ] && cp "$project_dir/.env.example" "$project_dir/.env"
            [ -f "$project_dir/artisan" ] && (cd "$project_dir" && php artisan key:generate --force 2>/dev/null) || true
            ;;
        next-js|react)
            if [ ! -d "$project_dir/node_modules" ] && [ -f "$project_dir/package.json" ]; then
                echo "[install] pnpm install..."
                (cd "$project_dir" && pnpm install 2>/dev/null) || echo "[warn] pnpm failed"
            else
                echo "[skip] node_modules present"
            fi
            ;;
        python)
            if [ ! -d "$project_dir/venv" ] && [ -f "$project_dir/requirements.txt" ]; then
                echo "[install] venv + pip install..."
                (cd "$project_dir" && python3 -m venv venv 2>/dev/null && . venv/bin/activate && pip install -r requirements.txt 2>/dev/null) || echo "[warn] python failed"
            else
                echo "[skip] venv present"
            fi
            ;;
    esac

    # ── Step 3: Apply Laravel options (after deps installed) ──
    if [ "$TEMPLATE" = "laravel" ] && [ -d "$project_dir/vendor" ]; then
        echo ""
        echo "[configure] Applying Laravel options..."

        # Starter kit
        case "${STARTER_KIT:-}" in
            *"Breeze + Blade"*)
                (cd "$project_dir" && composer require laravel/breeze --dev --no-interaction 2>/dev/null && php artisan breeze:install blade 2>/dev/null) || true
                ;;
            *"Breeze + React"*)
                (cd "$project_dir" && composer require laravel/breeze --dev --no-interaction 2>/dev/null && php artisan breeze:install react 2>/dev/null) || true
                ;;
            *"Breeze + Vue"*)
                (cd "$project_dir" && composer require laravel/breeze --dev --no-interaction 2>/dev/null && php artisan breeze:install vue 2>/dev/null) || true
                ;;
            *"Jetstream + Livewire"*)
                (cd "$project_dir" && composer require laravel/jetstream[livewire] --no-interaction 2>/dev/null && php artisan jetstream:install livewire 2>/dev/null) || true
                ;;
            *"Jetstream + Inertia"*)
                (cd "$project_dir" && composer require laravel/jetstream[inertia] --no-interaction 2>/dev/null && php artisan jetstream:install inertia 2>/dev/null) || true
                ;;
        esac

        # Database
        if [ -f "$project_dir/.env" ]; then
            case "${DB:-}" in
                *"MySQL"*)
                    sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=mysql/' "$project_dir/.env"
                    sed -i 's/^DB_HOST=.*/DB_HOST=devbox-mysql/' "$project_dir/.env"
                    ;;
                *"PostgreSQL"*)
                    sed -i 's/^DB_CONNECTION=.*/DB_CONNECTION=pgsql/' "$project_dir/.env"
                    sed -i 's/^DB_HOST=.*/DB_HOST=devbox-postgres/' "$project_dir/.env"
                    ;;
            esac
        fi

        # Testing
        if [ "${TESTING:-}" = "PHPUnit" ]; then
            (cd "$project_dir" && composer remove pestphp/pest --dev --no-interaction 2>/dev/null && composer require phpunit/phpunit --dev --no-interaction 2>/dev/null) || true
        fi

        echo "[ok] Laravel options applied."
    fi

    # ── Done ──
    echo ""
    echo "========================================="
    echo -e "${GREEN}  Project ready: $PROJECT_NAME${NC}"
    echo "========================================="
    echo ""
    echo "  cd /workspace/$PROJECT_NAME"
    echo ""
    case "$TEMPLATE" in
        laravel)       echo "  serve" ;;
        next-js|react) echo "  pnpm dev --host 0.0.0.0" ;;
        python)
            case "${FRAMEWORK:-}" in
                *"FastAPI"*) echo "  . venv/bin/activate && uvicorn app:app --reload --host 0.0.0.0 --port 8000" ;;
                *)           echo "  . venv/bin/activate && python app.py" ;;
            esac
            ;;
    esac
    echo ""
}

# ─── Main ─────────────────────────────────────────────────

main() {
    print_header

    # Step 1: Project name
    PROJECT_NAME="${1:-}"
    if [ -z "$PROJECT_NAME" ]; then
        PROJECT_NAME=$(ask "Project name")
    fi
    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Error: Name is required.${NC}"
        exit 1
    fi
    validate_name "$PROJECT_NAME" || exit 1

    # Step 2: Template selection
    TEMPLATE="${2:-}"
    if [ -z "$TEMPLATE" ]; then
        TEMPLATE=$(ask_choice "Select framework:" "${TEMPLATES[@]}")
    fi
    local valid=false
    for t in "${TEMPLATES[@]}"; do [ "$t" = "$TEMPLATE" ] && valid=true && break; done
    if ! $valid; then
        echo -e "${RED}Error: Unknown template '$TEMPLATE'${NC}"
        exit 1
    fi

    # Step 3: Template-specific options
    case "$TEMPLATE" in
        laravel)  menu_laravel ;;
        next-js)  menu_nextjs ;;
        python)   menu_python ;;
    esac

    # Step 4: Confirm
    echo ""
    echo -e "${CYAN}── Summary ──${NC}"
    echo "  Name:     $PROJECT_NAME"
    echo "  Template: $TEMPLATE"
    case "$TEMPLATE" in
        laravel)
            echo "  Starter:  ${STARTER_KIT:-None}"
            echo "  Database: ${DB:-SQLite}"
            echo "  Testing:  ${TESTING:-Pest}"
            echo "  Dark:     ${DARK_MODE:-yes}"
            echo "  API:      ${API:-no}"
            ;;
        next-js)
            echo "  TypeScript: ${TYPESCRIPT:-yes}"
            echo "  Tailwind:   ${TAILWIND:-yes}"
            ;;
        python)
            echo "  Framework:  ${FRAMEWORK:-Flask}"
            ;;
    esac
    echo ""

    CONFIRM=$(ask_yesno "Create this project?" "y")
    if [ "$CONFIRM" = "no" ]; then
        echo "Cancelled."
        exit 0
    fi

    # Step 5: Create
    create_project
}

main "$@"
