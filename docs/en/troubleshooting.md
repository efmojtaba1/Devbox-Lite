<div class="doc-nav-header">
  <h1>Troubleshooting Guide</h1>
  <span class="lang-links">
    <strong><a href="../fa/troubleshooting.md">فارسی</a></strong> | <a href="README.md">Home</a>
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
<li><a href="#quick-fix">Quick Fix</a></li>
<li>
<details><summary><a href="#docker-issues">Docker Issues</a></summary>
<ul>
<li><a href="#container-wont-start">Container Won't Start</a></li>
<li><a href="#port-in-use">Port in Use</a></li>
<li><a href="#permission-denied">Permission Denied</a></li>
<li><a href="#image-build-fails">Image Build Fails</a></li>
<li><a href="#disk-space-full">Disk Space Full</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#workspace-issues">Workspace Issues</a></summary>
<ul>
<li><a href="#projects-not-visible-in-container">Projects Not Visible in Container</a></li>
<li><a href="#python-virtual-environment-empty">Python Virtual Environment Empty</a></li>
<li><a href="#node-modules-not-found">Node Modules Not Found</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#vs-code-issues">VS Code Issues</a></summary>
<ul>
<li><a href="#vs-code-wont-connect-to-container">VS Code Won't Connect to Container</a></li>
<li><a href="#extensions-wont-install">Extensions Won't Install</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#tool-issues">Tool Issues</a></summary>
<ul>
<li><a href="#tools-not-installed">Tools Not Installed</a></li>
<li><a href="#pnpm-err_pnpm_ignored_builds">pnpm ERR_PNPM_IGNORED_BUILDS</a></li>
<li><a href="#composer-errors">Composer Errors</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#network-issues">Network Issues</a></summary>
<ul>
<li><a href="#container-communication">Container Communication</a></li>
<li><a href="#internet-access">Internet Access</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#database-issues">Database Issues</a></summary>
<ul>
<li><a href="#database-container-wont-start">Database Container Won't Start</a></li>
<li><a href="#cannot-connect-to-database">Cannot Connect to Database</a></li>
<li><a href="#laravel-migration-fails-with-connection-refused">Laravel Migration Fails with Connection Refused</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#volume-issues">Volume Issues</a></summary>
<ul>
<li><a href="#changes-not-saving">Changes Not Saving</a></li>
<li><a href="#laravel-project-creation-fails-silently">Laravel Project Creation Fails Silently</a></li>
<li><a href="#named-volumes-stale-after-project-delete">Named Volumes Stale After Project Delete</a></li>
</ul>
</details>
</li>
<li><a href="#docker-desktop-wont-start">Docker Desktop Won't Start</a></li>
<li>
<details><summary><a href="#wsl2-issues">WSL2 Issues</a></summary>
<ul>
<li><a href="#wsl2-not-installed">WSL2 Not Installed</a></li>
<li><a href="#docker-not-available-in-wsl2">Docker Not Available in WSL2</a></li>
<li><a href="#slow-performance-on-windows">Slow Performance on Windows</a></li>
<li><a href="#permission-denied-in-wsl2">Permission Denied in WSL2</a></li>
<li><a href="#docker-build-slow-in-wsl2">Docker Build Slow in WSL2</a></li>
<li><a href="#cannot-access-windows-files-from-wsl2">Cannot Access Windows Files from WSL2</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#github-authentication">GitHub Authentication</a></summary>
<ul>
<li><a href="#option-1-ssh-key-recommended">Option 1: SSH Key (Recommended)</a></li>
<li><a href="#option-2-personal-access-token">Option 2: Personal Access Token</a></li>
</ul>
</details>
</li>
<li><a href="#useful-resources">Useful Resources</a></li>
<li><a href="#related-documentation">Related Documentation</a></li>
</ul>

---

<h2 id="quick-fix" class="heading-with-back">
  <span>Quick Fix</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

Most issues can be resolved with these steps:

```powershell
.\scripts\logs        # Check what's wrong
.\scripts\restart     # Try restarting
.\scripts\rebuild     # If still broken, rebuild
.\scripts\up          # Start again
```

If nothing works, restart Docker Desktop.

---

<h2 id="docker-issues" class="heading-with-back">
  <span>Docker Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Container Won't Start

