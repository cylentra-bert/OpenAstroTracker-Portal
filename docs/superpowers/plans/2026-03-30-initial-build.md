# OpenAstroTracker-Portal Initial Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a web portal that provides a unified browser landing page routing to polar alignment, remote desktop (KStars/PHD2), and INDI device management on a Raspberry Pi running stock 64-bit Raspberry Pi OS.

**Architecture:** nginx acts as a reverse proxy and static file server at port 80, routing `/pa/` to the Flask OAT PA app, `/desktop/` to NoVNC, and `/indi/` to INDI Web Manager. x11vnc exposes the Pi's X display over VNC; NoVNC wraps that with a WebSocket proxy so any browser can connect. The Flask OAT PA app uses Socket.IO, which negotiates at `/socket.io/` (not under `/pa/`), so a dedicated nginx location handles that path. All services run as systemd units and start on boot.

**Tech Stack:** Bash (install script), nginx (reverse proxy + static hosting), systemd (service management), NoVNC + x11vnc (remote desktop), indiweb via pipx (INDI Web Manager), HTML/CSS (landing page — no frameworks)

---

## Context for Agentic Workers

This is a **deployment/installer project** targeting Raspberry Pi OS 64-bit (Debian Bookworm). Files in this repo are installed onto the Pi by `install.sh`. They are primarily config files (nginx, systemd) and shell scripts — not a compiled application.

**Assumptions when this plan runs:**
- Working directory is the repo root: `OpenAstroTracker-Portal/`
- `astro-soft-build` has already been run on the target Pi (INDI, KStars, PHD2 installed)
- `oat-web-pa` .deb has been installed on the Pi (its Flask app runs on port 5000)
- Default Pi username is `pi` (uid 1000) — adjust if different

**Important platform notes:**
- Developer is on Windows. Shell script syntax checks (`bash -n`) run locally.
- nginx, systemd, and service validation steps only work on the target Pi.
- `novnc` on Bookworm ships the launcher at `/usr/share/novnc/utils/launch.sh` (not `novnc_proxy`).
- `pip3 install` into system Python is blocked on Bookworm (PEP 668) — use `pipx`.
- `x11vnc` running as a system service needs `User=` and `XAUTHORITY` set to access the user X session.

**Testing strategy for infrastructure files:**
- Shell scripts: `bash -n <script>` for syntax check (runs on Windows/Linux)
- nginx config: `nginx -t` (Pi only, after install)
- systemd units: `systemd-analyze verify` (Pi only, after install)
- Landing page: open `landing/index.html` directly in a browser (Windows/Linux)

---

## File Map

| File | Responsibility |
|------|---------------|
| `install.sh` | Install packages, copy configs, enable+start all services |
| `uninstall.sh` | Remove configs, disable+stop all services |
| `nginx/openastrotracker.conf` | nginx site config — static landing + reverse proxies |
| `services/x11vnc.service` | systemd unit for x11vnc VNC server (port 5900) |
| `services/novnc.service` | systemd unit for NoVNC WebSocket proxy (port 6080) |
| `services/indi-web.service` | systemd unit for INDI Web Manager (port 8624) |
| `landing/index.html` | Static landing page with cards for each service |
| `landing/style.css` | Dark space-themed styles |

---

## Task 1: Landing Page HTML

**Files:**
- Create: `landing/index.html`

- [ ] **Step 1: Create landing/index.html**

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenAstroTracker</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <header>
        <h1>OpenAstroTracker</h1>
        <p class="subtitle">Raspberry Pi Control Panel</p>
    </header>
    <main>
        <div class="card-grid">
            <a href="/pa/" class="card">
                <div class="card-icon">&#9755;</div>
                <h2>Polar Alignment</h2>
                <p>Automated polar alignment using plate solving</p>
            </a>
            <a href="/desktop/" class="card">
                <div class="card-icon">&#9733;</div>
                <h2>Remote Desktop</h2>
                <p>KStars &amp; PHD2 — full imaging control</p>
            </a>
            <a href="/indi/" class="card">
                <div class="card-icon">&#9881;</div>
                <h2>INDI Devices</h2>
                <p>Start drivers and manage connected hardware</p>
            </a>
        </div>
    </main>
    <footer>
        <p>OpenAstroTracker Portal</p>
    </footer>
</body>
</html>
```

- [ ] **Step 2: Open landing/index.html in a browser to verify structure renders**

Expected: Three card links visible, header shows "OpenAstroTracker", no broken elements.

---

## Task 2: Landing Page CSS

**Files:**
- Create: `landing/style.css`

- [ ] **Step 1: Create landing/style.css**

```css
*, *::before, *::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

