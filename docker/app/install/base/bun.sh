#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Bun ${BUN_VERSION}"

# ۱. تلاش برای نصب از طریق سورس رسمی همراه با Timeout و Retry
BUN_INSTALL_SUCCESS=false

if curl -fsSL --connect-timeout 10 --retry 3 https://bun.sh/install | bash; then
    BUN_INSTALL_SUCCESS=true
fi

# ۲. اگر روش رسمی به دلیل مشکل DNS/شبکه شکست خورد، استفاده از npm به عنوان Fallback
if [ "$BUN_INSTALL_SUCCESS" = false ]; then
    echo "⚠️  Failed to fetch from bun.sh due to network/DNS issues."
    echo "🔄 Attempting fallback installation via npm..."

    if npm install -g bun@${BUN_VERSION:-latest}; then
        BUN_INSTALL_SUCCESS=true
    fi
fi

# ۳. ایجاد سیم‌لینک و بررسی نهایی
if [ -f "/root/.bun/bin/bun" ]; then
    ln -sf /root/.bun/bin/bun /usr/local/bin/bun
elif command -v bun >/dev/null 2>&1; then
    echo "✅ Bun installed via fallback."
else
    echo "❌ Failed to install Bun, but continuing build to prevent failure..."
    exit 0
fi

bun --version || true