**Check logs:**
```powershell
.\scripts\logs
```

**Rebuild and start:**
```powershell
.\scripts\rebuild
.\scripts\up
```

---

### Port in Use

Find and kill the process using the port:

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

---

### Permission Denied

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

If the issue persists:

```powershell
.\scripts\down
docker volume rm devbox_workspace
.\scripts\up
```

---

### Image Build Fails

```powershell
docker builder prune
.\scripts\rebuild
```

---

### Disk Space Full

```powershell
docker system df
docker system prune -a --volumes
```

---

<h2 id="workspace-issues" class="heading-with-back">
  <span>Workspace Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Projects Not Visible in Container

The `workspace/` folder on your host is mounted to `/workspace` inside the container. Make sure:

1. `docker/compose/.env` has correct `WORKSPACE_PATH`
2. Project directories exist in `workspace/` on your host

```powershell
# Check current mount
.\scripts\shell
ls /workspace
```

---

### Python Virtual Environment Empty

When you create a Python project, the `venv` folder might appear empty because Docker volume mounts overwrite it.

**Fix:** Recreate the venv inside the container:

```bash
cd /workspace/python
python3 -m venv venv
source venv/bin/activate
pip install flask requests
```

---

### Node Modules Not Found

If `node_modules` is missing after container restart:

```bash
cd /workspace/next-js
npm install
```

---

<h2 id="vs-code-issues" class="heading-with-back">
  <span>VS Code Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### VS Code Won't Connect to Container

1. Restart container: `.\scripts\restart`
2. In VS Code: F1 → "Dev Containers: Reopen in Container"

### Extensions Won't Install

```powershell
docker compose exec devbox-lite rm -rf /root/.vscode-server
```

Then restart VS Code.

---

<h2 id="tool-issues" class="heading-with-back">
  <span>Tool Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Tools Not Installed

```powershell
docker compose exec devbox-lite bash
which php
which node
which python3
```

### pnpm ERR_PNPM_IGNORED_BUILDS

If you see `ERR_PNPM_IGNORED_BUILDS` when running `pnpm install`:

```bash
# Inside container
pnpm approve-builds --all
```

This is a pnpm 10+ security feature. DevBox pre-configures `dangerouslyAllowAllBuilds: true`, so this should not happen after rebuild.

### Composer Errors

```powershell
docker compose exec devbox-lite bash
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
```

---

<h2 id="network-issues" class="heading-with-back">
  <span>Network Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Container Communication

```powershell
docker network ls
docker network inspect devbox-network
.\scripts\down
.\scripts\up
```

### Internet Access

```powershell
docker compose exec devbox-lite ping 8.8.8.8
```

If there are issues, configure DNS in docker-compose.yml:

```yaml
services:
  devbox-lite:
    dns:
      - 8.8.8.8
      - 8.8.4.4
```

---

<h2 id="database-issues" class="heading-with-back">
  <span>Database Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Database Container Won't Start

```powershell
docker ps -a
docker logs devbox-mysql
```

If the container is corrupted:

```powershell
docker rm -f devbox-mysql
docker volume rm devbox-mysql-data
# Then restart and recreate
```

---

### Cannot Connect to Database

Make sure you're using the correct hostname inside the container:

```bash
# Inside container - use container names
mysql -h devbox-mysql -u root
psql -h devbox-postgres -U postgres
redis-cli -h devbox-redis
```

From the host, use `localhost` with the mapped ports:

```powershell
# From PowerShell
mysql -h 127.0.0.1 -P 3307
```

### Laravel Migration Fails with Connection Refused

If you see `SQLSTATE[HY000] [2002] Connection refused` when running `php artisan migrate`:

**Cause:** The `.env` file uses `127.0.0.1` as `DB_HOST`, but inside Docker containers, services communicate via container names.

**Fix:** Update your Laravel `.env` file:

```env
DB_HOST=devbox-mysql    # NOT 127.0.0.1
```

---

<h2 id="volume-issues" class="heading-with-back">
  <span>Volume Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### Changes Not Saving

```powershell
docker volume ls
docker volume inspect devbox_workspace
```

If the issue persists:

```powershell
.\scripts\down
docker volume rm devbox_workspace
.\scripts\up
```

