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
# Reject usernames or home paths that would break sed substitution
if ! printf '%s' "$PORTAL_USER" | grep -qE '^[a-zA-Z0-9._-]+$'; then
    echo "ERROR: Username '$PORTAL_USER' contains unsupported characters." >&2
    exit 1
fi
if ! printf '%s' "$PORTAL_HOME" | grep -qE '^[a-zA-Z0-9/._-]+$'; then
    echo "ERROR: Home directory '$PORTAL_HOME' contains unsupported characters." >&2
    exit 1
fi

echo "=== OpenAstroTracker Portal Installer ==="
echo ""

# 1. Install packages
echo "[1/8] Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y nginx novnc wayvnc pipx python3-venv avahi-daemon

# 2. Install INDI Web Manager into a dedicated venv (path used by indi-web.service)
echo "[2/8] Installing INDI Web Manager..."
sudo python3 -m venv "$INDIWEB_VENV"
sudo "$INDIWEB_VENV/bin/pip" install indiweb legacy-cgi

# 3. Copy landing page
echo "[3/8] Installing landing page..."
sudo mkdir -p "$INSTALL_DIR/landing"
if [ ! -d "$REPO_DIR/landing" ] || [ -z "$(ls -A "$REPO_DIR/landing")" ]; then
    echo "ERROR: $REPO_DIR/landing is missing or empty." >&2
    exit 1
fi
sudo cp -r "$REPO_DIR/landing/." "$INSTALL_DIR/landing/"

# 4. Set up NoVNC access password (must exist before nginx -t references it)
echo "[4/8] Setting up NoVNC access password..."
if ! command -v htpasswd &>/dev/null; then
    echo "  Installing apache2-utils for htpasswd..."
    sudo apt-get install -y apache2-utils
fi
DESKTOP_PASS=$(openssl rand -base64 12 | tr -d "=/+")
if [ -z "$DESKTOP_PASS" ]; then
    echo "ERROR: Failed to generate desktop access password." >&2
    exit 1
fi
if [ -f /etc/nginx/.htpasswd-desktop ]; then
    if ! printf '%s\n' "$DESKTOP_PASS" | sudo htpasswd -i /etc/nginx/.htpasswd-desktop openastrotracker > /dev/null; then
        echo "ERROR: Failed to update /etc/nginx/.htpasswd-desktop." >&2
        exit 1
    fi
else
    if ! printf '%s\n' "$DESKTOP_PASS" | sudo htpasswd -i -c /etc/nginx/.htpasswd-desktop openastrotracker > /dev/null; then
        echo "ERROR: Failed to create /etc/nginx/.htpasswd-desktop." >&2
        sudo rm -f /etc/nginx/.htpasswd-desktop
        exit 1
    fi
fi
sudo chmod 644 /etc/nginx/.htpasswd-desktop

# 5. Configure nginx
echo "[5/8] Configuring nginx..."
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

# 6. Install systemd services
echo "[6/8] Installing systemd service units..."
sudo cp "$REPO_DIR/services/novnc.service" /etc/systemd/system/
# Generate wayvnc and indi-web services with the detected desktop user
# Escape user/home values so sed replacements are safe against & / \ in the strings
ESCAPED_USER=$(printf '%s\n' "$PORTAL_USER" | sed 's/[\\&]/\\&/g')
PORTAL_UID=$(id -u "$PORTAL_USER") || { echo "ERROR: Cannot determine UID for user '$PORTAL_USER'." >&2; exit 1; }
sed "s|User=pi|User=$ESCAPED_USER|g; s|/run/user/1000|/run/user/$PORTAL_UID|g" \
    "$REPO_DIR/services/wayvnc.service" | sudo tee /etc/systemd/system/wayvnc.service > /dev/null
sed "s|User=pi|User=$ESCAPED_USER|g" \
    "$REPO_DIR/services/indi-web.service" | sudo tee /etc/systemd/system/indi-web.service > /dev/null
# Remove old x11vnc service if present
if systemctl is-active --quiet x11vnc 2>/dev/null || systemctl is-enabled --quiet x11vnc 2>/dev/null; then
    sudo systemctl stop x11vnc 2>/dev/null || true
    sudo systemctl disable x11vnc 2>/dev/null || true
    sudo rm -f /etc/systemd/system/x11vnc.service
fi
sudo systemctl daemon-reload
sudo systemctl enable wayvnc novnc indi-web
sudo systemctl start wayvnc novnc indi-web

echo ""
echo "Checking service status..."
for svc in wayvnc novnc indi-web; do
    if sudo systemctl is-active --quiet "$svc"; then
        echo "  ✓ $svc running"
    else
        echo "  ✗ $svc failed to start — check: sudo systemctl status $svc"
    fi
done

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
echo "Note: /desktop/ shows the Pi's graphical desktop — use it to open KStars, PHD2, etc."
