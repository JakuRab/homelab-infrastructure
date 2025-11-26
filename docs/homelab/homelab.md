# Rabalski Homelab — Architecture & Runbook (English)

> **Purpose:** This document gives AI agents and human operators an exact, end‑to‑end picture of the homelab: hardware, networks, DNS/cert model, reverse proxying, containers, data layout, and a step‑by‑step migration plan to the **Supermicro CSE‑216 + X10** platform.

---

## 1) High‑level goals & principles

- **Single entrypoint** via Caddy reverse proxy with TLS (Cloudflare DNS‑01).  
- **Private‑by‑default access:** allow **LAN + Tailscale**; block the public Internet unless explicitly opened.  
- **Predictable DNS** internally (AdGuard rewrites) and externally (Cloudflare).  
- **Composable services** (Docker), each on the shared network `caddy_net`.  
- **Data lives outside containers**; clear bind/volume separation and backup points.  
- **Idempotent runbooks**: every action documented as a small, safe scriptable sequence.

---

## 2) Physical & host layout

**Current edge & hosts**

- **ISP CPE** (Arris) → bridged/limited features.
- **TP‑Link Archer AX55 Pro** (main router): DHCP, static lease for servers:
  -`clockworkcity` → `192.168.1.10`.
  -`narsis` → `192.168.1.11`.
  -`Almalexia (main pc)` → `192.168.1.20`
  -`EPSONB2S2E9` → `192.168.1.201`
  -`MikroTik` → `192.168.1.2`  

- **Server `clockworkcity` (Ubuntu 24.04.3 LTS x86)**:
  - NIC: `enp4s0` (LAN `192.168.1.10/24`).
  - **Tailscale**: `100.98.21.87` (`clockworkcity.tail7d1f88.ts.net`).
  - Docker networks (bridges): `caddy_net` (external), app‑specific bridges.
  - **Disks**:
    - NVMe (OS + root LV).
    - HDD `sda1` **storage** (was `/mnt/hdd`).
    - SSD `sdb1` **NC_SSD** → **Nextcloud data** at `/mnt/ncdata` (active).  

- **Main PC `Almalexia` (OpenSuse Tumbleweed)**:
  - Shell: `zsh`
  - Terminal: `ghostty`
  - Desktop Enviroments: `Hyprland (wayland, primary)`, `Plasma (wayland, secondary)`

- **Server `narsis` (Debian 13 Trixie x86_64)**:
  - NIC: `eno1` (LAN `192.168.1.11/24`), `eno2` (available).
  - **Tailscale**: `100.87.23.43` (`narsis.tail7d1f88.ts.net`, IPv6: `fd7a:115c:a1e0::a037:172b`).
  - Docker networks (bridges): `caddy_net` (external), service-specific bridges.
  - **Disks**:
    - Boot: 120GB SATA SSD (internal, OS only, `/var` moved to `/home` partition for Docker temp operations).
    - Docker: 480GB NVMe M.2 at `/mnt/nvme` (containers + service data).
    - Storage: 24× 2.5" hot-swap bays (available for media/data).
  - **Portainer**: `https://192.168.1.11:9443`
  - **IPMI**: Web accessible (credentials reset).
  - **Services**: 10 migrated services running (see §15.7 Migration Summary).

**Planned platforms**

