<div class="doc-nav-header">
  <h1>DevBox Lite</h1>
  <span class="lang-links">
    <strong><a href="../fa/README.md">فارسی</a></strong> | <a href="../../README.md">Back to Home</a>
  </span>
</div>

Lightweight, isolated, ready-to-work — a Docker + Ubuntu 24.04 development environment built for **Laravel, Next.js, React, and Python** projects.

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
<li><a href="#why-devbox-lite">Why DevBox Lite?</a></li>
<li><a href="#available-tools">Available Tools</a></li>
<li>
<details><summary><a href="#quick-start">Quick Start</a></summary>
<ul>
<li><a href="#prerequisites">Prerequisites</a></li>
<li><a href="#windows-setup">Windows Setup</a></li>
<li><a href="#wsl2-setup-recommended">WSL2 Setup (Recommended)</a></li>
<li><a href="#short-commands-optional">Short Commands (Optional)</a></li>
</ul>
</details>
</li>
<li><a href="#folder-structure">Folder Structure</a></li>
<li>
<details><summary><a href="#creating-new-projects">Creating New Projects</a></summary>
<ul>
<li><a href="#recommended-new-project-interactive-offline-first">Recommended: <code>new-project</code> (Interactive, Offline-First)</a></li>
<li><a href="#available-templates">Available Templates</a></li>
<li><a href="#manual-method-shell-terminal">Manual Method: <code>shell</code> (Terminal)</a></li>
</ul>
</details>
</li>
<li><a href="#auto-setup-databases">Auto-Setup Databases</a></li>
<li><a href="#documentation">Documentation</a></li>
<li><a href="#license">License</a></li>
</ul>

---

<h2 id="why-devbox-lite" class="heading-with-back">
  <span>Why DevBox Lite?</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

- **Lightweight & Fast:** Image size ~1 GB
- **Offline Support:** Databases and tools work without internet
- **Complete Tools:** PHP, Node.js, Python, Composer, Laravel, Xdebug, Pest
- **Database Management:** MySQL, PostgreSQL, Redis + GUI tools (phpMyAdmin, Adminer)
- **API Testing:** Bruno (fully offline)

---

<h2 id="available-tools" class="heading-with-back">
  <span>Available Tools</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="quick-start" class="heading-with-back">
  <span>Quick Start</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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
| `new-project` | Create new project (interactive, offline-first) |
| `setup-deps` | Auto-setup databases and tools |
| `init-example` | Initialize example templates (one-time after rebuild) |
| `setup-example` | Verify example templates |
| `refresh-example` | Update examples to latest versions |

---

<h2 id="folder-structure" class="heading-with-back">
  <span>Folder Structure</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

```
DevBox_Lite/
├── docker/
│   ├── app/              # Image build files
│   │   ├── Dockerfile
│   │   └── install/      # Install scripts
│   └── compose/          # Docker Compose
├── scripts/              # Management scripts
├── example/              # Offline project templates
│   ├── laravel/          # Laravel skeleton
│   ├── next-js/          # Next.js skeleton
│   ├── python/           # Python skeleton
│   └── react/            # React skeleton
├── docs/                 # Documentation (Farsi + English)
├── prebuilt/             # Offline-ready images
│   └── images/           # mysql-8.4.tar, postgres-17.tar, ...
└── workspace/            # Your projects go here
```

> **Note:** The `prebuilt/` folder is in the project root, not inside `workspace/`. Images are automatically mounted to the container.

---

<h2 id="creating-new-projects" class="heading-with-back">
  <span>Creating New Projects</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

> **Important:** All development commands run **inside the container**.

### Recommended: `new-project` (Interactive, Offline-First)

```powershell
# From host — interactive menu
.\scripts\devbox.sh new-project

# Or inside the container
new-project
```

The script asks for project name, framework, and options step by step. Templates are copied from pre-built `example/` directory (no internet needed).

### Available Templates

| Template | Options | Port |
|----------|---------|------|
| `laravel` | Starter kit, database, testing, dark mode, API | 8000 |
| `next-js` | TypeScript, Tailwind | 3000 |
| `react` | Vite + React 19 | 5173 |
| `python` | Flask, FastAPI, Plain | 5001/8000 |

### Manual Method: `shell` (Terminal)

```powershell
.\scripts\shell.ps1
# Inside the container:
cd /workspace
laravel new my-app    # or: pnpm create next-app, etc.
```

---

<h2 id="auto-setup-databases" class="heading-with-back">
  <span>Auto-Setup Databases</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="documentation" class="heading-with-back">
  <span>Documentation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |

---

<h2 id="license" class="heading-with-back">
  <span>License</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

This project is under [LICENSE](../../LICENSE).

---

**Current Version:** lite-1.0.0
