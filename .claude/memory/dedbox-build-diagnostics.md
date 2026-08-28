---
name: dedbox-build-diagnostics
description: Improve Docker daemon startup diagnostics and fallback in build.sh
metadata:
  type: project
  date: 2026-08-28
---

## DevBox Build Script Docker Diagnostics Fix

**Commits:** `5a29b08 fix(build): improve Docker daemon startup diagnostics and fallback`

### Problem Addressed:
The `build.sh` script would fail with "Could not connect to Docker daemon" without providing useful diagnostic information when Docker failed to start in Linux environments.

### Changes Made:

#### scripts/build.sh - Enhanced Docker startup logic:
- **Visible error output:** Removed `>/dev/null 2>&1` redirection to show actual error messages from `service docker start`
- **Fallback mechanism:** If `service docker start` fails, try launching `sudo dockerd` directly in background
- **Extended timeout:** Increased wait time from 10 seconds to 30 seconds for Docker daemon initialization
- **Comprehensive diagnostics:** On failure, show:
  - Docker binary location (`which docker`)
  - Dockerd binary location (`which dockerd`)
  - Docker socket existence (`ls -la /var/run/docker.sock`)
  - Service status output (`service docker status`)
- **Clear progress messaging:** Improved user feedback during startup attempts

### Impact:
- **Better troubleshooting:** Users can now see exactly why Docker failed to start
- **More robust startup:** Fallback to direct dockerd launch increases success chances
- **Longer patience:** 30-second timeout accommodates slower VM/container startup
- **Actionable diagnostics:** Error messages include specific commands to investigate further

### Files Modified:
- `scripts/build.sh` - Enhanced Docker daemon startup logic (19 insertions, 5 deletions)