- **Media Server** (`narsis` — now deployed, see above):
  - **Hostname**: `narsis`
  - **IP Address**: `192.168.1.11` (static DHCP reservation)
  - **OS**: Debian 13 (Trixie)
  - Case: **Supermicro CSE‑216** with BPN‑SAS3‑216EL1 backplane (24× 2.5" bays).
  - CPU: **Xeon E5‑2660 v4** (14‑core, 28 threads, Broadwell‑EP, **no iGPU**).
  - Mainboard: **Supermicro X10SRL‑F** (LGA2011‑3, IPMI 2.0 with dedicated NIC).
  - RAM: 32 GB (2× 16 GB DDR4 RDIMM ECC), expandable to 512 GB.
  - Storage:
    - **OS Boot**: 120GB SATA SSD (internal, powered via SATA power connector, ~10-20GB used).
    - **Docker Data**: 480GB NVMe M.2 SSD on PCIe adapter (ext4, mounted at `/mnt/nvme`).
    - **Future Storage**: 24× 2.5" hot-swap bays available for media/data drives.
  - HBA: **LSI SAS3008** (AOC‑S3008L‑L8e, IT mode, 8‑port, 12 Gb/s SAS3).
  - GPU: **NVIDIA Quadro T400/T600** — incoming (hardware transcoding, NVENC).
  - Network: Dual embedded Intel GbE (`igb` driver, `eno1`/`eno2`) + IPMI dedicated port.
  - IPMI: Web accessible, credentials reset via `ipmitool`, fan control set to "Optimal".
  - Fans: Replaced UltraFlo server fans with Arctic P8 Silent (quiet operation).
  - **Docker**: v29.0.4, data root at `/mnt/nvme/docker`.
  - **Portainer**: Deployed, accessible at `https://192.168.1.11:9443`.
  - **Shell**: zsh with Starship prompt (Catppuccin Macchiato theme).

- **Storage Server** (ZFS/bulk data):
  - Case: **Supermicro CSE‑826E16‑R1200LPB** (12× 3.5" bays, redundant 1200W PSU).
  - CPU: **Xeon E3‑1220L** (Sandy Bridge, low‑power, no iGPU).
  - Mainboard: **Supermicro X9SCL** (LGA1155, IPMI 2.0 with dedicated NIC).
  - RAM: 24 GB (3× 8 GB DDR3 UDIMM ECC).
  - Storage: SATA SSD (OS), M.2 NVMe on PCIe adapter (L2ARC/SLOG cache for ZFS).
  - HBA: **LSI SAS3008** (AOC‑S3008L‑L8e, IT mode) — incoming.
  - Network: Quad embedded Intel GbE + IPMI dedicated port.

- **Deployment plan**: Apps migrate in phases from `clockworkcity` (see §15).

**Media Server Boot & Access Notes**

Hardware setup and lessons learned during initial deployment:

1. **Video Output (No iGPU)**
   - CPU has no integrated graphics
   - Must use **native VGA cable** (VGA-to-HDMI adapters often fail during BIOS/POST)
   - IPMI KVM-over-IP is the recommended access method once configured

2. **IPMI Access**
   - Default IP: `192.168.1.100` (DHCP enabled by default)
   - Check router DHCP leases for actual IP (look for "SUPERMICRO" hostname)
   - IPMI MAC address label: Located on motherboard near IPMI port
   - Default credentials (`ADMIN`/`ADMIN`) may be changed by previous owner
   - Reset procedure: Clear CMOS via JBT1 jumper (no dedicated IPMI reset jumper on X10SRL-F)

3. **HBA Boot Configuration**
   - **Critical**: Set HBA Boot Support to **"BIOS and OS"** (not "OS only")
   - OS-only mode prevents booting from HBA-connected drives
   - Access HBA BIOS: Press **Ctrl+C** during LSI initialization screen
   - Boot drive must be in **caddy bay #1** (first slot) for reliable detection
   - Higher-numbered bays may initialize too late in boot sequence

4. **NVMe Boot Issues**
   - X10SRL-F BIOS may not support NVMe boot (board predates widespread NVMe adoption)
   - Solutions: Update BIOS to latest version, or boot from SATA/USB and use NVMe for data
   - Current deployment uses SATA SSD boot with NVMe available for Docker/data

5. **Network Drivers**
   - Dual Intel GbE uses **`igb`** driver (i210/I350 chipset)
   - May require `firmware-misc-nonfree` package in Debian

**narsis Docker & Storage Configuration**

Deployed and configured on 2025-11-25:

1. **Storage Layout (Three-Tier Strategy)**
   - **Boot SSD** (120GB SATA): OS only, minimal usage (~10-20GB)
   - **NVMe** (480GB PCIe): Docker data root + all service configurations
   - **Hot-swap Caddies** (24× 2.5" bays): Reserved for media storage, progressively filled

2. **Docker Setup**
   - Docker CE v29.0.4 installed from official repository (Bookworm packages on Trixie)
   - Docker data root: `/mnt/nvme/docker` (configured in `/etc/docker/daemon.json`)
   - External network: `caddy_net` (created for reverse proxy connectivity)
   - Service data directories: `/mnt/nvme/services/<service>/config`
   - User `athires` added to `docker` group for sudo-free access

3. **Portainer Deployment**
   - Container: `portainer/portainer-ce:latest`
   - Web UI: `https://192.168.1.11:9443` (HTTPS) or `http://192.168.1.11:9000`
   - Data volume: `/opt/portainer/data`
   - Connected to: `caddy_net` network
   - Purpose: Service management, stack deployment via Git integration

4. **Migration Strategy**
   - **Goal**: Migrate majority of services from `clockworkcity` to `narsis`
   - **Method**: One-by-one deployment via Portainer, proxied through clockworkcity Caddy
   - **Rationale**: narsis is more capable hardware; clockworkcity will become dedicated OPNsense/pfSense router
   - **Phase 1**: Non-critical services (Glance, n.eko, monitoring)
   - **Phase 2**: Medium-priority (n8n, SearXNG, utilities)
   - **Phase 3**: Critical services (Home Assistant, Vaultwarden)
   - **Services to remain on clockworkcity**: Caddy (reverse proxy), AdGuard Home (DNS), possibly Tailscale

5. **Essential Tools Installed**
   - `rsync`: File synchronization and backups
   - `htop`: System monitoring
   - `ncdu`: Disk usage analysis
   - `tree`: Directory visualization
   - `jq`: JSON parsing (for Docker/API work)
   - `netcat-openbsd`, `dnsutils`: Network diagnostics
   - `smartmontools`, `lm-sensors`: Hardware monitoring

6. **Future Enhancements**
   - GPU installation for hardware transcoding (Quadro T400/T600)
   - Media services: Plex/Jellyfin, *arr stack
   - Nextcloud migration from clockworkcity
   - Separate storage server for backups (ZFS, additional Supermicro chassis)

---

## 3) Networks & addressing

- **LAN**: `192.168.1.0/24` (gateway: Archer).  
- **Tailscale**: private overlay; MagicDNS; ACLs gate access.  
- **Docker**: external `caddy_net` for anything fronted by Caddy; app bridges for east‑west.

**Access policy (Caddy ‘gate’)**

```
allow: 192.168.1.0/24, 192.168.0.0/24 (legacy), 100.64.0.0/10 (Tailscale), 127.0.0.1/8, ::1, fd7a:115c:a1e0::/48
```

---

## 4) DNS model

- **Public (Cloudflare)**  
  - `*.rabalski.eu` → CNAME to `anchor.rabalski.eu` → A to public IP (31.178.228.90).  
  - Certificates issued by **Let’s Encrypt** using **DNS‑01 via Cloudflare API token**.

- **Internal (AdGuard Home)**  
  - **DNS rewrites**: `*.rabalski.eu` → `192.168.1.10` so devices on LAN hit Caddy directly.  
  - Upstreams: Cloudflare/Quad9 (DoH/DoT optional).  
  - *Clients without LAN DNS* can still reach services via **Tailscale** (MagicDNS) or temporary `/etc/hosts` overrides.

---

## 5) TLS & certificates

- **Issuer**: Let’s Encrypt (ACME) with **Cloudflare DNS‑01** plugin for Caddy.  
- **Secret**: `CF_API_TOKEN` in host `.env` file (not committed).  
- **Caddy** runs on :443 (TCP/UDP) and optionally :8443 NAT‑forwarded from edge.

---

## 6) Reverse proxy: Caddy (structure)

- Global email + standardized security headers.  
- `gate` matcher: only LAN + Tailscale.  
- Service blocks: reverse_proxy to container names on `caddy_net`.  
- Special cases: Home Assistant trusted proxies, Nextcloud upstream on host port 12000 (AIO), Vaultwarden admin protected by `basic_auth`.

**Operational commands**

```bash
# Validate & reload (container mounts /etc/caddy/Caddyfile:ro; host path: ./configs/caddy/Caddyfile):
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
# If valid:
docker exec caddy caddy reload   --config /etc/caddy/Caddyfile
```

---

## 7) Service catalog (active)

- **Home Assistant** (Zigbee via SONOFF ZBDongle‑E): `dom.rabalski.eu`  
- **Vaultwarden**: `21376942.rabalski.eu`  
- **SearXNG**: `search.rabalski.eu`  
- **Nextcloud AIO (Apache 12000)**: `cloud.rabalski.eu`  
- **Portainer**: `portainer.rabalski.eu`  
- **AdGuard Home**: `sink.rabalski.eu`  
- **n.eko** (Firefox/WebRTC): `kicia.rabalski.eu`  
- **changedetection.io**: `watch.rabalski.eu`  
- **Glance** dashboard: `deck.rabalski.eu`  
- **Marreta**: `ram.rabalski.eu`  
- **Dumbpad**: `pad.rabalski.eu`  
- **Speedtest‑Tracker**: `speedtest.rabalski.eu`

---

## 8) Data & storage layout

- **Nextcloud (AIO)**  
  - App volume: `nextcloud_aio_nextcloud` → `/var/www/html` (internal).  
  - **Data bind**: `/mnt/ncdata` (on **SSD** `sdb1`, ext4).  
  - Ownership: `www-data:www-data` (33:33).  
  - Verified content example: `admin/, appdata_*/, Marta/, .ncdata`.

- Other apps: config/data under `/opt/<name>/config` bind‑mounted to `/config` in container.  
- Backups: `rsync` to external target (later ZFS on CSE‑216), keep `.env`/secrets separate.

---

## 9) Runbooks (selected)

### 9.1 Bring up/repair Caddy

```bash
cd ~/homelabbing/configs/caddy
export CF_API_TOKEN=***                    # or ensure ~/caddy/.env contains it
mkdir -p .docker
DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache
docker compose up -d
docker exec caddy caddy list-modules | grep -i dns.providers.cloudflare
docker exec caddy caddy validate --config /etc/caddy/Caddyfile || true
docker exec caddy caddy reload   --config /etc/caddy/Caddyfile || true
```

### 9.2 Add a new service behind Caddy

1) Put service on `caddy_net`.  
2) Add vhost block + `import gate`.  
3) `docker exec caddy caddy validate && ... reload`.  
4) Add AdGuard rewrite (`service.rabalski.eu` → `192.168.1.10`).

