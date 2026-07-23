# DevBox Lite Development Guide

**[فارسی](../fa/development.md) | [Home](../README.md)**

---

## Table of Contents

* [Project Architecture](#project-architecture)
* [Dockerfile Structure](#dockerfile-structure)
* [Adding New Software](#adding-new-software)
  * [1. Create Install Script](#1-create-install-script)
  * [2. Add to Dockerfile](#2-add-to-dockerfile)
* [Changing Tool Versions](#changing-tool-versions)
* [Testing & Validation](#testing--validation)
  * [Test Tools](#test-tools)
  * [Test Full Image](#test-full-image)
* [Coding Style](#coding-style)
  * [Shell Scripts](#shell-scripts)
  * [PowerShell Scripts](#powershell-scripts)
  * [pnpm 11 Configuration](#pnpm-11-configuration)
* [Offline Support](#offline-support)
  * [Prebuilt Packages](#prebuilt-packages)
  * [Prebuilt Docker Images](#prebuilt-docker-images)
* [WSL2 Performance](#wsl2-performance)
  * [Why WSL2?](#why-wsl2)
  * [Prerequisites](#prerequisites)
  * [Full Setup](#full-setup)
  * [Optimize WSL2 Resources](#optimize-wsl2-resources)
  * [Performance Comparison](#performance-comparison)
* [Documentation](#documentation)

---

## Project Architecture [🔝](#table-of-contents)

```text
DevBox Lite/
├── docker/
│   ├── app/                  # Image build files
│   │   ├── Dockerfile        # Main file (multi-stage)
│   │   ├── .env              # Tool versions
│   │   ├── entrypoint.sh     # Startup script
│   │   └── install/          # Modular install scripts
│   └── compose/              # Docker Compose file (.env for WORKSPACE_PATH)
├── scripts/                  # Management scripts
├── docs/                     # Documentation
│   ├── fa/                   # Farsi documentation
│   └── en/                   # English documentation
├── prebuilt/                 # Pre-downloaded packages for offline use
│   ├── images/               # Docker image archives
│   └── packages/             # Bruno packages
└── workspace/                # Project workspace (mounted to /workspace in container)
    ├── data/                 # Persistent data
    │   └── bruno/            # Bruno API client data
    │       ├── collections/  # Saved collections and requests
    │       └── config/       # Bruno application config
    ├── laravel/              # Laravel project (example)
    ├── next-js/              # Next.js project (example)
    └── python/               # Python project (example)
```

---

## Dockerfile Structure [🔝](#table-of-contents)

```text
base → languages → frameworks → tools → extensions → cleanup → runtime
```

- **base:** Ubuntu 24.04 + base packages
- **languages:** PHP, Node.js, Python, Composer, Bun
- **frameworks:** Laravel Installer
- **tools:** Database clients, GitHub CLI, Docker CLI, Nginx, Supervisor, PM2, Bruno
- **extensions:** Xdebug, Pest
- **cleanup:** Cache cleanup
- **runtime:** Lightweight final image

---

## Adding New Software [🔝](#table-of-contents)

### 1. Create Install Script

```bash
# docker/app/install/tools/mytool.sh
#!/bin/bash
source "$(dirname "$0")/../common.sh"
log "Installing MyTool"
set -e
apt install -y --no-install-recommends mytool
echo "MyTool installed successfully."
mytool --version
```

### 2. Add to Dockerfile

```dockerfile
COPY install/tools/mytool.sh /tmp/install/mytool.sh
RUN chmod +x /tmp/install/mytool.sh && /tmp/install/mytool.sh
```

---

## Changing Tool Versions [🔝](#table-of-contents)

Edit `docker/app/.env`:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

Then rebuild the image:

```powershell
.\scripts\build
```

---

## Testing & Validation [🔝](#table-of-contents)

### Test Tools

```bash
docker run --rm devbox-lite bash -c "
  php --version
  node --version
  python3 --version
  composer --version
"
```

### Test Full Image

```bash
docker build -t devbox-lite:test ./docker/app
docker run --rm devbox-lite:test bash -c "
  php --version
  node --version
  python3 --version
"
```

---

## Coding Style [🔝](#table-of-contents)

### Shell Scripts

- Use `set -e` to stop on errors
- Use `common.sh` for shared functions
- Log important steps with `log`

### PowerShell Scripts

- Use `common.ps1` for shared functions
- Manage errors with `Test-Result`

### pnpm 11 Configuration

DevBox uses pnpm 11 with `dangerouslyAllowAllBuilds: true` in the global config (`~/.config/pnpm/config.yaml`) to allow build scripts from dependencies like `sharp` and `unrs-resolver` without manual approval.

The pnpm store is configured to use a Docker volume (`pnpm-store`) instead of the project directory, preventing `.pnpm-store` from appearing in the workspace root.

---

## Offline Support [🔝](#table-of-contents)

### Prebuilt Packages

Place packages in `prebuilt/packages/`:

- `bruno_3.5.2_amd64_linux.deb`

The install scripts check for prebuilt packages first, then download from internet if not found.

### Prebuilt Docker Images

Place exported images in `prebuilt/images/`:

- `mysql-8.4.tar`
- `postgres-17.tar`
- `redis-7.tar`
- etc.

---

## WSL2 Performance [🔝](#table-of-contents)

For better development performance, run DevBox inside WSL2 instead of using Docker Desktop's bind mount.

### Why WSL2?

- Docker Desktop bind mount: file operations go through Windows → WSL2 bridge (slow)
- WSL2 native: files live on Linux filesystem (10-20x faster)

### Prerequisites

1. WSL2 installed: `wsl --install` (PowerShell as Administrator)
2. Docker available in WSL2 (one of):
   - Docker Desktop WSL Integration enabled, OR
   - Docker installed natively: `sudo apt install docker.io docker-compose-v2`

### Full Setup

```bash
# 1. Open Ubuntu terminal (from Start Menu or type `wsl` in PowerShell)

# 2. Install Docker (if not using Docker Desktop integration)
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
wsl --shutdown  # Then reopen Ubuntu

# 3. Clone and configure
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env

# 4. Build and start
chmod +x scripts/*.sh
./scripts/build.sh
./scripts/up.sh
./scripts/shell.sh
```

### Optimize WSL2 Resources

Create or edit `%USERPROFILE%\.wslconfig`:

```ini
[wsl2]
memory=8GB
processors=4
swap=4GB
```

Then restart WSL: `wsl --shutdown`

### Performance Comparison

| Operation | Docker Desktop | WSL2 Native |
|-----------|---------------|-------------|
| pnpm install | ~7 min | ~30 sec |
| Next.js build | ~10+ min | ~30 sec |
| Next.js dev startup | ~5 min | ~5 sec |

---

## Documentation [🔝](#table-of-contents)

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
