# DevBox Lite

**[فارسی](docs/fa/README.md)** | **[English](docs/en/README.md)**

---

Lightweight, isolated development environment based on Docker + Ubuntu 24.04, designed for **Laravel, Next.js, React, and Python** projects.

## Features
- **Lightweight and fast:** Image size is approximately 1 GB.
- **Offline Support:** Database management with offline image support
- **Complete Toolset:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **Database Management:** MySQL, PostgreSQL, Redis + GUI tools
- **API Testing:** Bruno (fully offline)
- **WSL2 Support:** Native Linux filesystem for better performance

## Quick Start

### Windows

```powershell
git clone https://github.com/efmojtaba1/DevBox.git D:\DevBox
cd D:\DevBox
.\scripts\build
.\scripts\up
```

### WSL2 (Recommended for better performance)

```powershell
# Step 1: Install WSL2 (PowerShell as Administrator)
wsl --install
```
Restart computer, then open Ubuntu terminal (search "Ubuntu" in Start Menu, or type `wsl` in PowerShell):
```bash
# Step 2: Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-v2 && sudo usermod -aG docker $USER && newgrp docker
```
Open Docker Desktop → Settings → Resources → WSL Integration → Enable Ubuntu.

```bash
# Step 3: Clone and setup
mkdir -p ~/projects && cd ~/projects && git clone https://github.com/efmojtaba1/DevBox.git && cd DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build
./scripts/up
./scripts/shell
```

## Documentation

| Language | Docs |
|----------|------|
| ‎[فارسی](docs/fa/README.md) | [نحوه استفاده](docs/fa/usage.md) · [داکر](docs/fa/docker.md) · [عیب‌یابی](docs/fa/troubleshooting.md) · [توسعه](docs/fa/development.md) |
| [English](docs/en/README.md) | [Usage](docs/en/usage.md) · [Docker](docs/en/docker.md) · [Troubleshooting](docs/en/troubleshooting.md) · [Development](docs/en/development.md) |