### 9.3 AdGuard quick checks

```bash
nslookup <host>.rabalski.eu 192.168.1.10   # expect 192.168.1.10
nslookup -type=AAAA <host>.rabalski.eu 192.168.1.10  # expect no AAAA or a local IPv6, not Cloudflare
```

### 9.4 Tailscale quick fixes

```bash
# Show self + shields status
tailscale status --self
# Disable shields (server):
sudo tailscale set --shields-up=false
# MagicDNS issues? Re-login may reset DNS policy
tailscale logout && tailscale up --accept-dns=true
```

### 9.4a Tailscale stabilization (server hardening)

Issue: tailscaled appears “active (running)” but peers can’t reach it or it shows offline in the admin, then works again after reboot. This can be start-limit/boot timing related on busy Docker hosts.

1) Systemd override to keep it up and start after full network:

```bash
sudo mkdir -p /etc/systemd/system/tailscaled.service.d
sudo tee /etc/systemd/system/tailscaled.service.d/override.conf >/dev/null <<'EOF'
[Unit]
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Restart=always
RestartSec=5s
EOF

sudo systemctl daemon-reload
sudo systemctl reset-failed tailscaled
sudo systemctl enable --now tailscaled
```

Alternatively copy the prepared override from `configs/tailscale/tailscaled.service.d/override.conf` to `/etc/systemd/system/tailscaled.service.d/override.conf` and then run `sudo systemctl daemon-reload && sudo systemctl enable --now tailscaled`.

2) Optional safety net: restart if backend state isn’t Running.

