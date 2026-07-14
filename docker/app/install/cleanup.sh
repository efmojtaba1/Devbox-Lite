#!/bin/bash

source "$(dirname "$0")/common.sh"

log "Cleaning up"

# Remove apt cache and lists
apt autoremove -y
apt clean
rm -rf /var/lib/apt/lists/*

# Remove temporary files
rm -rf /tmp/*

# Remove package manager caches
rm -rf /root/.cache/*
rm -rf /root/.npm/_cacache
rm -rf /root/.local/share/pip/cache
rm -rf /root/.cache/pip
rm -rf /root/.cargo/registry/cache
rm -rf /root/.rustup/toolchains/*/lib/rustlib/src
rm -rf /root/.cache/pipx
rm -rf /root/.gradle/caches
rm -rf /root/.m2/repository

# Remove Composer and Bun caches
rm -rf /root/.config/composer/cache 2>/dev/null || true
rm -rf /root/.bun/install/cache 2>/dev/null || true
rm -rf /root/.npm 2>/dev/null || true

# Remove system logs
rm -rf /var/log/* 2>/dev/null || true

# Remove documentation (saves significant space)
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/lintian/*
rm -rf /usr/share/linda/*
rm -rf /usr/share/locale/*

# Remove C/C++ development headers (only needed at compile time)
rm -rf /usr/include/* 2>/dev/null || true

# Remove static libraries
find /usr/lib -name '*.a' -delete 2>/dev/null || true
find /usr/lib/x86_64-linux-gnu -name '*.a' -delete 2>/dev/null || true

# Remove Java source files (not needed at runtime)
rm -rf /usr/lib/jvm/java-*/lib/src.zip 2>/dev/null || true

# Remove Python test suites (saves ~100MB)
rm -rf /usr/lib/python3*/test 2>/dev/null || true
rm -rf /usr/local/lib/python3*/dist-packages/*/tests 2>/dev/null || true

# Remove pip setuptools from system (we have it via pip)
rm -rf /usr/lib/python3/dist-packages/setuptools 2>/dev/null || true

# Remove Python __pycache__ and .pyc files (~158MB)
find /usr/local/lib/python3* -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find /usr/local/lib/python3* -name '*.pyc' -type f -delete 2>/dev/null || true
find /usr/lib/python3* -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find /usr/lib/python3* -name '*.pyc' -type f -delete 2>/dev/null || true

# Remove Python .dist-info (~14MB)
find /usr/local/lib/python3* -name '*.dist-info' -type d -exec rm -rf {} + 2>/dev/null || true

# Remove node.js documentation
rm -rf /usr/local/lib/node_modules/*/docs 2>/dev/null || true
rm -rf /usr/local/lib/node_modules/*/test 2>/dev/null || true

# Remove Postman unnecessary files (saves ~200MB)
rm -rf /opt/Postman/resources/*.pak 2>/dev/null || true
rm -rf /opt/Postman/resources/*.bin 2>/dev/null || true
rm -rf /opt/Postman/chrome-sandbox 2>/dev/null || true

# Remove Bruno unnecessary files
rm -rf /opt/Bruno/resources/*.pak 2>/dev/null || true

# Remove VNC related unnecessary files
rm -rf /usr/share/novnc/*.md 2>/dev/null || true

# Strip debug symbols from large binaries
for bin in trivy cosign prometheus promtool k9s skaffold jaeger kn kubectl helm sops pack faas-cli crane \
    gh docker docker-compose docker-buildx \
    mysql psql redis-cli \
    nginx supervisord pm2 \
    node npm pnpm bun php composer pip pipx; do
    if [ -f "/usr/local/bin/$bin" ]; then
        strip --strip-unneeded "/usr/local/bin/$bin" 2>/dev/null || true
    fi
    if [ -f "/usr/bin/$bin" ]; then
        strip --strip-unneeded "/usr/bin/$bin" 2>/dev/null || true
    fi
done

# Final cleanup
apt clean
rm -rf /var/lib/apt/lists/*
rm -rf /tmp/*
rm -rf /root/.cache/*

success "Cleanup completed"
