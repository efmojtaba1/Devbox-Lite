# DevBox Lite

Lightweight, isolated development environment based on Docker + Ubuntu 24.04, designed for **Laravel, Next.js, React, and Python** projects.

---

## Features

- **Lightweight & Fast:** Image size ~1GB
- **Offline Support:** Database management with offline image support
- **Complete Toolset:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **Database Management:** MySQL, PostgreSQL, Redis + GUI tools (phpMyAdmin, Adminer, pgAdmin)
- **API Testing:** Bruno (fully offline)

---

## Available Tools

| Category | Tools |
|----------|-------|
| **PHP** | PHP 8.4 + Composer + Laravel Installer + Xdebug + Pest |
| **Node.js** | Node.js 22 + pnpm + npm + Bun |
| **Python** | Python 3.12 + pip + pipx + Jupyter + poetry + black + ruff + pytest |
| **Database** | MySQL Client + PostgreSQL Client + Redis CLI |
| **Server** | Nginx + Supervisor + PM2 |
| **Tools** | Docker CLI + GitHub CLI + Git |
| **API Testing** | Bruno (via VNC) |

---

## Quick Start

### Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) installed and running
- [VS Code](https://code.visualstudio.com/) with [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension

### Setup Steps (Windows)

1. Clone the project:

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
```
```powershell
cd D:\DevBox
```
2. Build the image:

```powershell
.\scripts\build
```

3. Start the container:

```powershell
.\scripts\up
```

4. Connect VS Code to the container via Remote Explorer → Dev Containers

### Setup Steps (WSL2 - Recommended for better performance)

1. Clone inside WSL2:

```bash
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox
```

2. Configure workspace path:

```bash
echo "WORKSPACE_PATH=$PWD" > .env
```

3. Build and start:

```bash
./scripts/build
./scripts/up
./scripts/shell
```

---

## Management Scripts

You can type these commands directly in the VS Code terminal:

| Command | Description |
|---------|-------------|
| `up` | Start the container |
| `down` | Stop the container |
| `shell` | Open container terminal |
| `logs` | View logs |
| `restart` | Restart the container |
| `status` | Check status |
| `build` | Build the image |
| `rebuild` | Rebuild the image (no cache) |
| `clean` | Remove image and containers |
| `setup-deps` | Auto-setup project dependencies |
| `test-api` | API testing tools (Bruno) |
| `run` | Run arbitrary command inside the container |
| `scan` | Detect project types in workspace |

### Database Management (shortcuts in VS Code terminal)

| Command | Description |
|---------|-------------|
| `create mysql` | Create and start MySQL |
| `create postgres` | Create and start PostgreSQL |
| `create redis` | Create and start Redis |
| `start mysql` | Start container |
| `stop mysql` | Stop container |
| `connect mysql` | Connect to database terminal |
| `phpmyadmin` | Start phpMyAdmin (port 8081) |
| `adminer` | Start Adminer (port 8082) |
| `pgadmin` | Start pgAdmin (port 8083) |

---

## Creating New Projects

> **Important:** All development commands (python, pnpm, composer, php, etc.) run **inside the container**, not on your host machine. Use `run` for single commands or `shell` for an interactive terminal.

### Using `run` (single commands)

```powershell
run pnpm create next-app my-app
run composer install
run python3 -m venv my-env
```

### Using `shell` (interactive terminal)

```powershell
shell
# Now inside the container:
cd /workspace
python3 -m venv my-env
source my-env/bin/activate
pip install flask
```

### Laravel

```bash
cd /workspace
laravel new my-app
cd my-app
composer install
npm install
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
pnpm create next-app my-app
cd my-app
pnpm install
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

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |

---

## License

This project is licensed under [LICENSE](../../LICENSE).

---

**Current version:** lite-1.0.0