:root {
    --bg: #0d1117;
    --surface: #161b22;
    --border: #30363d;
    --text: #e6edf3;
    --text-muted: #8b949e;
    --accent: #58a6ff;
    --accent-hover: #79c0ff;
}

body {
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem 1rem;
}

header {
    text-align: center;
    margin-bottom: 3rem;
}

header h1 {
    font-size: 2rem;
    font-weight: 600;
    letter-spacing: 0.02em;
}

.subtitle {
    color: var(--text-muted);
    margin-top: 0.4rem;
    font-size: 0.95rem;
}

main {
    width: 100%;
    max-width: 760px;
}

.card-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
    gap: 1.25rem;
}

.card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1.75rem 1.5rem;
    text-decoration: none;
    color: inherit;
    transition: border-color 0.15s, transform 0.15s;
    display: flex;
    flex-direction: column;
    gap: 0.5rem;
}

.card:hover {
    border-color: var(--accent);
    transform: translateY(-2px);
}

.card-icon {
    font-size: 1.75rem;
    line-height: 1;
    margin-bottom: 0.25rem;
}

.card h2 {
    font-size: 1.05rem;
    font-weight: 600;
    color: var(--accent);
}

.card p {
    font-size: 0.85rem;
    color: var(--text-muted);
    line-height: 1.5;
}

