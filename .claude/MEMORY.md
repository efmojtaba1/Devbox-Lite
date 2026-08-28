# Memory index

- [Mojtaba (user profile)](user-mojtaba.md) — DevBox Lite author; replies in Farsi, pastes raw installer logs and expects fixes in `export.sh`.
- [WSL payload transport rule](devbox-wsl-payload-transport.md) — commands sent to `wsl.exe` must contain no `$` and no double quotes; why the Ubuntu user stage silently failed.
- ["Commit and push" workflow](feedback-commit-and-push.md) — I only `git add .` + commit and ask him to push; assume the previous commit was pushed.
- [Unattended import requirement](devbox-unattended-import.md) — only the Linux username/password may be asked; everything else automatic and auto-resumed after restart.
- [PowerShell native stderr trap](powershell-native-stderr-trap.md) — under `'Stop'`, native stderr kills the script even when redirected; wsl.exe must go through an EAP-relaxed guard.
- [Database container fix](devbox-fix-database-container-creation.md) — commit `c0c6ac2` fixes hanging at `[db] Ensuring database service running` and mysql client fallback.
- [Docker build diagnostics](dedbox-build-diagnostics.md) — commit `5a29b08` improves Docker daemon startup with debug info, 30s timeout, and dockerd fallback, addressing the `Could not connect to Docker daemon` error.
