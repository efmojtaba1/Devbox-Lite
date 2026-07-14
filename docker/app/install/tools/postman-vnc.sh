#!/bin/bash

source "$(dirname "$0")/../common.sh"

log "Installing Postman + VNC (noVNC)"

set -e

# Install X11, VNC, and noVNC
apt-get install -y --no-install-recommends \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    x11-xserver-utils \
    dbus-x11

# Install Postman (prebuilt or download)
PREBUILT_DIR="/workspace/prebuilt/packages"

if [ -f "$PREBUILT_DIR/postman-linux-x64.tar.gz" ]; then
    echo "Using prebuilt Postman package..."
    cp "$PREBUILT_DIR/postman-linux-x64.tar.gz" /tmp/postman.tar.gz
else
    echo "Downloading Postman..."
    wget -q "https://dl.pstmn.io/download/latest/linux64" -O /tmp/postman.tar.gz
fi

tar -xzf /tmp/postman.tar.gz -C /opt/
rm -f /tmp/postman.tar.gz

# Postman Electron files are required for proper operation

# Create noVNC index.html for auto-redirect
cat > /usr/share/novnc/index.html << 'INDEX'
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="refresh" content="0; url=vnc.html" />
</head>
<body>
    <p>Redirecting to <a href="vnc.html">noVNC</a>...</p>
</body>
</html>
INDEX

# Create startup script
cat > /usr/local/bin/start-postman << 'LAUNCHER'
#!/bin/bash

# Start Xvfb if not running
if ! pgrep -x Xvfb > /dev/null 2>&1; then
    nohup Xvfb :1 -screen 0 1280x720x24 -nolisten tcp > /dev/null 2>&1 &
    sleep 1
fi

export DISPLAY=:1

# Start VNC if not running
if ! pgrep -x x11vnc > /dev/null 2>&1; then
    nohup x11vnc -forever -nopw -rfbport 5900 -shared > /dev/null 2>&1 &
    sleep 1
fi

# Stop old websockify and restart fresh
pkill -f websockify 2>/dev/null || true
sleep 1
nohup websockify --web=/usr/share/novnc 6080 localhost:5900 > /dev/null 2>&1 &
sleep 1

# Launch Postman (setsid detaches from exec session to prevent EPIPE)
setsid bash -c 'exec /opt/Postman/Postman' > /dev/null 2>&1 < /dev/null &

echo ""
echo "========================================="
echo "Postman is starting..."
echo "========================================="
echo "Access Postman at: http://localhost:6080"
echo ""
LAUNCHER
chmod +x /usr/local/bin/start-postman

echo "Postman + VNC installed successfully."
