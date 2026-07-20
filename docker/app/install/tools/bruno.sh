#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Bruno API Client"

set -e

# Install dependencies (without novnc apt package - has broken deps)
# NOTE: apt-get update is done once before all tools in Dockerfile stage
apt-get install -y --no-install-recommends \
    libgtk-3-0 \
    libnotify4 \
    libnss3 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    libatspi2.0-0 \
    libuuid1 \
    libsecret-1-0 \
    libasound2t64 \
    libgbm1 \
    xvfb \
    x11vnc \
    websockify

# Download noVNC from GitHub (apt novnc has broken dependencies)
if [ ! -d /usr/share/novnc ]; then
    echo "Downloading noVNC..."
    git clone --depth 1 https://github.com/novnc/noVNC.git /usr/share/novnc 2>/dev/null
fi

# Create index.html redirect (noVNC repo has no index.html, causes directory listing)
if [ ! -f /usr/share/novnc/index.html ]; then
    cat > /usr/share/novnc/index.html << 'HTML'
<!DOCTYPE html>
<html>
<head><meta http-equiv="refresh" content="0;url=vnc_lite.html" /></head>
<body><p>Redirecting to <a href="vnc_lite.html">noVNC</a>...</p></body>
</html>
HTML
fi

# Read Bruno version from .env or use default
BRUNO_VERSION="${BRUNO_VERSION:-3.5.2}"
PREBUILT_DIR="/workspace/prebuilt/packages"

if [ -f "$PREBUILT_DIR/bruno_${BRUNO_VERSION}_amd64_linux.deb" ]; then
    echo "Using prebuilt Bruno package..."
    cp "$PREBUILT_DIR/bruno_${BRUNO_VERSION}_amd64_linux.deb" /tmp/bruno.deb
else
    echo "Downloading Bruno v${BRUNO_VERSION}..."
    wget -q "https://github.com/usebruno/bruno/releases/download/v${BRUNO_VERSION}/bruno_${BRUNO_VERSION}_amd64_linux.deb" -O /tmp/bruno.deb
fi

# Install Bruno
dpkg -i /tmp/bruno.deb 2>/dev/null || apt-get install -f -y
rm -f /tmp/bruno.deb

# NOTE: apt-get clean is done at stage end in cleanup.sh, not here

# Create launcher script
cat > /usr/local/bin/start-bruno << 'LAUNCHER'
#!/bin/bash

# Start Xvfb if not running
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    nohup Xvfb :1 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
    sleep 1
fi

export DISPLAY=:1

# Start VNC if not running
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    nohup x11vnc -display :1 -forever -nopw -rfbport 5900 -shared > /dev/null 2>&1 &
    sleep 1
fi

# Stop websockify on this port only (don't kill other tool's websockify)
fuser -k 6080/tcp 2>/dev/null || true
sleep 1

# Find noVNC web directory
NOVNC_DIR=""
for dir in /usr/share/novnc /usr/share/novnc/web; do
    [ -d "$dir" ] && NOVNC_DIR="$dir" && break
done
NOVNC_DIR="${NOVNC_DIR:-/usr/share/novnc}"

nohup websockify --web="$NOVNC_DIR" 6080 localhost:5900 > /dev/null 2>&1 &
sleep 1

# Launch Bruno (setsid detaches from exec session to prevent EPIPE)
setsid bash -c 'exec bruno --no-sandbox --ozone-platform=x11' > /dev/null 2>&1 < /dev/null &

echo ""
echo "========================================="
echo "Bruno is starting..."
echo "========================================="
echo "Access Bruno at: http://localhost:6080"
echo ""
LAUNCHER
chmod +x /usr/local/bin/start-bruno

echo "Bruno installed successfully."
bruno --version 2>/dev/null || echo "Bruno v${BRUNO_VERSION} installed"
