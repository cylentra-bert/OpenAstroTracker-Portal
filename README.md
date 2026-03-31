# OpenAstroTracker Portal

A single-script installer that sets up a unified web portal on a Raspberry Pi for controlling an OpenAstroTracker mount. Once installed, all tools are accessible from a browser on the same network — no separate ports or apps to remember.

## What it provides

| Path | Tool | Requires |
|------|------|----------|
| `/` | Landing page | nginx running |
| `/indi/` | INDI Web Manager device control | indi-web service running |
| `/pa/` | Polar alignment tool | oat-web-pa running on port 5000 |
| `/desktop/` | Remote desktop (KStars / PHD2) | Active graphical session; password-protected |

---

## Prerequisites

Before running the installer, the following must already be set up on the Raspberry Pi:

- **Raspberry Pi OS with Desktop** — 64-bit, Bookworm or later. The Lite (headless) image does not include a graphical environment and the remote desktop feature will not work.
- **[astro-soft-build](https://gitea.nouspiro.space/nou/astro-soft-build)** — provides INDI, KStars, and PHD2
- **[oat-web-pa](https://github.com/af7v/OpenAstroTracker-PA)** — provides the polar alignment tool on port 5000

---

## Installation

### 1. Set the Pi's hostname

The portal is accessed at `http://openastrotracker.local`. For this hostname to resolve, the Pi must be named `openastrotracker`. Set it now if you haven't already:

```bash
sudo hostnamectl set-hostname openastrotracker
```

Then update `/etc/hosts` so the system can resolve its own hostname. Open the file:

```bash
sudo nano /etc/hosts
```

Find the line with the old hostname (e.g. `raspberrypi`) and change it to `openastrotracker`:

```
127.0.1.1       openastrotracker
```

Save and exit. Without this step, `sudo` will print "unable to resolve host" warnings on every command.

Finally, restart avahi-daemon so the `.local` name is advertised:

```bash
sudo systemctl restart avahi-daemon
```

### 2. Clone and run the installer

Run as your normal desktop user — **not as root**. The script calls `sudo` internally:

```bash
git clone https://github.com/cylentra-bert/OpenAstroTracker-Portal.git
cd OpenAstroTracker-Portal
chmod +x install.sh uninstall.sh   # only needed if git didn't preserve the executable bit
./install.sh
```

### 3. Save the generated password

At the end of the install, a randomly generated password for `/desktop/` is printed along with the username (`openastrotracker`). **Save it immediately — it cannot be recovered after the terminal session ends.** If you lose it, re-run `install.sh` to generate a new one.

### What the installer does

1. Installs packages: `nginx`, `novnc`, `wayvnc`, `pipx`, `python3-venv`, `avahi-daemon`
2. Creates a Python virtual environment at `/opt/indiweb-venv/` and installs `indiweb`
3. Copies the landing page to `/opt/openastrotracker-portal/landing/`
4. Generates a random password and creates `/etc/nginx/.htpasswd-desktop` to protect `/desktop/`
5. Installs and enables the nginx site config; removes the default nginx site
6. Installs, enables, and starts three systemd services: `wayvnc`, `novnc`, `indi-web`
7. Enables `avahi-daemon` for `.local` hostname resolution

---

## After Installation

Open `http://openastrotracker.local` in a browser on the same network.

If that doesn't resolve, find the Pi's IP address with `hostname -I` on the Pi and use `http://<ip-address>` instead.

- `/pa/` requires `oat-web-pa` to be running separately. The portal does not start it.
- `/desktop/` requires an active graphical desktop session on the Pi. Use the remote desktop to open KStars, PHD2, and other tools.

---

## Networking

nginx listens on **port 80**. The portal is intended for use on a trusted local network only — it is HTTP with no TLS.

If you have enabled a firewall on the Pi (e.g., `ufw`), allow HTTP traffic:

```bash
sudo ufw allow 80/tcp
```

---

## Systemd Services

| Service | Description | Port |
|---------|-------------|------|
| `wayvnc` | Exports the Wayland desktop via VNC | 5900 |
| `novnc` | WebSocket proxy that bridges VNC to HTTP | 6080 |
| `indi-web` | INDI Web Manager | 8624 |

`novnc` depends on `wayvnc` — if wayvnc is not running, novnc will also be down.

`wayvnc` will enter a restart loop when no graphical session is active. This is normal — it retries every 5 seconds and starts working once someone logs in to the Pi's desktop.

Check service status:

```bash
sudo systemctl status wayvnc novnc indi-web
```

---

## Updating

Pull the latest changes and re-run the installer:

```bash
git -C OpenAstroTracker-Portal pull
./OpenAstroTracker-Portal/install.sh
```

Re-running the installer is safe. It updates packages, overwrites the nginx config and service files, and generates a **new** random password for `/desktop/` — the old password will stop working. All three services are restarted.

---

## Uninstall

```bash
./uninstall.sh
```

Stops and disables all three services, removes the nginx site, removes `/opt/openastrotracker-portal/` and `/opt/indiweb-venv/`, and re-enables the default nginx site if available. Packages installed via apt (`nginx`, `novnc`, `x11vnc`, etc.) are not removed — uninstall them manually if needed:

```bash
sudo apt remove nginx novnc wayvnc avahi-daemon apache2-utils
```

---

## Pitfalls

**Do not run as root.**
The installer detects the desktop user via `$SUDO_USER`. Running as root directly (e.g. `sudo su` then `./install.sh`) causes `$SUDO_USER` to be empty, which results in incorrect service files and `wayvnc`/`indi-web` failing at startup.

**`openastrotracker.local` won't work until the hostname is set.**
avahi-daemon publishes the Pi's system hostname. The default Raspberry Pi OS hostname is `raspberrypi`, not `openastrotracker`. See [Installation step 1](#1-set-the-pis-hostname).

**mDNS requires Bonjour on Windows.**
`.local` names resolve natively on Linux and macOS. On Windows, Bonjour must be installed (it comes with iTunes or Apple devices). Without it, use the Pi's IP address: `hostname -I` on the Pi.

**`/pa/` will return 502 if oat-web-pa is not running.**
The portal proxies `/pa/` to port 5000 but does not manage the oat-web-pa process.

**`/desktop/` requires a graphical session on the Pi.**
"Graphical session" means a user is logged in to the Pi's desktop environment. SSH sessions do not count. `wayvnc` attaches to the active Wayland session.

---

## Troubleshooting

**`openastrotracker.local` does not resolve**

Check that the hostname is set correctly and avahi is running:

```bash
hostname                          # should print: openastrotracker
sudo systemctl status avahi-daemon
```

On Windows, install Bonjour or connect by IP address.

**502 Bad Gateway on `/pa/`**

`oat-web-pa` is not running on port 5000:

```bash
sudo systemctl status oat-web-pa
```

**502 Bad Gateway on `/desktop/`**

Check both services — novnc depends on wayvnc:

```bash
sudo systemctl status wayvnc novnc
```

If wayvnc shows a restart loop, log in to the Pi's desktop graphically and it will stabilize.

**`/desktop/` login fails**

Username is `openastrotracker`. The password was printed at the end of install. To reset it, re-run `./install.sh` and save the new password.

**INDI Web Manager shows no drivers**

INDI driver XML files must be present at `/usr/share/indi/`. Verify `astro-soft-build` (or INDI packages) are installed:

```bash
ls /usr/share/indi/
```

**nginx fails to start**

```bash
sudo nginx -t
```

Common causes: port 80 is already in use, or the landing page directory is missing.
