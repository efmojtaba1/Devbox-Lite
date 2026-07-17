# Daily Usage Guide (DevBox Lite)

**[فارسی](../fa/usage.md)** | [Home](../../README.md)

---

## Main Workflow

1. Open Docker Desktop
2. Open the Docker Desktop terminal
3. Start the container:

```powershell
.\scripts\up
```
   - If using Docker Desktop GUI:
   - Go to Images section and click ▶ to create a container from the DevBox image
   - Then go to Containers section and click ▶ to start the container

4. Open VS Code and connect to the container via Remote Explorer

### WSL2 (Recommended for better performance)

```bash
# Inside WSL2
cd ~/projects/DevBox
echo "WORKSPACE_PATH=$PWD" > .env
./scripts/up
./scripts/shell
```


---

## Management Scripts

The `.vscode` folder in the project root contains configuration and scripts that simplify container commands in the VS Code integrated terminal.

With these settings, instead of typing full paths like `scripts\up.ps1`, developers can type shortcut commands like `up`, `shell`, etc. directly in the VS Code terminal.



| Command | Description |
|---------|-------------|
| `up` | Start the container |
| `down` | Stop the container |
| `shell` | Open container terminal |
| `logs` | View logs |
| `restart` | Restart the container |
| `status` | Check status |
| `build` | Build the image |
| `rebuild` | Rebuild the image |
| `clean` | Remove image and containers |
| `setup-deps` | Auto-setup project dependencies |
| `test-api` | API testing tools (Bruno) |
| `run` | Run arbitrary command inside the container |
| `scan` | Detect project types in workspace |

---

## Creating New Projects

> **Important:** All development commands run **inside the container**. Use `run` for single commands or `shell` for an interactive terminal.

### Using `run` (single commands)

```powershell
run pnpm create next-app my-app
run composer install
run python3 -m venv my-env
```

### Using `shell` (interactive terminal)

```powershell
shell
# Now inside the container:
cd /workspace
```

### Laravel

```bash
cd /workspace
laravel new my-app
cd my-app
composer install
npm install
php artisan serve --host=0.0.0.0 --port=8000
```

### Next.js / React

```bash
cd /workspace
pnpm create next-app my-app
cd my-app
pnpm install
pnpm dev --hostname 0.0.0.0 --port=3000
```

### Python

```bash
cd /workspace
python3 -m venv my-env
source my-env/bin/activate
pip install flask
```

---

## Database Management

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

## Connecting VS Code to Container

1. Open VS Code
2. Select Remote Explorer → Dev Containers
3. Click **"+"** and select the project path
4. VS Code will automatically detect and connect to the container

---

## Default Ports

| Database | Port | Container Name |
|----------|------|----------------|
| MySQL | 3307 | devbox-mysql |
| PostgreSQL | 5433 | devbox-postgres |
| Redis | 6380 | devbox-redis |
| MongoDB | 27017 | devbox-mongo |
| MariaDB | 3308 | devbox-mariadb |
| phpMyAdmin | 8081 | - |
| Adminer | 8082 | - |
| pgAdmin | 8083 | - |

---

## Connecting from Inside Container

```bash
# PostgreSQL
psql -h devbox-postgres -p 5432

# MySQL
mysql -h devbox-mysql -P 3306

# Redis
redis-cli -h devbox-redis -p 6379
```

---

## API Testing

### Bruno (Lightweight, Fast)

```powershell
# From PowerShell
test-api bruno

# Inside container
bruno
```

Bruno opens at http://localhost:6080

### Offline Usage

1. Create collections in Bruno
2. Export collections as JSON
3. Collections work without internet

---

## Tool Version Selection

Tool versions are controlled by `docker/app/.env`:

```bash
PHP_VERSION=8.4
NODE_VERSION=22
PYTHON_VERSION=3.12
```

To change versions, edit the values and rebuild the image:

```powershell
.\scripts\build
```

---

## Important Notes

1. Place projects in the `workspace/` folder
2. Use VS Code Dev Containers
3. Regularly backup your projects
4. If you encounter issues, check [Troubleshooting](troubleshooting.md)

---

## Related Documentation

| Document | Description |
|----------|-------------|
| [Docker Reference](docker.md) | Complete Docker commands |
| [Troubleshooting](troubleshooting.md) | Common issues and fixes |
| [Development Guide](development.md) | DevBox development and maintenance |
