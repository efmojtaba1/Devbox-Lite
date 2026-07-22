# Docker Commands Reference

**[فارسی](../fa/docker.md) | [Home](README.md)**

---

## Table of Contents

* [Basic Concepts](#basic-concepts)
* [Container Management](#container-management)
  * [Start Container](#start-container)
  * [Stop Container](#stop-container)
  * [Stop and Remove Volumes](#stop-and-remove-volumes)
  * [Open Terminal](#open-terminal)
  * [View Logs](#view-logs)
  * [Restart](#restart)
  * [Check Status](#check-status)
  * [Run Command Inside Container](#run-command-inside-container)
  * [Detect Project Types](#detect-project-types)
* [Image Commands](#image-commands)
  * [Build Image](#build-image)
  * [Rebuild (No Cache)](#rebuild-no-cache)
  * [List Images](#list-images)
  * [Remove Image](#remove-image)
* [Cleanup Commands](#cleanup-commands)
  * [Full Cleanup](#full-cleanup)
  * [Clean Cache](#clean-cache)
* [API Testing](#api-testing)
  * [Bruno](#bruno)
  * [Offline Usage](#offline-usage)
  * [Named Volumes](#named-volumes)
* [Troubleshooting](#troubleshooting)
  * [Container Won't Start](#container-wont-start)
  * [Port in Use](#port-in-use)
  * [Permission Issues](#permission-issues)
* [Important Notes](#important-notes)
* [Related Documentation](#related-documentation)

---

## Basic Concepts [🔝](#table-of-contents)

- **Image:** Template with OS and installed tools
- **Container:** Running instance of an Image
- **Volume:** Persistent data storage
- **Network:** Communication between containers (devbox-network)

---

## Container Management [🔝](#table-of-contents)

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

### Stop and Remove Volumes

**Windows:**

```powershell
.\scripts\down-v
```

**WSL2:**

```bash
./scripts/down-v.sh
```

> **Warning:** This removes ALL named volumes including Bruno collections, pnpm store, and cached dependencies.

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

## Image Commands [🔝](#table-of-contents)

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

## Cleanup Commands [🔝](#table-of-contents)

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

## API Testing [🔝](#table-of-contents)

### Bruno

```powershell
test-api bruno
```

Address: http://localhost:6080

### Offline Usage

1. Create collections in Bruno → export as JSON
2. Collections are saved to `workspace/data/bruno/collections/`
3. Collections work without internet

### Named Volumes

Bruno uses named Docker volumes for persistence:

- `bruno-config` → `/root/.config/bruno` (Electron preferences)
- `bruno-collections` → `/root/bruno` (API collections)

To backup Bruno data:

```bash
docker run --rm -v devbox_bruno-collections:/data:ro alpine tar czf /backup/bruno-collections.tar.gz -C /data .
```

---

## Troubleshooting [🔝](#table-of-contents)

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

## Important Notes [🔝](#table-of-contents)

1. Always use the management scripts
2. Stop the container before removing the image
3. Use `docker system prune` with caution
4. Check logs for troubleshooting

---

## Related Documentation [🔝](#table-of-contents)

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
