<div class="doc-nav-header">
  <h1>Docker Commands Reference</h1>
  <span class="lang-links">
    <strong><a href="../fa/docker.md">فارسی</a></strong> | <a href="README.md">Home</a>
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
<li><a href="#basic-concepts">Basic Concepts</a></li>
<li>
<details><summary><a href="#container-management">Container Management</a></summary>
<ul>
<li><a href="#start-container">Start Container</a></li>
<li><a href="#stop-container">Stop Container</a></li>
<li><a href="#stop-and-remove-volumes">Stop and Remove Volumes</a></li>
<li><a href="#open-terminal">Open Terminal</a></li>
<li><a href="#view-logs">View Logs</a></li>
<li><a href="#restart">Restart</a></li>
<li><a href="#check-status">Check Status</a></li>
<li><a href="#run-command-inside-container">Run Command Inside Container</a></li>
<li><a href="#detect-project-types">Detect Project Types</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#image-commands">Image Commands</a></summary>
<ul>
<li><a href="#build-image">Build Image</a></li>
<li><a href="#rebuild-no-cache">Rebuild (No Cache)</a></li>
<li><a href="#list-images">List Images</a></li>
<li><a href="#remove-image">Remove Image</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#cleanup-commands">Cleanup Commands</a></summary>
<ul>
<li><a href="#full-cleanup">Full Cleanup</a></li>
<li><a href="#clean-cache">Clean Cache</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#api-testing">API Testing</a></summary>
<ul>
<li><a href="#bruno">Bruno</a></li>
<li><a href="#offline-usage">Offline Usage</a></li>
<li><a href="#named-volumes">Named Volumes</a></li>
</ul>
</details>
</li>
<li>
<details><summary><a href="#troubleshooting">Troubleshooting</a></summary>
<ul>
<li><a href="#container-wont-start">Container Won't Start</a></li>
<li><a href="#port-in-use">Port in Use</a></li>
<li><a href="#permission-issues">Permission Issues</a></li>
</ul>
</details>
</li>
<li><a href="#important-notes">Important Notes</a></li>
<li><a href="#related-documentation">Related Documentation</a></li>
</ul>

---

<h2 id="basic-concepts" class="heading-with-back">
  <span>Basic Concepts</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

- **Image:** Template with OS and installed tools
- **Container:** Running instance of an Image
- **Volume:** Persistent data storage
- **Network:** Communication between containers (devbox-network)

---

<h2 id="container-management" class="heading-with-back">
  <span>Container Management</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="image-commands" class="heading-with-back">
  <span>Image Commands</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="cleanup-commands" class="heading-with-back">
  <span>Cleanup Commands</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="api-testing" class="heading-with-back">
  <span>API Testing</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="troubleshooting" class="heading-with-back">
  <span>Troubleshooting</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

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

<h2 id="important-notes" class="heading-with-back">
  <span>Important Notes</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

1. Always use the management scripts
2. Stop the container before removing the image
3. Use `docker system prune` with caution
4. Check logs for troubleshooting

---

<h2 id="related-documentation" class="heading-with-back">
  <span>Related Documentation</span>
  <a href="#table-of-contents" title="Back to Table of Contents" class="back-to-toc">🔝</a>
</h2>

| Document | Description |
|----------|-------------|
| [Usage Guide](usage.md) | Daily workflow and useful commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