```bash
sudo install -m 0755 configs/tailscale/tailscale-healthcheck.sh /usr/local/bin/tailscale-healthcheck.sh
sudo install -m 0644 configs/tailscale/tailscale-health.service /etc/systemd/system/tailscale-health.service
sudo install -m 0644 configs/tailscale/tailscale-health.timer   /etc/systemd/system/tailscale-health.timer
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-health.timer
```

3) Sanity checks when it “looks up but isn’t reachable/visible”:

```bash
tailscale status --self
tailscale ip -4 -6
ip -br addr show tailscale0
tailscale netcheck

# Clean re-login (fixes duplicate/invalid node keys)
sudo tailscale logout
sudo systemctl restart tailscaled
sudo tailscale up --accept-dns=true --accept-routes=true
```

Notes:
- If UFW is enabled, allow Tailscale: `sudo ufw allow in on tailscale0` and `sudo ufw route allow in on tailscale0`.
- Keep Tailscale updated from the official repo for Ubuntu 24.04.
- Frequent `monitor: RTM_DELROUTE ...` in logs is normal on Docker hosts (container veth churn).

### 9.4b When the Tailscale CLI hangs

Symptoms you may see on `clockworkcity`:
- `tailscale status --self`, `tailscale netcheck`, or `sudo tailscale logout` hang, but `ip -br addr show tailscale0` shows valid addresses.

Quick recovery:

```bash
sudo systemctl restart tailscaled
# After ~3–5s, verify
tailscale status --self
# Confirm visibility in admin and peer reachability
```

Notes:
- `tailscale ip -4 -6` is invalid usage; run separately: `tailscale ip -4` and `tailscale ip -6`.
- If hangs recur, capture logs before restarting: `journalctl -u tailscaled --since "-15m" --no-pager | tail -n +1`.
- With the override + timer enabled (see 9.4a), tailscaled should auto-recover from transient issues.

Config locations (after applying 9.4a):
- Systemd override: `/etc/systemd/system/tailscaled.service.d/override.conf`
- Health script: `/usr/local/bin/tailscale-healthcheck.sh`
- Health service/timer: `/etc/systemd/system/tailscale-health.service`, `/etc/systemd/system/tailscale-health.timer`
- Daemon socket/state (reference): `/run/tailscale/tailscaled.sock`, `/var/lib/tailscale/tailscaled.state`

### 9.5 Nextcloud data migration (performed)

1) Mount SSD `sdb1` to `/mnt/ssd-new`, copy from HDD or old path:  
   `rsync -aHAX --info=progress2 /mnt/hdd/nextcloud-data/ /mnt/ssd-new/`  
2) `fstab` entry for **NC_SSD** label/UUID → `/mnt/ncdata` with `noatime`.  
3) `sudo mount -a`, `sudo chown -R 33:33 /mnt/ncdata`.  
4) Start DB/Redis first, then Nextcloud Apache.  
5) Validate via `/status.php` and full web login.

### 9.6 Speedtest‑Tracker repair (performed)

- Set `DB_CONNECTION=sqlite` and **persist DB** at `/config/www/database/database.sqlite`.  
- Initialize DB: `php artisan migrate --force && php artisan db:seed --force` inside container.  
- Use `CACHE_DRIVER=file`, `SESSION_DRIVER=file` to avoid DB cache errors.

---

## 10) Security posture

- **Caddy `gate`** allowlist (LAN + Tailscale only) for private apps.  
- **Strict headers** (HSTS, X‑Frame‑Options, Referrer‑Policy, X‑Content‑Type‑Options).  
- **Home Assistant**: set `trusted_proxies` to Docker bridge ranges; configure `use_x_forwarded_for: true`.  
- Optionally add fail2ban on Caddy logs or Caddy rate limits per site.

---

## 11) Monitoring & logs (one‑liners)

```bash
# Who listens on 443 (host)
sudo ss -tnlp | grep ':443'
# Caddy last minute
docker logs caddy --since 60s
# Site health (from client)
curl -I https://<site>.rabalski.eu
# Inside Caddy net DNS resolution
docker exec -it caddy getent hosts <container-name>
```

---

## 12) Disaster recovery cheat‑sheet

1) Verify DNS (AdGuard rewrite + public).  
2) Bring up Caddy with Cloudflare token.  
3) Start data backends (DB/Redis), then apps.  
4) Restore volumes/binds from backup.  
5) Validate certs (`docker logs caddy | grep -i acme`).

---

## 13) Secrets & environment

- Host `.env` (not in Git):  
  - `CF_API_TOKEN=...`  
  - `EMAIL=...`, `PASSWORD=...` (for one‑time bootstrap flows).  
  - Service‑specific keys (e.g., `APP_KEY` for Speedtest).  
- For Portainer/Compose, prefer Docker secrets once available.

---

## 14) Docker Compose library (canonical snippets)

> These blocks assume an external Docker network **`caddy_net`** already exists:
>
> ```bash
> docker network create caddy_net
> ```

### 14.1 Caddy (local build with bundled Cloudflare DNS plugin)

Run compose commands from `~/homelabbing/configs/caddy` (compose file + Dockerfile live there).

```yaml
services:
  caddy:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        CADDY_VERSION: "2.8.4"
    image: caddy-cloudflare:2.8.4
    container_name: caddy
    restart: unless-stopped
    environment:
      CF_API_TOKEN: ${CF_API_TOKEN}
      CLOUDFLARE_API_TOKEN: ${CF_API_TOKEN}
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    networks: [caddy_net]
    ports:
      - "443:443/tcp"
      - "443:443/udp"
      # optional WAN-forwarded
      - "8443:443/tcp"
      - "8443:443/udp"

networks:
  caddy_net:
    external: true
volumes:
  caddy_data: {}
  caddy_config: {}
```

