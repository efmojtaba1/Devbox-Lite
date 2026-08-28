---
name: devbox-fix-database-container-creation
description: Fix database container creation failures and improve MySQL client fallback handling
metadata:
  type: project
  date: 2026-08-28
---

## DevBox Database Container Creation Fix

**Commits:** `c0c6ac2 fix(new-project): handle db container creation failures and improve MySQL client fallback`

### Problem Addressed:
1. **Project creation hanging:** `new-project` script would hang indefinitely in offline mode when `db-manager.sh create` failed
2. **MySQL client error:** "mysql client is not available in the container" error when resetting databases

### Changes Made:

#### scripts/new-project.sh - ensure_container_running function:
- **Early return on failure:** Return immediately when `db-manager.sh create` fails (instead of continuing in wait loop)
- **Clear error messages:** Show `[error] Failed to create/start $kind container.` with proper exit codes
- **Retry progress:** Added `[retry] Waiting for $kind (attempt $attempt/$max_attempts)` messages for transparency
- **Longer health checks:** Increased sleep from 1s to 2s for more reliable container readiness detection
- **Early cleanup:** Return on skip to avoid unnecessary operations

#### scripts/new-project.sh - reset_mysql_database function:
- **Container-first approach:** Use `docker exec -i devbox-mysql` to access MySQL without requiring mysql binary in workspace container
- **Fallback strategy:** Only use local mysql client as last resort
- **Success feedback:** Clear `[ok] MySQL database '$db_name' reset via container client.` messages

#### scripts/new-project.sh - reset_postgres_database function:
- **Same container-first pattern:** Use `docker exec -i devbox-postgres` instead of requiring local psql client

### Impact:
- **Fixes hanging:** Project creation no longer hangs when database containers fail to start
- **Better error handling:** Clear error messages and immediate failure reporting
- **More robust:** Uses container's own database clients instead of requiring workspace clients
- **Improved visibility:** Progress messages show what's happening during database startup

### Files Modified:
- `scripts/new-project.sh` - Main fixes (72 insertions, 22 deletions)