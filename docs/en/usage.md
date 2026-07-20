# Daily Usage Guide

**[فارسی](../fa/usage.md)** | [Home](../../README.md)

---

## First Time Setup

### Windows

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

### WSL2 (Recommended)

```bash
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

---

## Daily Workflow

1. Open Docker Desktop
2. Start the container: `.\scripts\up`
3. Open VS Code → Remote Explorer → Dev Containers
4. Work inside `/workspace` directory

---

## Management Scripts

Use these commands directly in VS Code terminal:

| Command | Description |
|---------|-------------|
| `up` | Start the container |
| `down` | Stop the container |
| `down-v` | Stop container and remove all volumes |
| `shell` | Open container terminal |
| `logs` | View logs |
| `restart` | Restart the container |
| `status` | Check status |
| `build` | Build the image |
| `rebuild` | Rebuild the image (no cache) |
| `clean` | Remove image and containers |
| `setup-deps` | Auto-setup databases and tools |
| `test-api` | API testing tools (Bruno) |
| `run` | Run arbitrary command inside container |
| `scan` | Detect project types in workspace |
| `new-project` | Create new project (offline-first, interactive) |
| `setup-example` | Install deps in example templates |
| `refresh-example` | Update examples to latest versions |

---

## Creating Projects

> **Important:** All development commands run **inside the container**, not on your host machine.

### Recommended: `new-project` (interactive, offline-first)

The `new-project` command creates projects interactively with an offline-first approach. It copies pre-built templates from `example/` directory (with dependencies already installed), so no internet connection is needed.

#### From Host (PowerShell / WSL2)

```powershell
# Interactive mode — asks for project name, template, and options
devbox new-project

# With arguments (skips name/template prompts)
devbox new-project my-app laravel
```

#### Inside Container

```bash
# Interactive mode
new-project

# With arguments
new-project my-app react
```

#### Available Templates

| Template | Description | Port |
|----------|-------------|------|
| `laravel` | Laravel + PHP (with starter kit options) | 8000 |
| `next-js` | Next.js + TypeScript + Tailwind | 3000 |
| `react` | React + Vite | 5173 |
| `python` | Python + Flask/FastAPI | 5000/8000 |

#### Laravel Options

When selecting Laravel, you get interactive choices:
- **Starter kit:** None, Breeze (Blade/React/Vue), Jetstream (Livewire/Inertia)
- **Database:** SQLite, MySQL, PostgreSQL
- **Testing:** Pest, PHPUnit
- **Dark mode:** Yes/No
- **API routes:** Yes/No

#### React Options

- **TypeScript:** Yes/No
- **Tailwind CSS:** Yes/No

#### Python Options

- **Framework:** Flask, FastAPI, Plain Python

### Setup Example Templates

Templates are automatically initialized when you run `up` (after first build or `down-v`). No manual setup needed.

To verify templates are ready:

```bash
# From host
devbox setup-example

# Inside container
setup-example
```

### Refresh Templates

To update example templates with latest framework versions:

```bash
# From host — refresh all
devbox refresh-example

# Refresh specific template
devbox refresh-example laravel

# Inside container
refresh-example
```

### Manual Project Creation

You can also create projects manually:

```bash
# Inside the container
cd /workspace

# Laravel
laravel new my-app
cd my-app
serve

# Next.js
pnpm create next-app my-app
cd my-app
pnpm dev

# React
pnpm create vite my-app --template react
cd my-app
pnpm dev

# Python
python3 -m venv my-env
source my-env/bin/activate
pip install flask
python app.py
```

### Running Projects

After creating a project, start the dev server:

| Framework | Command | URL |
|-----------|---------|-----|
| Laravel | `serve` | http://localhost:8000 |
| Next.js | `pnpm dev` | http://localhost:3000 |
| React | `pnpm dev` | http://localhost:5173 |
| Python (Flask) | `. venv/bin/activate && python app.py` | http://localhost:5000 |
| Python (FastAPI) | `. venv/bin/activate && uvicorn app:app --reload --host 0.0.0.0 --port 8000` | http://localhost:8000 |

---

## Stop and Remove Volumes

If you need to completely reset (remove all named volumes like `node_modules`, `vendor`, `bruno`):

```powershell
# Windows
.\scripts\down-v

