#!/usr/bin/env bash
set -euo pipefail

echo "=== OpenAstroTracker Portal Uninstaller ==="

# Stop and remove services
sudo systemctl stop wayvnc x11vnc novnc indi-web 2>/dev/null || true
sudo systemctl disable wayvnc x11vnc novnc indi-web 2>/dev/null || true
sudo rm -f /etc/systemd/system/wayvnc.service \
           /etc/systemd/system/x11vnc.service \
           /etc/systemd/system/novnc.service \
           /etc/systemd/system/indi-web.service
sudo systemctl daemon-reload

# Remove nginx site
sudo rm -f /etc/nginx/sites-enabled/openastrotracker
sudo rm -f /etc/nginx/sites-available/openastrotracker
sudo rm -f /etc/nginx/.htpasswd-desktop
if [ -f /etc/nginx/sites-available/default ] && [ ! -L /etc/nginx/sites-enabled/default ]; then
    sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
if sudo nginx -t 2>/dev/null; then
    sudo systemctl restart nginx
else
    echo "WARNING: nginx configuration invalid after removal. Check /etc/nginx/sites-available/ manually." >&2
fi

# Remove installed files
sudo rm -rf /opt/openastrotracker-portal
sudo rm -rf /opt/indiweb-venv

echo "Uninstall complete."
