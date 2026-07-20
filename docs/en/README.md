# DevBox Lite

**[فارسی](../fa/README.md)** | [Back to Home](../../README.md)

Lightweight, isolated, ready-to-work — a Docker + Ubuntu 24.04 development environment built for **Laravel, Next.js, React, and Python** projects.

---

## Why DevBox Lite?

- **Lightweight & Fast:** Image size ~1 GB
- **Offline Support:** Databases and tools work without internet
- **Complete Tools:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **Database Management:** MySQL, PostgreSQL, Redis + GUI tools (phpMyAdmin, Adminer)
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

### Windows Setup

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

Then open VS Code and connect to the container via Remote Explorer → Dev Containers.

### WSL2 Setup (Recommended)

> **Why WSL2?** File operations in Docker Desktop are 10-20x slower than native WSL2 filesystem. For serious development, WSL2 is strongly recommended.

```bash
# 1. Install WSL2 (PowerShell as Administrator)
wsl --install
# Restart computer

# 2. Install Docker in Ubuntu
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER && newgrp docker

# 3. Enable Docker Desktop
# Docker Desktop → Settings → WSL Integration → Enable Ubuntu

# 4. Clone and setup
mkdir -p ~/projects && cd ~/projects
git clone git@github.com:efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env
chmod +x scripts/*.sh
./scripts/build.sh && ./scripts/up.sh && ./scripts/shell.sh
```

### Short Commands (Optional)

```bash
./scripts/setup-aliases.sh && source ~/.bashrc
```

Now you can use these commands:

| Command | Description |
|---------|-------------|
| `up` | Start the container |
| `down` | Stop the container |
| `down-v` | Stop container and remove volumes |
| `shell` | Open container terminal |
| `build` | Build the image |
| `rebuild` | Rebuild the image |
| `logs` | View logs |
| `status` | Check status |
| `setup-deps` | Auto-setup databases and tools |

---

## Folder Structure

```
DevBox_Lite/
├── docker/
│   ├── app/              # Image build files
│   │   ├── Dockerfile
│   │   ├── .env          # Tool versions
│   │   └── install/      # Install scripts
│   └── compose/          # Docker Compose + .env
├── scripts/              # Management scripts
├── docs/                 # Documentation (Farsi + English)
├── prebuilt/             # Offline-ready images
│   └── images/           # mysql-8.4.tar, postgres-17.tar, ...
└── workspace/            # Project workspace
    ├── data/bruno/       # Bruno collections and config
    ├── laravel/          # Laravel project
    ├── next-js/          # Next.js project
    └── python/           # Python project
```

> **Note:** The `prebuilt/` folder is in the project root, not inside `workspace/`. Images are automatically mounted to the container.

---

## Creating New Projects

> **Important:** All development commands (python, pnpm, composer, php, etc.) run **inside the container**.

### Quick Method: `run` (Single Commands)

```powershell
run laravel new my-app
run pnpm create next-app my-app
run python3 -m venv my-env
```

### Interactive Method: `shell` (Terminal)

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

## Auto-Setup Databases

The `setup-deps` script automatically detects project types and starts required databases and GUI tools:

```bash
# Inside the container
setup-deps /workspace
```

| Project Type | Database | GUI Tool |
|--------------|----------|----------|
| Laravel | MySQL + Redis | phpMyAdmin |
| Next.js / React | PostgreSQL | Adminer |
| Python | PostgreSQL | Adminer |

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

This project is under [LICENSE](../../LICENSE).

---

**Current Version:** lite-1.0.0
