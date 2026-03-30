#!/usr/bin/env bash
set -euo pipefail

echo "=== OpenAstroTracker Portal Uninstaller ==="

# Stop and remove services
sudo systemctl stop x11vnc novnc indi-web 2>/dev/null || true
sudo systemctl disable x11vnc novnc indi-web 2>/dev/null || true
sudo rm -f /etc/systemd/system/x11vnc.service \
           /etc/systemd/system/novnc.service \
           /etc/systemd/system/indi-web.service
sudo systemctl daemon-reload

# Remove nginx site
sudo rm -f /etc/nginx/sites-enabled/openastrotracker
sudo rm -f /etc/nginx/sites-available/openastrotracker
sudo systemctl restart nginx

# Remove installed files
sudo rm -rf /opt/openastrotracker-portal
sudo rm -rf /opt/indiweb-venv

echo "Uninstall complete."