footer {
    margin-top: auto;
    padding-top: 3rem;
    color: var(--text-muted);
    font-size: 0.8rem;
}
```

- [ ] **Step 2: Reload landing/index.html in browser**

Expected: Dark background (#0d1117), three cards with accent-colored headings, hover effect lifts cards slightly, responsive layout.

- [ ] **Step 3: Commit**

```bash
git add landing/
git commit -m "Add landing page with dark space theme"
```

---

## Task 3: nginx Configuration

**Files:**
- Create: `nginx/openastrotracker.conf`

**Context:** nginx runs on the Pi as a reverse proxy. This file goes in `/etc/nginx/sites-available/` and is symlinked to `/etc/nginx/sites-enabled/`. The default nginx site must be disabled first.

Port assignments:
- `5000` — OAT PA Flask app (oat-web-pa)
- `6080` — NoVNC WebSocket proxy
- `8624` — INDI Web Manager

**Socket.IO note:** The Flask OAT PA app uses Socket.IO. The client library calls `/socket.io/...` as an absolute path — it does NOT call `/pa/socket.io/...`. A separate location block at `/socket.io/` is required to forward these requests to port 5000. Without it, WebSocket connections for real-time status updates will 404.

**WebSocket Connection header note:** For the mixed HTTP+WebSocket `/pa/` location, the `Connection` header must be conditional (using an nginx map) so that normal HTTP requests get `Connection: close` and WebSocket upgrades get `Connection: upgrade`. Pure WebSocket tunnels (`/socket.io/`, `/desktop/`) can hardcode `"upgrade"`.

- [ ] **Step 1: Create nginx/openastrotracker.conf**

```nginx
# Conditionally set Connection header — required for mixed HTTP+WebSocket locations
map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Landing page — static files served directly by nginx
    root /opt/openastrotracker-portal/landing;
    index index.html;

    location = / {
        try_files /index.html =404;
    }

    # Polar Alignment tool (Flask app on port 5000)
    # Strips the /pa/ prefix before forwarding
    location /pa/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 86400;
    }

    # Socket.IO transport endpoint — absolute path used by socket.io client
    # Must proxy to the same Flask app as /pa/
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # NoVNC remote desktop (WebSocket proxy on port 6080)
    location /desktop/ {
        proxy_pass http://127.0.0.1:6080/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }

    # INDI Web Manager (HTTP only, port 8624)
    location /indi/ {
        proxy_pass http://127.0.0.1:8624/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

- [ ] **Step 2: Verify nginx syntax (Pi only — after install.sh has copied this file)**

```bash
sudo nginx -t
```

Expected: `nginx: configuration file /etc/nginx/nginx.conf syntax is ok`

- [ ] **Step 3: Commit**

```bash
git add nginx/
git commit -m "Add nginx reverse proxy config with Socket.IO support"
```

---

## Task 4: systemd Service Files

**Files:**
- Create: `services/x11vnc.service`
- Create: `services/novnc.service`
- Create: `services/indi-web.service`

**Context:**
- `x11vnc` exposes the running X display (`:0`) over VNC on port `5900`. It must run as the desktop user (`pi`, uid 1000) with access to the Xauthority file — not as root.
- `novnc` wraps port `5900` with a WebSocket proxy on port `6080`. On Bookworm, the launcher is `/usr/share/novnc/utils/launch.sh` (not `novnc_proxy`).
- `indi-web` is the INDI Web Manager Python process. It is installed via `pipx` into `/opt/indiweb-venv/` (see Task 5). It listens on port `8624`.

- [ ] **Step 1: Create services/x11vnc.service**

```ini
[Unit]
Description=x11vnc VNC server for display :0
After=graphical.target
Wants=graphical.target

[Service]
Type=simple
User=pi
Environment=XAUTHORITY=/home/pi/.Xauthority
Environment=DISPLAY=:0
ExecStart=/usr/bin/x11vnc -display :0 -nopw -listen localhost -xkb -ncache 10 -ncache_cr -forever
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
```

- [ ] **Step 2: Create services/novnc.service**

```ini
[Unit]
Description=NoVNC WebSocket proxy for VNC on :5900
After=x11vnc.service
Requires=x11vnc.service

[Service]
Type=simple
ExecStart=/usr/share/novnc/utils/launch.sh --listen 6080 --vnc localhost:5900
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical.target
```

- [ ] **Step 3: Create services/indi-web.service**

`indiweb` is installed via pipx into `/opt/indiweb-venv/bin/indi-web`. The `--xmldir` path points to the INDI driver XML files installed by `astro-soft-build`.

```ini
[Unit]
Description=INDI Web Manager
After=network.target

[Service]
Type=simple
ExecStart=/opt/indiweb-venv/bin/indi-web -p 8624 --xmldir /usr/share/indi
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 4: Verify service syntax (Pi only — after install.sh copies files to /etc/systemd/system/)**

```bash
systemd-analyze verify /etc/systemd/system/x11vnc.service
systemd-analyze verify /etc/systemd/system/novnc.service
systemd-analyze verify /etc/systemd/system/indi-web.service
```

Expected: No errors (warnings about missing units are acceptable).

- [ ] **Step 5: Commit**

```bash
git add services/
git commit -m "Add systemd service units for x11vnc, NoVNC, and INDI Web Manager"
```

---

## Task 5: Install and Uninstall Scripts

**Files:**
- Create: `install.sh`
- Create: `uninstall.sh`

**Context:** `install.sh` runs on the Pi as a regular user (uses `sudo` internally). It:
1. Installs packages: `nginx`, `novnc`, `x11vnc`, `pipx`, `avahi-daemon`
2. Installs `indiweb` via pipx into `/opt/indiweb-venv/` (deterministic path for service file)
3. Copies landing page to `/opt/openastrotracker-portal/landing/`
4. Installs and enables the nginx site config
5. Installs and enables systemd units for x11vnc, novnc, and indi-web
6. Starts all services
7. Enables avahi for `.local` mDNS
8. Prints the access URL

`avahi-daemon` provides mDNS so the Pi is reachable at `openastrotracker.local`.

- [ ] **Step 1: Create install.sh**

```bash
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
```

- [ ] **Step 2: Create uninstall.sh**

```bash
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
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x install.sh uninstall.sh
```

- [ ] **Step 4: Syntax check (runs on any OS with bash)**

```bash
bash -n install.sh
bash -n uninstall.sh
```

Expected: No output (clean exit = no syntax errors).

- [ ] **Step 5: Commit**

```bash
git add install.sh uninstall.sh
git commit -m "Add install and uninstall scripts"
```

---

## Task 6: Create GitHub Repo and Push

**Context:** Repo goes at `github.com/af7v/OpenAstroTracker-Portal`. Public repo.

**Branch strategy note:** The initial repo creation is an exception to the feature-branch rule in CONTRIBUTING.md. The initial scaffold commit goes directly to `main`. All future changes must use feature branches.

- [ ] **Step 1: Create GitHub repo via GitHub MCP tool**

Use `mcp__plugin_github_github__create_repository` with:
- `name`: `OpenAstroTracker-Portal`
- `description`: `Web portal for OpenAstroTracker — polar alignment, remote desktop, and INDI device management on Raspberry Pi`
- `private`: `false`
- `auto_init`: `false`

- [ ] **Step 2: Add remote and push**

```bash
git remote add origin https://github.com/af7v/OpenAstroTracker-Portal.git
git push -u origin main
```

Expected: Branch `main` pushed, all commits visible on GitHub.

---

## Post-Install Verification (on Pi)

After running `install.sh` on a Pi:

```bash
sudo systemctl status nginx       # Active (running)
sudo systemctl status x11vnc      # Active (running)
sudo systemctl status novnc       # Active (running)
sudo systemctl status indi-web    # Active (running)
```

Then in a browser:
1. `http://openastrotracker.local` — landing page loads with 3 cards
2. `http://openastrotracker.local/pa/` — OAT PA app loads (requires oat-web-pa running)
3. `http://openastrotracker.local/desktop/` — NoVNC connects (requires KStars open on Pi desktop)
4. `http://openastrotracker.local/indi/` — INDI Web Manager UI loads