---

### Laravel Project Creation Fails Silently

If `laravel new` shows prompts but exits immediately after "Creating Laravel application...":

**Cause:** Old named volumes (`devbox_vendor-laravel`, `devbox_node-modules-laravel`) from a previous project are interfering.

**Fix:**

```powershell
# Stop container and remove volumes
.\scripts\down-v

# Start fresh
.\scripts\up

# Now create your project
.\scripts\shell
# Inside container:
laravel new my-app
```

---

### Named Volumes Stale After Project Delete

When you delete a project folder, the associated named volumes remain. To clean them up:

```powershell
# List all devbox volumes
docker volume ls | findstr devbox

# Remove specific volumes (stop container first)
.\scripts\down-v
docker volume rm devbox_vendor-laravel devbox_node-modules-laravel
.\scripts\up
```

---

<h2 id="docker-desktop-wont-start" class="heading-with-back">
  <span>Docker Desktop Won't Start</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

```powershell
Restart-Service com.docker.service
```

Or restart Docker Desktop from the Start menu.

---

<h2 id="wsl2-issues" class="heading-with-back">
  <span>WSL2 Issues</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

### WSL2 Not Installed

```powershell
wsl --install
```

Restart computer after installation.

### Docker Not Available in WSL2

**Option 1: Enable Docker Desktop WSL Integration (Recommended)**

1. Open Docker Desktop
2. Go to Settings → Resources → WSL Integration
3. Enable your Ubuntu distribution
4. Click "Apply & Restart"

**Option 2: Install Docker Natively in Ubuntu**

```bash
# Inside Ubuntu WSL2
sudo apt update && sudo apt install -y docker.io docker-compose-v2
sudo usermod -aG docker $USER
# Restart WSL
wsl --shutdown
```

Then reopen Ubuntu terminal.

### Slow Performance on Windows

If development is slow on Windows, switch to WSL2:

```bash
# Clone inside WSL2
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build
./scripts/up
./scripts/shell
```

### Permission Denied in WSL2

```bash
sudo chmod -R 777 ~/projects/DevBox
```

### Docker Build Slow in WSL2

If Docker build is slow in WSL2:

1. Check internet connection: `ping -c 4 8.8.8.8`
2. Try using a mirror registry
3. Ensure adequate resources (4GB+ RAM, 2+ CPU cores)
4. Check WSL2 memory limit in `.wslconfig`:

```ini
# %USERPROFILE%\.wslconfig
[wsl2]
memory=8GB
processors=4
```

### Cannot Access Windows Files from WSL2

Windows drives are mounted at `/mnt/`. For example:
- `C:\Users` → `/mnt/c/Users`
- `D:\Projects` → `/mnt/d/Projects`

For best performance, keep project files inside WSL2 filesystem (`~/projects/`), not on Windows drives.

---

<h2 id="github-authentication" class="heading-with-back">
  <span>GitHub Authentication</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

GitHub no longer supports password authentication for Git. You must use SSH keys or Personal Access Token.

### Option 1: SSH Key (Recommended)

**Step 1: Generate SSH key**
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

**Step 2: Copy public key**
```bash
cat ~/.ssh/id_ed25519.pub
```

**Step 3: Add key to GitHub**
1. Go to https://github.com/settings/keys
2. Click **"New SSH key"**
3. Paste the copied key
4. Click **"Add SSH key"**

**Step 4: Test connection**
```bash
ssh -T git@github.com
```

**Step 5: Clone with SSH**
```bash
git clone git@github.com:efmojtaba1/DevBox.git
```

### Option 2: Personal Access Token

**Step 1: Create token**
1. Go to https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Select scopes: `repo`, `read:org`
4. Click **"Generate token"**
5. Copy the token immediately

**Step 2: Clone with token**
```bash
git clone https://YOUR_TOKEN@github.com/efmojtaba1/DevBox.git
```

**Step 3: Cache credentials (optional)**
```bash
git config --global credential.helper store
```

---

<h2 id="useful-resources" class="heading-with-back">
  <span>Useful Resources</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/remote/containers)

---

<h2 id="related-documentation" class="heading-with-back">
  <span>Related Documentation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Development Guide](development.md) | DevBox development and maintenance |
