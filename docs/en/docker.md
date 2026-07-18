# Docker Commands Reference

**[فارسی](../fa/docker.md)** | [Home](../../README.md)

---

## Basic Concepts

- **Image:** Template with OS and installed tools
- **Container:** Running instance of an Image
- **Volume:** Persistent data storage
- **Network:** Communication between containers (devbox-network)

---

## Container Management

### Start Container

**Windows:**
```powershell
.\scripts\up
```

**WSL2:**
```bash
./scripts/up
```

Or directly:
```bash
cd docker/compose
docker compose up -d
```

### Stop Container

**Windows:**
```powershell
.\scripts\down
```

**WSL2:**
```bash
./scripts/down
```

### Open Terminal

**Windows:**
```powershell
.\scripts\shell
```

**WSL2:**
```bash
./scripts/shell
```

### View Logs

**Windows:**
```powershell
.\scripts\logs
```

**WSL2:**
```bash
./scripts/logs
```

### Restart

**Windows:**
```powershell
.\scripts\restart
```

**WSL2:**
```bash
./scripts/restart
```

### Check Status

**Windows:**
```powershell
.\scripts\status
```

**WSL2:**
```bash
./scripts/status
```

### Run Command Inside Container

```powershell
run <command>
```

Examples:
```powershell
run pnpm create next-app my-app
run php artisan serve
```

### Detect Project Types

```powershell
scan
```

---

## Image Commands

### Build Image

**Windows:**
```powershell
.\scripts\build
```

**WSL2:**
```bash
./scripts/build
```

### Rebuild (No Cache)

**Windows:**
```powershell
.\scripts\rebuild
```

**WSL2:**
```bash
./scripts/rebuild
```

### List Images

```bash
docker images
```

### Remove Image

```bash
docker rmi devbox-lite
```

---

## Cleanup Commands

### Full Cleanup

**Windows:**
```powershell
.\scripts\clean
```

**WSL2:**
```bash
./scripts/clean
```

### Clean Cache

```bash
docker builder prune
docker system prune -a
```

---

## API Testing

### Bruno

```powershell
test-api bruno
```

Address: http://localhost:6080

### Offline Usage

1. Create collections in Bruno → export as JSON
2. Collections are saved to `workspace/data/bruno/collections/`
3. Collections work without internet

---

## Troubleshooting

### Container Won't Start

```powershell
.\scripts\logs
```

Or:
```powershell
cd docker/compose
docker compose logs devbox-lite
```

### Port in Use

```powershell
netstat -ano | findstr :8000
taskkill /PID <PID> /F
```

### Permission Issues

```powershell
docker compose exec devbox-lite chmod -R 777 /workspace
```

---

## Important Notes

1. Always use the management scripts
2. Stop the container before removing the image
3. Use `docker system prune` with caution
4. Check logs for troubleshooting

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
