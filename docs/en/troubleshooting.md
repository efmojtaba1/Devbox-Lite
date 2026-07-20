# Troubleshooting Guide

**[فارسی](../fa/troubleshooting.md)** | [Home](../../README.md)

---

## Quick Fix

Most issues can be resolved with these steps:

```powershell
.\scripts\logs        # Check what's wrong
.\scripts\restart     # Try restarting
.\scripts\rebuild     # If still broken, rebuild
.\scripts\up          # Start again
```

If nothing works, restart Docker Desktop.

---

## Docker Issues

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

## Workspace Issues

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

## VS Code Issues

### VS Code Won't Connect to Container

1. Restart container: `.\scripts\restart`
2. In VS Code: F1 → "Dev Containers: Reopen in Container"

### Extensions Won't Install

```powershell
docker compose exec devbox-lite rm -rf /root/.vscode-server
```

Then restart VS Code.

---

## Tool Issues

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

## Network Issues

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

## Database Issues

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

---

## Volume Issues

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

## Docker Desktop Won't Start

```powershell
Restart-Service com.docker.service
```

Or restart Docker Desktop from the Start menu.

---

## WSL2 Issues

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

## GitHub Authentication

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

## Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/remote/containers)

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Docker Reference](docker.md) | Complete Docker commands |
| [Development Guide](development.md) | DevBox development and maintenance |
