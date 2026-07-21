<div class="doc-nav-header">
  <h1>DevBox Lite Development Guide</h1>
  <span class="lang-links">
    <strong><a href="../fa/development.md">فارسی</a></strong> | <a href="README.md">Home</a>
  </span>
</div>

---

## Table of Contents

<style>
  .custom-toc,
  .custom-toc ul {
    list-style: none;
    padding-left: 0;
    margin: 0;
  }
  .custom-toc li {
    line-height: 2;
  }
  .custom-toc > li:not(:has(details)) {
    display: flex;
    align-items: center;
  }
  .custom-toc > li:not(:has(details))::before {
    content: "•";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
    font-size: 1.2rem;
    line-height: 1;
    flex-shrink: 0;
  }
  .custom-toc details {
    width: 100%;
  }
  .custom-toc summary {
    cursor: pointer;
    display: flex;
    align-items: center;
    list-style: none;
  }
  .custom-toc summary::-webkit-details-marker {
    display: none;
  }
  .custom-toc summary::before {
    content: "▶";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
    font-size: 0.7rem;
    line-height: 1;
    flex-shrink: 0;
  }
  .custom-toc details[open] > summary::before {
    content: "▼";
    font-size: 0.65rem;
  }
  .custom-toc details ul {
    padding-left: 1.2rem;
    margin-top: 0.25rem;
    margin-bottom: 0.5rem;
  }
  .custom-toc details ul li {
    display: flex;
    align-items: center;
  }
  .custom-toc details ul li::before {
    content: "◦";
    display: inline-flex;
    justify-content: flex-start;
    align-items: center;
    width: 1.2rem;
    font-size: 1rem;
    font-weight: bold;
    line-height: 1;
    flex-shrink: 0;
  }
  .heading-with-back {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .heading-with-back span {
    flex: 1;
  }
  .back-to-toc {
    text-decoration: none !important;
  }
  .back-to-toc:hover {
    text-decoration: none !important;
  }
  .doc-nav-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 1rem;
    direction: ltr;
  }
  .doc-nav-header .lang-links {
    direction: rtl;
  }
</style>

<ul class="custom-toc" dir="ltr">
<li><a href="#project-architecture">Project Architecture</a></li>
<li><a href="#dockerfile-structure">Dockerfile Structure</a></li>
<li>
<details><summary><a href="#adding-new-software">Adding New Software</a></summary>
<ul>
<li><a href="#1-create-install-script">1. Create Install Script</a></li>
<li><a href="#2-add-to-dockerfile">2. Add to Dockerfile</a></li>
</ul>
</details>
</li>
<li><a href="#changing-tool-versions">Changing Tool Versions</a></li>
<li>
<details><summary><a href="#testing--validation">Testing & Validation</a></summary>
<ul>
<li><a href="#test-tools">Test Tools</a></li>
<li><a href="#test-full-image">Test Full Image</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#coding-style">Coding Style</a></summary>
<ul>
<li><a href="#shell-scripts">Shell Scripts</a></li>
<li><a href="#powershell-scripts">PowerShell Scripts</a></li>
<li><a href="#pnpm-11-configuration">pnpm 11 Configuration</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#offline-support">Offline Support</a></summary>
<ul>
<li><a href="#prebuilt-packages">Prebuilt Packages</a></li>
<li><a href="#prebuilt-docker-images">Prebuilt Docker Images</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#wsl2-performance">WSL2 Performance</a></summary>
<ul>
<li><a href="#why-wsl2">Why WSL2?</a></li>
<li><a href="#prerequisites">Prerequisites</a></li>
<li><a href="#full-setup">Full Setup</a></li>
<li><a href="#optimize-wsl2-resources">Optimize WSL2 Resources</a></li>
<li><a href="#performance-comparison">Performance Comparison</a></li>
</ul>
</details>
</li>
<li><a href="#documentation">Documentation</a></li>
</ul>

---

<h2 id="project-architecture" class="heading-with-back">
  <span>Project Architecture</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

```
DevBox Lite/
├── docker/
│   ├── app/              # Image build files
│   │   ├── Dockerfile    # Main file (multi-stage)
│   │   ├── .env          # Tool versions
│   │   ├── entrypoint.sh # Startup script
│   │   └── install/      # Modular install scripts
│   └── compose/          # Docker Compose file (.env for WORKSPACE_PATH)
├── scripts/              # Management scripts
├── docs/                 # Documentation
│   ├── fa/               # Farsi documentation
│   └── en/               # English documentation
├── prebuilt/             # Pre-downloaded packages for offline use
│   ├── images/           # Docker image archives
│   └── packages/         # Bruno packages
└── workspace/            # Project workspace (mounted to /workspace in container)
    ├── data/             # Persistent data
    │   └── bruno/        # Bruno API client data
    │       ├── collections/  # Saved collections and requests
    │       └── config/       # Bruno application config
    ├── laravel/          # Laravel project (example)
    ├── next-js/          # Next.js project (example)
    └── python/           # Python project (example)
```

---

<h2 id="dockerfile-structure" class="heading-with-back">
  <span>Dockerfile Structure</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="adding-new-software" class="heading-with-back">
  <span>Adding New Software</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="changing-tool-versions" class="heading-with-back">
  <span>Changing Tool Versions</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="testing--validation" class="heading-with-back">
  <span>Testing & Validation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="coding-style" class="heading-with-back">
  <span>Coding Style</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="offline-support" class="heading-with-back">
  <span>Offline Support</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="wsl2-performance" class="heading-with-back">
  <span>WSL2 Performance</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="documentation" class="heading-with-back">
  <span>Documentation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
