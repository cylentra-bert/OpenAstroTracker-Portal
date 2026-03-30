#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/opt/openastrotracker-portal"
NGINX_SITE="/etc/nginx/sites-available/openastrotracker"
NGINX_ENABLED="/etc/nginx/sites-enabled/openastrotracker"
INDIWEB_VENV="/opt/indiweb-venv"

echo "=== OpenAstroTracker Portal Installer ==="
echo ""

# 1. Install packages
echo "[1/7] Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y nginx novnc x11vnc pipx avahi-daemon

# 2. Install INDI Web Manager into a dedicated venv (path used by indi-web.service)
echo "[2/7] Installing INDI Web Manager..."
sudo python3 -m venv "$INDIWEB_VENV"
sudo "$INDIWEB_VENV/bin/pip" install --quiet indiweb

# 3. Copy landing page
echo "[3/7] Installing landing page..."
sudo mkdir -p "$INSTALL_DIR/landing"
sudo cp -r "$REPO_DIR/landing/"* "$INSTALL_DIR/landing/"

# 4. Configure nginx
echo "[4/7] Configuring nginx..."
sudo cp "$REPO_DIR/nginx/openastrotracker.conf" "$NGINX_SITE"
[ -f /etc/nginx/sites-enabled/default ] && sudo rm /etc/nginx/sites-enabled/default
[ ! -L "$NGINX_ENABLED" ] && sudo ln -s "$NGINX_SITE" "$NGINX_ENABLED"
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# 5. Install systemd services
echo "[5/7] Installing systemd service units..."
sudo cp "$REPO_DIR/services/x11vnc.service" /etc/systemd/system/
sudo cp "$REPO_DIR/services/novnc.service" /etc/systemd/system/
sudo cp "$REPO_DIR/services/indi-web.service" /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable x11vnc novnc indi-web
sudo systemctl start x11vnc novnc indi-web

# 6. Enable avahi for .local hostname resolution
echo "[6/7] Enabling mDNS (avahi)..."
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# 7. Done
echo "[7/7] Installation complete."
echo ""
echo "=== Portal ready ==="
echo ""
echo "  http://openastrotracker.local"
echo "  http://openastrotracker.local/pa/        Polar Alignment"
echo "  http://openastrotracker.local/desktop/   Remote Desktop (KStars / PHD2)"
echo "  http://openastrotracker.local/indi/      INDI Device Manager"
echo ""
echo "Note: oat-web-pa must be running for /pa/ to respond."
echo "Note: Start KStars before using /desktop/."