# WSL2
./scripts/down-v.sh
```

> **Warning:** This removes ALL named volumes including Bruno collections, pnpm store, and cached dependencies.

---

## Auto-Setup Databases

The `setup-deps` script automatically detects your project type and starts the required databases and GUI tools:

```bash
# Inside the container
setup-deps /workspace
```

### What it detects

| Project Type | Detection | Databases | GUI Tool |
|-------------|-----------|-----------|----------|
| Laravel | `artisan` file | MySQL + Redis | phpMyAdmin |
| Next.js | `next.config*` file | PostgreSQL | Adminer |
| React | `react` in package.json | PostgreSQL | Adminer |
| Python | `*.py` or `requirements.txt` | PostgreSQL | Adminer |
| Django | `manage.py` file | PostgreSQL + Redis | Adminer |
| Express | `express` in package.json | PostgreSQL + Redis | Adminer |

### Connection Info (inside container)

```bash
# MySQL
mysql -h devbox-mysql -u root

# PostgreSQL
psql -h devbox-postgres -U postgres

# Redis
redis-cli -h devbox-redis
```

### Laravel `.env` Configuration

When you run `setup-deps`, the script automatically configures your Laravel `.env` file:
- Sets `DB_HOST=devbox-mysql`
- Sets `REDIS_HOST=devbox-redis`
- Sets `CACHE_STORE=redis` (if Redis is available)
- Sets `QUEUE_CONNECTION=redis` (if Redis is available)
- Sets `SESSION_DRIVER=redis` (if Redis is available)
- Generates `APP_KEY` if empty

If you need to configure manually:

```env
DB_CONNECTION=mysql
DB_HOST=devbox-mysql
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=

REDIS_HOST=devbox-redis

CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
```

> **Note:** Inside the container, use `devbox-mysql` and `devbox-redis` as hostnames, not `127.0.0.1`.

### Laravel with React/Vite (Starter Kits)

When you run `setup-deps`, the script automatically detects Vite and:
- Installs frontend dependencies (`pnpm install`)
- Starts Vite dev server with HMR in background

The dev server enables Hot Module Replacement - changes are reflected instantly without rebuilding.

---

## Database Management

### Creating Databases

| Command | Description |
|---------|-------------|
| `create mysql` | Create and start MySQL |
| `create postgres` | Create and start PostgreSQL |
| `create redis` | Create and start Redis |
| `create mongo` | Create and start MongoDB |
| `create mariadb` | Create and start MariaDB |
| `create memcached` | Create and start Memcached |

### Container Management

| Command | Description |
|---------|-------------|
| `start mysql` | Start container |
| `stop mysql` | Stop container |
| `connect mysql` | Connect to database terminal |

### GUI Tools

| Command | URL | Description |
|---------|-----|-------------|
| `phpmyadmin` | http://localhost:8081 | MySQL/MariaDB management |
| `adminer` | http://localhost:8082 | Multi-database management |
| `pgadmin` | http://localhost:8083 | PostgreSQL management |

---

## Default Ports

| Service | Port | Container Name |
|---------|------|----------------|
| MySQL | 3307 | devbox-mysql |
| PostgreSQL | 5433 | devbox-postgres |
| Redis | 6380 | devbox-redis |
| MongoDB | 27017 | devbox-mongo |
| MariaDB | 3308 | devbox-mariadb |
| phpMyAdmin | 8081 | - |
| Adminer | 8082 | - |
| pgAdmin | 8083 | - |

---

## Connecting VS Code to Container

1. Open VS Code
2. Select Remote Explorer → Dev Containers
3. Click **"+"** and select the project path
4. VS Code will automatically detect and connect to the container

---

## API Testing

### Bruno

```powershell
# From PowerShell
test-api bruno

# Inside container
bruno
```

Bruno opens at http://localhost:6080

### Offline Usage

1. Create collections in Bruno
2. Collections are saved to `workspace/data/bruno/collections/`
3. Collections work without internet

---

## Tool Versions

Tool versions are controlled by `docker/app/.env`:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

To change versions, edit the values and rebuild:

```powershell
.\scripts\build
```

---

## Important Notes

1. Projects go in the `workspace/` folder
2. Use VS Code Dev Containers for best experience
3. Back up your projects regularly
4. For issues, check [Troubleshooting](troubleshooting.md)

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
