<div class="doc-nav-header">
  <h1>Daily Usage Guide</h1>
  <span class="lang-links">
    <strong><a href="../fa/usage.md">فارسی</a></strong> | <a href="README.md">Home</a>
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
<li>
<details><summary><a href="#first-time-setup">First Time Setup</a></summary>
<ul>
<li><a href="#windows">Windows</a></li>
<li><a href="#wsl2-recommended">WSL2 (Recommended)</a></li>
</ul>
</details>
</li>
<li><a href="#daily-workflow">Daily Workflow</a></li>
<li><a href="#management-scripts">Management Scripts</a></li>
<li>
<details><summary><a href="#creating-projects">Creating Projects</a></summary>
<ul>
<li><a href="#recommended-new-project-interactive-offline-first">Recommended: <code>new-project</code> (interactive, offline-first)</a></li>
<li><a href="#setup-example-templates">Setup Example Templates</a></li>
<li><a href="#refresh-templates">Refresh Templates</a></li>
<li><a href="#manual-project-creation">Manual Project Creation</a></li>
<li><a href="#running-projects">Running Projects</a></li>
</ul>
</details>
</li>
<li><a href="#stop-and-remove-volumes">Stop and Remove Volumes</a></li>
<li>
<details><summary><a href="#auto-setup-databases">Auto-Setup Databases</a></summary>
<ul>
<li><a href="#what-it-detects">What it detects</a></li>
<li><a href="#connection-info-inside-container">Connection Info (inside container)</a></li>
<li><a href="#laravel-env-configuration">Laravel <code>.env</code> Configuration</a></li>
<li><a href="#laravel-with-reactvite-starter-kits">Laravel with React/Vite (Starter Kits)</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#database-management">Database Management</a></summary>
<ul>
<li><a href="#creating-databases">Creating Databases</a></li>
<li><a href="#container-management">Container Management</a></li>
<li><a href="#gui-tools">GUI Tools</a></li>
</ul>
</details>
</li>
<li><a href="#default-ports">Default Ports</a></li>
<li><a href="#connecting-vs-code-to-container">Connecting VS Code to Container</a></li>
<li>
<details><summary><a href="#api-testing">API Testing</a></summary>
<ul>
<li><a href="#bruno">Bruno</a></li>
<li><a href="#offline-usage">Offline Usage</a></li>
</ul>
</details>
</li>
<li><a href="#tool-versions">Tool Versions</a></li>
<li><a href="#important-notes">Important Notes</a></li>
<li><a href="#related-documentation">Related Documentation</a></li>
</ul>

---

<h2 id="first-time-setup" class="heading-with-back">
  <span>First Time Setup</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="daily-workflow" class="heading-with-back">
  <span>Daily Workflow</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

1. Open Docker Desktop
2. Start the container: `.\scripts\up`
3. Open VS Code → Remote Explorer → Dev Containers
4. Work inside `/workspace` directory

---

<h2 id="management-scripts" class="heading-with-back">
  <span>Management Scripts</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="creating-projects" class="heading-with-back">
  <span>Creating Projects</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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
| `python` | Python + Flask/FastAPI | 5001/8000 |

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
| Python (Flask) | `dev` | http://localhost:5001 |
| Python (FastAPI) | `dev` | http://localhost:8000 |

---

<h2 id="stop-and-remove-volumes" class="heading-with-back">
  <span>Stop and Remove Volumes</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

If you need to completely reset (remove all named volumes like `node_modules`, `vendor`, `bruno`):

```powershell
# Windows
.\scripts\down-v

# WSL2
./scripts/down-v.sh
```

> **Warning:** This removes ALL named volumes including Bruno collections, pnpm store, and cached dependencies.

---

<h2 id="auto-setup-databases" class="heading-with-back">
  <span>Auto-Setup Databases</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="database-management" class="heading-with-back">
  <span>Database Management</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="default-ports" class="heading-with-back">
  <span>Default Ports</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="connecting-vs-code-to-container" class="heading-with-back">
  <span>Connecting VS Code to Container</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

1. Open VS Code
2. Select Remote Explorer → Dev Containers
3. Click **"+"** and select the project path
4. VS Code will automatically detect and connect to the container

---

<h2 id="api-testing" class="heading-with-back">
  <span>API Testing</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="tool-versions" class="heading-with-back">
  <span>Tool Versions</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="important-notes" class="heading-with-back">
  <span>Important Notes</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

1. Projects go in the `workspace/` folder
2. Use VS Code Dev Containers for best experience
3. Back up your projects regularly
4. For issues, check [Troubleshooting](troubleshooting.md)

---

<h2 id="related-documentation" class="heading-with-back">
  <span>Related Documentation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

| Document | Description |
|----------|-------------|
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