### 14.2 Home Assistant (with Zigbee dongle)

```yaml
services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    restart: unless-stopped
    environment:
      TZ: Europe/Warsaw
    devices:
      - /dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_184bf3194b53ef11b8be2ce0174bec31-if00-port0:/dev/ttyUSB0
    volumes:
      - ha_config:/config
      - /etc/localtime:/etc/localtime:ro
      - /run/udev:/run/udev:ro
    networks: [caddy_net]

networks:
  caddy_net:
    external: true
volumes:
  ha_config: {}
```

**HA `configuration.yaml` (proxy awareness)**

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 172.18.0.0/16   # Docker bridge(s)
    - 127.0.0.1
    - ::1
```

### 14.3 Vaultwarden

```yaml
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: unless-stopped
    environment:
      SIGNUPS_ALLOWED: "false"
      WEBSOCKET_ENABLED: "true"
    volumes:
      - /opt/vaultwarden/data:/data
    networks: [caddy_net]
```

### 14.4 SearXNG

```yaml
services:
  searxng:
    image: searxng/searxng:latest
    container_name: searxng
    restart: unless-stopped
    environment:
      - SEARXNG_BASE_URL=https://search.rabalski.eu/
    networks: [caddy_net]
```

### 14.5 Portainer

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /opt/portainer/data:/data
    networks: [caddy_net]
```

