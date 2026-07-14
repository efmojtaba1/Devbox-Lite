# Docker Commands Reference (DevBox Lite)

**[فارسی](../fa/docker.md)** | **[English](docker.md)** | [Home](../../README.md)

---

## Basic Concepts

- **Image:** Template with OS and installed tools
- **Container:** Running instance of an Image
- **Volume:** Persistent data storage (workspace/ folder)
- **Network:** Communication between containers (devbox-network)

---

## Management Commands

### Start Container

```powershell
.\scripts\up
```
Or:

```powershell
cd docker/compose
docker compose up -d
```

### Stop Container

```powershell
.\scripts\down
```
Or:

```powershell
cd docker/compose
docker compose down
```

### Open Terminal

```powershell
.\scripts\shell
```
Or:

```powershell
cd docker/compose
docker compose exec devbox-lite bash
```

### View Logs

```powershell
.\scripts\logs
```
Or:

```powershell
cd docker/compose
docker compose logs -f devbox-lite
```

### Restart

```powershell
.\scripts\restart
```
Or:

```powershell
cd docker/compose
docker compose restart devbox-lite
```

### Check Status

```powershell
.\scripts\status
```
Or:

```powershell
cd docker/compose
docker compose ps
```

---

## Image Commands

### Build Image

```powershell
.\scripts\build
```
Or:

```powershell
cd docker/compose
docker compose build
```

### Rebuild (No Cache)

```powershell
.\scripts\rebuild
```
Or:

```powershell
cd docker/compose
docker compose build --no-cache
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

```powershell
.\scripts\clean
```
Or:

```powershell
cd docker/compose
docker compose down
docker rmi devbox-lite
```

### Clean Cache

```bash
docker builder prune
docker system prune -a
```

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
