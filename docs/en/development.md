# DevBox Lite Development Guide

**[فارسی](../fa/development.md)** | **[English](development.md)** | [Home](../../README.md)

---

## Project Architecture

```
DevBox Lite/
├── docker/
│   ├── app/              # Image build files
│   │   ├── Dockerfile    # Main file (multi-stage)
│   │   ├── .env          # Tool versions
│   │   ├── entrypoint.sh # Startup script
│   │   └── install/      # Modular install scripts
│   └── compose/          # Docker Compose file
├── scripts/              # Management scripts
├── docs/                 # Documentation
│   ├── fa/               # Farsi documentation
│   └── en/               # English documentation
├── prebuilt/             # Pre-downloaded packages for offline use
│   ├── images/           # Docker image archives
│   └── packages/         # Bruno packages
└── workspace/            # Project workspace
```

---

## Dockerfile Structure

```
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

## Adding New Software

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

## Changing Tool Versions

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

## Testing & Validation

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

## Coding Style

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

## Offline Support

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

## Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
