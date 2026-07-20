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
2. Start the container: `.\scripts\up` (Windows) or `./scripts/up` (WSL2)
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

---

## Creating Projects

> **Important:** All development commands run **inside the container**, not on your host machine.

### Using `run` (single commands)

```powershell
run laravel new my-app
run pnpm create next-app my-app
run python3 -m venv my-env
```

### Using `shell` (interactive terminal)

```powershell
shell
# Now inside the container:
cd /workspace
```

### Laravel

```bash
cd /workspace
laravel new my-app
cd my-app
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
pnpm create next-app my-app
cd my-app
pnpm dev --hostname 0.0.0.0 --port=3000
```

### Python

```bash
cd /workspace
python3 -m venv my-env
source my-env/bin/activate
pip install flask
```

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