Config source: `homelabbing/configs/portainer/docker-compose.yml` (deployed on clockworkcity).  
⚠️ Compatibility note (2025‑02): Docker 29.0.0 currently trips Portainer 2.33.x into creating a Podman endpoint (`the Podman environment option doesn't support Docker environments`). See [portainer/portainer#12925](https://github.com/portainer/portainer/issues/12925); either keep Docker ≤28.x or set `Environment=DOCKER_MIN_API_VERSION=1.24` in `docker.service` before starting Portainer.

### 14.6 AdGuard Home

```yaml
services:
  adguard:
    image: adguard/adguardhome:latest
    container_name: adguard
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
    volumes:
      - /opt/adguard/work:/opt/adguardhome/work
      - /opt/adguard/conf:/opt/adguardhome/conf
    networks: [caddy_net]
```

### 14.7 n.eko (Firefox)

```yaml
services:
  neko:
    image: m1k1o/neko:firefox
    container_name: neko
    restart: unless-stopped
    environment:
      - NEKO_PASSWORD=***
      - NEKO_PASSWORD_ADMIN=***
    networks: [caddy_net]
```

### 14.8 changedetection.io

```yaml
services:
  changedetection:
    image: ghcr.io/dgtlmoon/changedetection.io:latest
    container_name: changedetection
    restart: unless-stopped
    volumes:
      - /opt/changedetection/data:/datastore
    networks: [caddy_net]
```

### 14.9 Glance

```yaml
services:
  glance:
    image: glanceapp/glance:latest
    container_name: glance
    restart: unless-stopped
    networks: [caddy_net]
```

### 14.10 Marreta

```yaml
services:
  marreta:
    image: ghcr.io/tiagocoutinh0/marreta:latest
    container_name: marreta
    restart: unless-stopped
    networks: [caddy_net]
```

### 14.11 Dumbpad

```yaml
services:
  dumbpad:
    image: ghcr.io/dumbpad/dumbpad:latest
    container_name: dumbpad
    restart: unless-stopped
    networks: [caddy_net]
```

### 14.12 Speedtest‑Tracker (working sqlite config)

```yaml
services:
  speedtest-tracker:
    image: lscr.io/linuxserver/speedtest-tracker:latest
    container_name: speedtest-tracker
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Warsaw
      APP_KEY: ${APP_KEY}
      DB_CONNECTION: sqlite
      DB_DATABASE: /config/www/database/database.sqlite
      APP_URL: https://speedtest.rabalski.eu
      ASSET_URL: https://speedtest.rabalski.eu
      APP_TIMEZONE: Europe/Warsaw
      ADMIN_NAME: Kuba
      ADMIN_EMAIL: ${EMAIL}
      ADMIN_PASSWORD: ${PASSWORD}
      SPEEDTEST_SCHEDULE: "6 * * * *"
      PRUNE_RESULTS_OLDER_THAN: "0"
      SPEEDTEST_SERVERS: "3671,7200,23122"
      CACHE_DRIVER: file
      SESSION_DRIVER: file
      QUEUE_CONNECTION: sync
    volumes:
      - /opt/speedtest-tracker/config:/config
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost/api/healthcheck | grep -qi running"]
      interval: 10s
      retries: 3
      start_period: 30s
      timeout: 10s
    networks: [caddy_net]
```

> After first start:
>
> ```bash
> docker exec -it speedtest-tracker bash -lc '
>   set -e
>   [ -f /config/www/database/database.sqlite ] || install -Dm644 /dev/null /config/www/database/database.sqlite
>   cd /app/www && php artisan migrate --force && php artisan db:seed --force
> '
> ```

### 14.13 Nextcloud AIO (reference)

Managed by AIO’s mastercontainer; Caddy proxies `cloud.rabalski.eu` → `host.docker.internal:12000` (see site block in §6/§16).

---

## 15) Migration: clockworkcity → narsis

**Status**: Foundation complete (2025-11-25). Ready for service migration.

### 15.1 Infrastructure Setup (Completed ✅)

- ✅ **Hardware**: Supermicro CSE-216 with X10SRL-F deployed
- ✅ **OS**: Debian 13 (Trixie) installed, networking configured
- ✅ **Storage**: Three-tier layout (boot SSD, NVMe for Docker, caddies for media)
- ✅ **Docker**: v29.0.4 installed, data root at `/mnt/nvme/docker`
- ✅ **Network**: Static IP `192.168.1.11`, `caddy_net` external network created
- ✅ **Portainer**: Deployed at `https://192.168.1.11:9443`
- ✅ **IPMI**: Accessible, credentials reset, fan control configured

### 15.2 Migration Strategy

**Architecture**:
```
                          ┌─────────────────────┐
Internet ──────────────▶ │  clockworkcity      │
                          │  (192.168.1.10)     │
                          │  • Caddy (reverse   │
                          │    proxy)           │
                          │  • AdGuard Home     │
                          └──────────┬──────────┘
                                     │
                          ┌──────────┴──────────┐
                          │                     │
                    ┌─────▼─────┐         ┌────▼─────┐
                    │  narsis   │         │ Clients  │
                    │ (services)│         │ (LAN)    │
                    └───────────┘         └──────────┘
```

**Key Principles**:
1. **Caddy stays on clockworkcity** (edge termination, proxies to narsis services)
2. **AdGuard stays on clockworkcity** (DNS is network-critical)
3. **Services migrate to narsis** one by one via Portainer
4. **No DNS changes needed** - all domains still resolve to 192.168.1.10
5. **Rollback friendly** - keep service on clockworkcity until narsis version validated

### 15.3 Service Migration Workflow (Per-Service)

**Prerequisites**:
- Service stack available in Git repository (`stacks/<service>/`)
- Service data backed up from clockworkcity
- Service volume paths planned on narsis (under `/mnt/nvme/services/<service>/`)

**Steps**:

1. **Deploy to narsis** (via Portainer):
   ```bash
   # Create service data directory
   ssh narsis
   sudo mkdir -p /mnt/nvme/services/<service>/config
   sudo chown -R athires:athires /mnt/nvme/services/<service>

   # Deploy via Portainer UI:
   # - Stacks → Add Stack → Repository
   # - Git URL, compose path: stacks/<service>/docker-compose.yml
   # - Add environment variables
   # - Deploy
   ```

2. **Update Caddy on clockworkcity**:
   ```bash
   # Edit Caddyfile, update service block:
   <service>.rabalski.eu {
     import gate
     reverse_proxy http://192.168.1.11:<port>  # Point to narsis
   }

   # Reload Caddy
   docker exec caddy caddy reload --config /etc/caddy/Caddyfile
   ```

3. **Test service**:
   ```bash
   # From Almalexia or LAN client
   curl -I https://<service>.rabalski.eu
   # Should return 200 OK

   # Test full functionality in browser
   ```

4. **Stop old service on clockworkcity** (after validation):
   ```bash
   ssh clockworkcity
   docker stop <service>
   # Keep container for rollback, delete after 1-2 weeks
   ```

5. **Monitor and validate**:
   - Check logs: `docker logs <service>`
   - Verify data persistence (restart container, check data)
   - Test from multiple clients (LAN, Tailscale)

**Rollback Procedure**:
```bash
# On clockworkcity: restart old service
docker start <service>

# Revert Caddyfile to point back to localhost
# Reload Caddy

# On narsis: stop/remove new deployment
docker stop <service>
```

### 15.4 Migration Order (Phased Approach)

**Phase 1: Test & Learn (Week 1)**
1. ✅ Glance (simple dashboard, no state)
2. n.eko (browser isolation, low risk)
3. SearXNG (metasearch, stateless)

**Phase 2: Monitoring & Utilities (Week 2)**
4. Monitoring stack (Prometheus + Grafana + Blackbox)
5. Changedetection.io (website monitoring)
6. Speedtest Tracker (speed tests)
7. Dumbpad, Marreta (small utilities)

**Phase 3: Medium Priority (Week 3)**
8. n8n (automation - test workflows thoroughly)
9. Additional utilities

**Phase 4: Critical Services (Week 4+)**
10. Home Assistant (backup first, test Zigbee, automations)
11. Vaultwarden (password manager - thorough backup & testing)

**Services Remaining on clockworkcity**:
- Caddy (reverse proxy - stays at edge)
- AdGuard Home (DNS - network-critical)
- Portainer (managing clockworkcity)
- Nextcloud AIO (migrate separately, large data)
- Tailscale (systemd service, not containerized)
- Home Assistant (pending migration - Zigbee USB device)
- Vaultwarden (pending migration - critical password data)

### 15.5 Post-Migration: clockworkcity Conversion to Router

**Future Goal** (after service migration complete):

1. **Hardware upgrade**:
   - Replace CPU with Pentium G6400T (10W TDP, energy efficient)
   - Add Intel NIC (i350/i210, 2-4 ports for WAN/LAN/DMZ)
   - Minimal RAM (8-16GB sufficient)
   - Small SSD (64-128GB for router OS)

2. **Software deployment**:
   - Install OPNsense (bare metal, recommended over pfSense)
   - Configure WAN/LAN separation
   - Migrate Caddy to run on OPNsense (via Docker plugin)
   - Migrate AdGuard Home to OPNsense
   - Configure Suricata/IDS, VLANs, advanced firewall rules

3. **Network architecture** (future):
   ```
   Internet (WAN) → clockworkcity (OPNsense router/firewall)
                    ↓ LAN
                    Switch ──┬─── narsis (services)
                             ├─── Almalexia (workstation)
                             └─── IoT devices (separate VLAN)
   ```

### 15.6 Hardening & Maintenance

**On narsis**:
- Configure unattended security updates
- Enable UFW firewall (allow only necessary ports)
- Join Tailscale for remote management
- Set up log rotation for Docker
- Schedule regular backups to separate storage server (when available)
- Monitor disk health via `smartctl`
- Monitor temperatures via `lm-sensors`

**On clockworkcity** (current):
- Continue monitoring until migration complete
- Keep services running as fallback
- Document any quirks/configs before shutdown

### 15.7 Migration Summary (2025-11-26)

**Status**: Phase 1-3 complete. 10 services successfully migrated to narsis.

**Migrated Services** (now running on narsis):
1. ✅ **Glance** (`deck.rabalski.eu`) → 192.168.1.11:8080
2. ✅ **SearXNG** (`search.rabalski.eu`) → 192.168.1.11:8081
3. ✅ **Changedetection.io** (`watch.rabalski.eu`) → 192.168.1.11:5000
4. ✅ **Dumbpad** (`pad.rabalski.eu`) → 192.168.1.11:3000
5. ✅ **Browser-services** (Selenium Grid, internal only) → 192.168.1.11:4444
6. ✅ **Marreta** (`ram.rabalski.eu`) → 192.168.1.11:80
7. ✅ **Speedtest Tracker** (`speedtest.rabalski.eu`) → 192.168.1.11:8888
8. ✅ **n.eko** (`kicia.rabalski.eu`) → 192.168.1.11:8082
9. ✅ **Monitoring Stack** (Prometheus + Grafana + Blackbox):
   - Prometheus (`prometheus.rabalski.eu`) → 192.168.1.11:9090
   - Grafana (`grafana.rabalski.eu`) → 192.168.1.11:3300
   - Blackbox (internal) → 192.168.1.11:9115
10. ✅ **n8n** (`n8n.rabalski.eu`) → 192.168.1.11:5678

**Infrastructure Improvements**:
- ✅ `/var` moved to `/home` partition (82GB available for Docker temp operations)
- ✅ All services deployed via Portainer Git integration
- ✅ All Caddyfile changes tracked in Git repository
- ✅ narsis joined to Tailscale network (100.87.23.43)

**Key Issues Resolved**:
- Docker 29.x Portainer compatibility (DOCKER_MIN_API_VERSION=1.24)
- Root partition disk exhaustion (moved `/var` to `/home`)
- Container permission issues (Prometheus UID 65534, Grafana UID 472)
- Caddy reload vs restart behavior

**Documentation Created**:
- `docs/homelab/narsis-migration.md` - Detailed migration log with lessons learned
- All stacks have `.env.template` files for deployment documentation

**Next Phase**:
- Home Assistant migration (requires USB device passthrough planning)
- Vaultwarden migration (requires careful backup and testing)

**Reference**: See `docs/homelab/narsis-migration.md` for detailed migration process, issues, and solutions.

---

## 16) Caddyfile (current shape, English‑commented)

```caddyfile
{
  email jakurb@rabalski.eu
}

(gate) {
  @blocked not remote_ip 192.168.1.0/24 192.168.0.0/24 100.64.0.0/10 127.0.0.1/8 ::1 fd7a:115c:a1e0::/48
  respond @blocked "Forbidden" 403
}

rabalski.eu, www.rabalski.eu {
  redir https://dom.rabalski.eu{uri} 301
}

21376942.rabalski.eu {
  import gate
  @admin path /admin*
  basic_auth @admin {
    MoonAndStar $2a$14$4d1bebef2676gfWrypHNK.8QIC2/ftLZ/2WwA0Ae8OXCHbg65YFSa
  }
  reverse_proxy vaultwarden:80 {
    transport http {
      read_buffer  64MB
      write_buffer 64MB
      dial_timeout 10s
      response_header_timeout 2m
    }
    header_up X-Forwarded-Proto {scheme}
    header_up X-Forwarded-Host  {host}
  }
}

search.rabalski.eu {
  import gate
  reverse_proxy searxng:8080
}

cloud.rabalski.eu {
  import gate
  reverse_proxy http://host.docker.internal:12000
  header {
    X-Forwarded-Proto {scheme}
    X-Forwarded-For   {remote}
    X-Forwarded-Host  {host}
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
  }
}

portainer.rabalski.eu {
  import gate
  reverse_proxy http://portainer:9000
}

aio-setup.rabalski.eu {
  import gate
  reverse_proxy https://nextcloud-aio-mastercontainer:8080 {
    transport http {
      tls_insecure_skip_verify
    }
  }
}

sink.rabalski.eu {
  import gate
  reverse_proxy http://adguard:80
}

kicia.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://neko:8080 {
    transport http {
      dial_timeout 10s
      response_header_timeout 2m
    }
  }
}

watch.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy changedetection:5000
}

deck.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy glance:8080
}

ram.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy marreta:80
}

pad.rabalski.eu {
  import gate
  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Referrer-Policy "strict-origin-when-cross-origin"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "DENY"
  }
  reverse_proxy dumbpad:3000
}

speedtest.rabalski.eu {
  import gate
  header {
    X-Content-Type-Options "nosniff"
    Referrer-Policy "strict-origin-when-cross-origin"
    X-Frame-Options "SAMEORIGIN"
  }
  reverse_proxy http://speedtest-tracker:80 {
    transport http {
      dial_timeout 10s
      response_header_timeout 2m
    }
  }
}

dom.rabalski.eu {
  import gate
  reverse_proxy http://homeassistant:8123
  encode gzip
  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    Referrer-Policy "no-referrer-when-downgrade"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
  }
}
```

---

## 17) Post‑migration validation checklist

- LAN client resolves `*.rabalski.eu` → `192.168.1.x` (new host).  
- `curl -I` to each site returns 200/302 as expected.  
- Caddy logs show certs and upstream 200s.  
- HA trusted proxies OK; Zigbee devices online.  
- Nextcloud `/status.php` returns 200; random file read/write OK.  
- Vaultwarden apps (browser/mobile/CLI) can sync.  
- Speedtest cron runs per schedule and records results.  
- Backups complete successfully.

---

## 18) Printing: Epson EcoTank L3270 (Wi‑Fi 2.4 GHz)

- Model: **Epson EcoTank L3270 Series** (AirPrint/IPP Everywhere capable).  
- Radio: 2.4 GHz only. Keep a separate 2.4 GHz SSID (e.g., `home-iot`) and a 5 GHz SSID (e.g., `home`). Both must bridge to the same LAN/VLAN.  
- Router (TP‑Link Archer):  
  - Disable Smart Connect/band‑steering for this SSID.  
  - 2.4 GHz: 20 MHz width; channels 1/6/11; mode b/g/n; consider disabling 802.11ax (Wi‑Fi 6) on 2.4 GHz for legacy compatibility.  
  - Security WPA2‑PSK AES; PMF Optional (not Required).  
  - Ensure client/AP isolation is OFF; allow multicast (enable IGMP snooping/multicast enhancement if available).

**Addressing & DNS**

- Printer Wi‑Fi identity: `EPSONB2S2E9` (MAC reserved in DHCP).  
- Static lease: map the printer’s MAC → `192.168.1.201` (update any older `.200` reservation).  
- AdGuard rewrite (friendly name): `epson.lan` → `192.168.1.201`.

**IPP endpoints**

- Preferred: `ipp://epson.lan/ipp/port1`  
- Alternatives (firmware dependent): `ipp://epson.lan/ipp/print`, or replace host with the IP `192.168.1.201`.

**OpenSUSE Tumbleweed (CUPS) setup**

```bash
sudo zypper in cups cups-client cups-filters avahi nss-mdns epson-inkjet-printer-escpr gutenprint
sudo systemctl enable --now cups avahi-daemon

# Clean and add driverless IPP queue (color usually available)
sudo lpadmin -x EpsonL3270 || true
sudo lpadmin -p EpsonL3270 -E -v ipp://epson.lan/ipp/port1 -m everywhere
sudo lpoptions -d EpsonL3270
sudo lpoptions -p EpsonL3270 -o print-color-mode=color || true
sudo lpoptions -p EpsonL3270 -o ColorModel=RGB || true
lp -d EpsonL3270 /usr/share/cups/data/testprint
```

If the driverless queue exposes only monochrome, use Epson ESC/P‑R PPD (closest EcoTank color model from `epson-inkjet-printer-escpr`):

```bash
# Find a suitable color PPD (examples: ET‑2700 or L3150 families)
rpm -ql epson-inkjet-printer-escpr | grep -Ei 'ppd.*(ET-27|L3150|EcoTank)'

# Add the queue using the PPD path you found
sudo lpadmin -x EpsonL3270 || true
sudo lpadmin -p EpsonL3270 -E -v ipp://epson.lan/ipp/port1 -P <PPD_PATH>
sudo lpoptions -d EpsonL3270
sudo lpoptions -p EpsonL3270 -o print-color-mode=color -o ColorModel=RGB
```

**Discovery (AirPrint/Bonjour)**

- Ensure router passes multicast; no guest/isolation.  
- Linux check: `avahi-browse -rt _ipp._tcp` should list the printer.  
- If discovery is flaky, add by `ipp://epson.lan/ipp/port1` instead of relying on mDNS.

**Windows/macOS (quick add)**

- macOS: Add Printer → IP → Address `ipp://epson.lan/ipp/port1` → Use “AirPrint”.  
- Windows: Add printer → “The printer that I want isn’t listed” → TCP/IP → Host `epson.lan` (or IP), protocol IPP if available; pick Epson ESC/P‑R driver if needed.

**Troubleshooting**

- Verify DNS: `nslookup epson.lan 192.168.1.10` (AdGuard should answer `192.168.1.201`).  
- Verify IPP/color: `ipptool -tv ipp://epson.lan/ipp/port1 get-printer-attributes.test | grep -i color`.  
- If prints are grayscale, re‑check queue defaults (`print-color-mode=color`, `ColorModel=RGB`) or switch to an ESC/P‑R PPD.

---

### Appendix: quick glossary

- **Nameserver** ≈ DNS resolver answering queries.  
- **Authoritative DNS** (Cloudflare) holds the public truth for `rabalski.eu`.  
- **Recursive DNS** (AdGuard) resolves for clients + applies rewrites/filters.  
- **MagicDNS**: Tailscale’s friendly names + internal resolution over the mesh.
