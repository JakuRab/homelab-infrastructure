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
  -`Almalexia (main pc)` → `192.168.1.20`  
  -`EPSONB2S2E9` → `192.168.1.201`  
  -`MikroTik` → `192.168.1.2`  

- **Server `clockworkcity` (Ubuntu 24.04.3 LTS x86)**:  
  - NIC: `enp4s0` (LAN `192.168.1.10/24`).  
  - **Tailscale**: `100.98.21.87` (MagicDNS domain `*.tail7d1f88.ts.net`).  
  - Docker networks (bridges): `caddy_net` (external), app‑specific bridges.  
  - **Disks**:
    - NVMe (OS + root LV).  
    - HDD `sda1` **storage** (was `/mnt/hdd`).  
    - SSD `sdb1` **NC_SSD** → **Nextcloud data** at `/mnt/ncdata` (active).  

- **Main PC `Almalexia` (OpenSuse Tumbleweed)**:
  - Shell: `zsh`
  - Terminal: `ghostty`
  - Desktop Enviroments: `Hyprland (wayland, primary)`, `Plasma (wayland, secondary)`

**Planned platforms**

- **Media Server** (future expansion capable):
  - Case: **Supermicro CSE‑216** with BPN‑SAS3‑216EL1 backplane (24× 2.5" bays).
  - CPU: **Xeon E5‑2660 v4** (14‑core, Broadwell‑EP, no iGPU).
  - Mainboard: **Supermicro X10SRL‑F** (LGA2011‑3, IPMI 2.0 with dedicated NIC).
  - RAM: 32 GB (2× 16 GB DDR4 RDIMM ECC), expandable to 512 GB.
  - Storage: M.2 NVMe SSD on PCIe adapter (OS/data).
  - HBA: **LSI SAS3008** (AOC‑S3008L‑L8e, IT mode, 8‑port, 12 Gb/s SAS3) — incoming.
  - GPU: **NVIDIA Quadro T400/T600** — incoming (hardware transcoding, NVENC).
  - Network: Dual embedded Intel GbE + IPMI dedicated port.

- **Storage Server** (ZFS/bulk data):
  - Case: **Supermicro CSE‑826E16‑R1200LPB** (12× 3.5" bays, redundant 1200W PSU).
  - CPU: **Xeon E3‑1220L** (Sandy Bridge, low‑power, no iGPU).
  - Mainboard: **Supermicro X9SCL** (LGA1155, IPMI 2.0 with dedicated NIC).
  - RAM: 24 GB (3× 8 GB DDR3 UDIMM ECC).
  - Storage: SATA SSD (OS), M.2 NVMe on PCIe adapter (L2ARC/SLOG cache for ZFS).
  - HBA: **LSI SAS3008** (AOC‑S3008L‑L8e, IT mode) — incoming.
  - Network: Quad embedded Intel GbE + IPMI dedicated port.

- **Deployment plan**: Apps migrate in phases from `clockworkcity` (see §15).  

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

## 15) Migration to Supermicro CSE‑216 + X10

### 15.1 Storage

- HBA in IT‑mode → present disks to OS.  
- Create **ZFS** pool (or MD RAID) for app data; separate SSD (or small mirror) for `ncdata`.  
- Snapshots & replication target for backups.

### 15.2 Networking & DNS

- Assign static `192.168.1.x` for the new host; join Tailscale (MagicDNS).  
- Pre‑create `caddy_net` and restore Caddy with Cloudflare token.  
- Copy AdGuard config (if migrating DNS) or leave on current node temporarily.

### 15.3 Cutover (per‑app)

1) **Freeze** on old: stop app, backup `/opt/<app>` and volumes.  
2) **Restore** to new host same paths/UIDs.  
3) Bring up compose; validate via `curl -I https://<app>.rabalski.eu` from LAN.  
4) Swap AdGuard rewrite to new host IP (one domain at a time).  
5) Rollback: revert rewrite and start app back on old host.

### 15.4 Hardening on new host

- Lock down SSH, add unattended upgrades, enable logs shipping, ensure HBA temps/fans.

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
