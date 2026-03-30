#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/openastrotracker-portal"
NGINX_SITE="/etc/nginx/sites-available/openastrotracker"
NGINX_ENABLED="/etc/nginx/sites-enabled/openastrotracker"
INDIWEB_VENV="/opt/indiweb-venv"

# Detect the desktop user (the user who invoked sudo, or current user)
PORTAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
PORTAL_HOME=$(getent passwd "$PORTAL_USER" | cut -d: -f6)
if [ -z "$PORTAL_HOME" ]; then
    echo "ERROR: Cannot determine home directory for user '$PORTAL_USER'." >&2
    exit 1
fi

echo "=== OpenAstroTracker Portal Installer ==="
echo ""

# 1. Install packages
echo "[1/8] Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y nginx novnc x11vnc pipx python3-venv avahi-daemon

# 2. Install INDI Web Manager into a dedicated venv (path used by indi-web.service)
echo "[2/8] Installing INDI Web Manager..."
sudo python3 -m venv "$INDIWEB_VENV"
sudo "$INDIWEB_VENV/bin/pip" install indiweb

# 3. Copy landing page
echo "[3/8] Installing landing page..."
sudo mkdir -p "$INSTALL_DIR/landing"
if [ ! -d "$REPO_DIR/landing" ] || [ -z "$(ls -A "$REPO_DIR/landing")" ]; then
    echo "ERROR: $REPO_DIR/landing is missing or empty." >&2
    exit 1
fi
sudo cp -r "$REPO_DIR/landing/." "$INSTALL_DIR/landing/"

# 4. Configure nginx
echo "[4/8] Configuring nginx..."
sudo cp "$REPO_DIR/nginx/openastrotracker.conf" "$NGINX_SITE"
if [ -f /etc/nginx/sites-enabled/default ]; then
    sudo rm /etc/nginx/sites-enabled/default
fi
if [ ! -L "$NGINX_ENABLED" ]; then
    sudo ln -s "$NGINX_SITE" "$NGINX_ENABLED"
fi
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# 5. Set up NoVNC access password
echo "[5/8] Setting up NoVNC access password..."
if ! command -v htpasswd &>/dev/null; then
    sudo apt-get install -y apache2-utils -qq
fi
DESKTOP_PASS=$(openssl rand -base64 12 | tr -d "=/+")
echo "openastrotracker:$(openssl passwd -apr1 "$DESKTOP_PASS")" | sudo tee /etc/nginx/.htpasswd-desktop > /dev/null
sudo chmod 640 /etc/nginx/.htpasswd-desktop

# 6. Install systemd services
echo "[6/8] Installing systemd service units..."
sudo cp "$REPO_DIR/services/novnc.service" /etc/systemd/system/
sudo cp "$REPO_DIR/services/indi-web.service" /etc/systemd/system/
# Generate x11vnc service with the detected desktop user
sed "s|User=pi|User=$PORTAL_USER|g; s|/home/pi|$PORTAL_HOME|g" \
    "$REPO_DIR/services/x11vnc.service" | sudo tee /etc/systemd/system/x11vnc.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable x11vnc novnc indi-web
sudo systemctl start x11vnc novnc indi-web

echo ""
echo "Checking service status..."
for svc in novnc indi-web; do
    if sudo systemctl is-active --quiet "$svc"; then
        echo "  ✓ $svc running"
    else
        echo "  ✗ $svc failed to start — check: sudo systemctl status $svc"
    fi
done
echo "  ℹ x11vnc requires an active desktop session (starts when you log in graphically)"

# 7. Enable avahi for .local hostname resolution
echo "[7/8] Enabling mDNS (avahi)..."
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 8. Done
echo "[8/8] Installation complete."
echo ""
echo "=== Portal ready ==="
echo ""
echo "  http://openastrotracker.local"
echo "  http://openastrotracker.local/pa/        Polar Alignment"
echo "  http://openastrotracker.local/desktop/   Remote Desktop (KStars / PHD2)"
echo "  http://openastrotracker.local/indi/      INDI Device Manager"
echo ""
echo "Desktop password (for /desktop/): $DESKTOP_PASS"
echo "Username: openastrotracker"
echo "Store this password somewhere safe — it cannot be recovered after install."
echo ""
echo "Note: oat-web-pa must be running for /pa/ to respond."
echo "Note: Start KStars before using /desktop/."
