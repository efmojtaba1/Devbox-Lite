# Troubleshooting Guide (DevBox Lite)

**[فارسی](../fa/troubleshooting.md)** | [Home](../../README.md)

---

## Quick Troubleshooting

- Check logs:
```powershell
.\scripts\logs
```
- Check container status:
```powershell
.\scripts\status
```
- Restart container:
```powershell
.\scripts\restart
```

- Restart Docker Desktop

---

## Docker Issues

### Container Won't Start

**Solution:**

```powershell
.\scripts\logs
```

If you see errors:

```powershell
.\scripts\rebuild
.\scripts\up
```

---

### Port in Use

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

## VS Code Issues

### VS Code Won't Connect to Container

1. Restart container: `.\scripts\restart`
2. In VS Code: F1 → "Dev Containers: Reopen in Container"

### Extensions Won't Install

```powershell
docker compose exec devbox-lite rm -rf /root/.vscode-server
```

Then restart VS Code

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

This is a pnpm 10+ security feature. DevBox pre-configures `dangerouslyAllowAllBuilds: true` in the global config, so this should not happen after rebuild.

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

## Volume Issues

### Changes Not Saving

```powershell
docker volume ls
docker volume inspect devbox_workspace
docker compose exec devbox-lite chmod -R 777 /workspace
```

If the issue persists:

```powershell
.\scripts\down
docker volume rm devbox_workspace
.\scripts\up
```

---

## Docker Desktop Won't Start

```powershell
Restart-Service com.docker.service
```

Or restart Docker Desktop from the Start menu

---

## WSL2 Issues

### WSL2 Not Installed

```powershell
wsl --install
```

Restart computer after installation.

### Docker Not Available in WSL2

```bash
# Inside WSL2
sudo service docker start
# Or install Docker CLI
sudo apt install docker.io
```

### Slow Performance on Windows

If development is slow on Windows, switch to WSL2:

```bash
# Clone inside WSL2
git clone https://github.com/efmojtaba1/DevBox.git ~/projects/DevBox
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/build
./scripts/up
```

### Permission Denied in WSL2

```bash
sudo chmod -R 777 ~/projects/DevBox
```

---

## GitHub Authentication

GitHub no longer supports password authentication for Git. You must use SSH keys or Personal Access Token.

### Option 1: SSH Key (Recommended)

**Step 1: Generate SSH key**
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```
Press Enter to accept default location and empty passphrase.

**Step 2: Copy public key**
```bash
cat ~/.ssh/id_ed25519.pub
```
Copy the entire output.

**Step 3: Add key to GitHub**
1. Go to https://github.com/settings/keys
2. Click **"New SSH key"**
3. Paste the copied key
4. Click **"Add SSH key"**

**Step 4: Test connection**
```bash
ssh -T git@github.com
```
If you see "Hi username! You've successfully authenticated...", it's working.

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
