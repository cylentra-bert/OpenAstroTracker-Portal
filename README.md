# OpenAstroTracker-Portal

A web portal for the OpenAstroTracker — provides a unified browser-based interface for polar alignment, remote desktop (KStars/PHD2), and INDI device management on a Raspberry Pi.

## Prerequisites

- Raspberry Pi running 64-bit Raspberry Pi OS (Bookworm or later)
- [astro-soft-build](https://gitea.nouspiro.space/nou/astro-soft-build) installed (INDI, KStars, PHD2)
- [oat-web-pa](https://github.com/af7v/OpenAstroTracker-PA) installed

## Installation

```bash
git clone https://github.com/af7v/OpenAstroTracker-Portal.git
./OpenAstroTracker-Portal/install.sh
```

Access at: `http://openastrotracker.local`

## Services

| Path | Service |
|------|---------|
| `/` | Landing page |
| `/pa/` | Polar alignment tool |
| `/desktop/` | Remote desktop (KStars / PHD2) |
| `/indi/` | INDI device manager |
