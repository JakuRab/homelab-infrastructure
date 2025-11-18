# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal infrastructure repository combining:
- **Homelabbing**: Self-hosted services on `clockworkcity` server (Ubuntu 24.04.3 LTS)
- **Linux configs**: Desktop environment configurations for `Almalexia` workstation (OpenSUSE Tumbleweed)
- **AI workspace**: Conversation tracking and documentation

## Key Architecture Principles

### Homelab Infrastructure

**Network Model:**
- Single entrypoint via Caddy reverse proxy with Cloudflare DNS-01 ACME
- Private-by-default: LAN (192.168.1.0/24) + Tailscale (100.64.0.0/10) only
- DNS split-horizon: Cloudflare (public) + AdGuard Home (internal rewrites)
- All services on shared Docker network `caddy_net` (must be created externally)

**Data Separation:**
- Configs: version-controlled in `homelabbing/configs/<service>/`, synced to server
- Runtime: deployed to `~/caddy/`, `/opt/<service>/`, or `/mnt/` on `clockworkcity`
- Secrets: `.env` files on server (never committed)

**Service Architecture:**
- Caddy custom build with Cloudflare DNS plugin (see Dockerfile pattern)
- Services compose files assume `caddy_net` network exists
- Nextcloud AIO runs on host port 12000 (proxied to `cloud.rabalski.eu`)
- Each service mounts config from `/opt/<name>/config` → `/config` in container

### Development Environment

**Main PC (`Almalexia`):**
- OS: OpenSUSE Tumbleweed
- Shell: `zsh`
- Terminal: `ghostty`
- Primary DE: Hyprland (Wayland) - config at `linux/configs/hyprland/`
- Secondary DE: Plasma (Wayland)

**Important**: Files in `aiTools` are a **staging repository** for AI agents to edit. Changes must be deployed to actual locations:
- Homelab configs: sync from `homelabbing/configs/` to server locations
- Linux configs: sync from `linux/configs/` to local system paths (e.g., `~/.config/`)

## Common Commands

### Homelab - Caddy Operations

```bash
# From repo: sync configs to server
rsync -av homelabbing/configs/caddy/ user@clockworkcity:~/caddy/

# On server: rebuild Caddy with Cloudflare plugin
cd ~/caddy
mkdir -p .docker
DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache
docker compose up -d

# Validate and reload Caddyfile after changes
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verify Cloudflare DNS plugin is loaded
docker exec caddy caddy list-modules | grep -i dns.providers.cloudflare
```

### Homelab - Adding New Services

1. Create compose file in `homelabbing/configs/<service>/docker-compose.yml`
2. Ensure service network includes `caddy_net: external: true`
3. Add vhost block to `homelabbing/configs/caddy/Caddyfile` with `import gate`
4. Sync Caddyfile to server and reload Caddy
5. Add AdGuard rewrite: `<service>.rabalski.eu` → `192.168.1.10`
6. Test from LAN client: `curl -I https://<service>.rabalski.eu`

### Homelab - Tailscale Management

```bash
# Check Tailscale status
tailscale status --self

# Fix connectivity issues (clean re-login)
sudo tailscale logout
sudo systemctl restart tailscaled
sudo tailscale up --accept-dns=true --accept-routes=true

# If CLI hangs, restart daemon
sudo systemctl restart tailscaled

# Apply stabilization config (systemd override + health timer)
# Source files in homelabbing/configs/tailscale/
sudo cp homelabbing/configs/tailscale/tailscaled.service.d/override.conf /etc/systemd/system/tailscaled.service.d/
sudo install -m 0755 homelabbing/configs/tailscale/tailscale-healthcheck.sh /usr/local/bin/
sudo install -m 0644 homelabbing/configs/tailscale/tailscale-health.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-health.timer
```

### Homelab - Docker Network Setup

```bash
# Create the required external network (run once)
docker network create caddy_net
```

### Linux Desktop - Deploy Config Changes

```bash
# Hyprland configuration
rsync -av /home/kuba/aiTools/linux/configs/hyprland/ ~/.config/hypr/
hyprctl reload

# Other configs follow similar pattern:
# rsync -av /home/kuba/aiTools/linux/configs/<name>/ <destination>/
```

### Homelab - Service Health Checks

```bash
# Check what's listening on 443
sudo ss -tnlp | grep ':443'

# Recent Caddy logs
docker logs caddy --since 60s

# Test site from client
curl -I https://<site>.rabalski.eu

# DNS resolution inside Caddy network
docker exec -it caddy getent hosts <container-name>

# Verify DNS rewrite (from LAN client)
nslookup <host>.rabalski.eu 192.168.1.10
```

## Repository Structure

```
aiTools/
├── homelabbing/
│   ├── homelab.md              # Complete homelab architecture & runbooks
│   ├── configs/
│   │   ├── caddy/              # Reverse proxy (Dockerfile + Caddyfile)
│   │   ├── net_monitor/        # Prometheus + Grafana + Blackbox
│   │   ├── portainer/          # Container management
│   │   ├── tailscale/          # VPN systemd hardening
│   │   └── n8n/                # Workflow automation
│   └── convos/                 # AI conversation logs for service setups
├── linux/configs/
│   ├── hyprland/               # Wayland compositor config
│   └── nvim/                   # Editor documentation
└── ai_workspace/               # Session-based AI discussions
```

## Important Files

- `homelabbing/homelab.md`: Authoritative architecture document (25KB) - consult this for all homelab questions
- `homelabbing/configs/caddy/Caddyfile`: Reverse proxy configuration with all service definitions
- `homelabbing/configs/caddy/README.md`: Caddy deployment workflow
- `homelabbing/configs/net_monitor/README.md`: Network monitoring stack guide

## Workflow Patterns

### Config Changes Workflow

1. **Edit** configs in repository (`homelabbing/configs/<service>/`)
2. **Sync** to server via `rsync` or `scp`
3. **Apply** changes (rebuild, reload, or restart as needed)
4. **Validate** via logs and health checks

### Secret Management

- **Never commit** `.env` files
- Secrets live on server in service directories
- Required vars documented in service READMEs
- Caddy needs: `CF_API_TOKEN` (Cloudflare API token with Zone:Read + DNS:Edit)

### Service Deployment Pattern

All services follow this compose template:
```yaml
services:
  <name>:
    image: <image>
    container_name: <name>
    restart: unless-stopped
    volumes:
      - /opt/<name>/config:/config  # persistent config
    networks:
      - caddy_net

networks:
  caddy_net:
    external: true  # created once, shared by all services
```

## Special Considerations

### Caddy Custom Build

Caddy uses a **custom Dockerfile** that downloads the official binary with the Cloudflare DNS plugin pre-bundled. Changes to `Caddyfile` require only reload; changes to `Dockerfile` or plugin dependencies require rebuild.

### Nextcloud AIO

Nextcloud runs via AIO mastercontainer, **not** as a standard compose service. Data lives on dedicated SSD at `/mnt/ncdata`. Caddy proxies to `http://host.docker.internal:12000`.

### Network Monitoring Stack

Deployed via Portainer stack. Configuration files use Docker bind-mounts from `/srv/configs/net_monitor`. Prometheus watches target files in `file_sd/` directories for automatic discovery (no restart needed).

### Tailscale Stability

`clockworkcity` uses systemd overrides and a health-check timer to prevent Tailscale daemon hangs. Config files in `homelabbing/configs/tailscale/` must be deployed to `/etc/systemd/system/` and `/usr/local/bin/`.

## Key Documentation Reference

For detailed homelab operations, troubleshooting, service catalog, data layout, Caddyfile syntax, migration planning, and security model - **always consult `homelabbing/homelab.md`** first. It contains:
- Network topology and addressing
- DNS model (split-horizon)
- Complete service catalog with domains
- Docker Compose library for all services
- Runbooks for common operations
- Disaster recovery procedures
- Migration plan to Supermicro platform

## Static IP Assignments (Router DHCP)

- `clockworkcity` (server): `192.168.1.10`
- `Almalexia` (main PC): `192.168.1.20`
- `EPSONB2S2E9` (printer): `192.168.1.201`
- `MikroTik` (router): `192.168.1.2`

## Active Services (on clockworkcity)

All accessible via `https://<subdomain>.rabalski.eu`:
- `dom` - Home Assistant (Zigbee via SONOFF dongle)
- `21376942` - Vaultwarden (password manager)
- `search` - SearXNG (metasearch)
- `cloud` - Nextcloud AIO
- `portainer` - Portainer CE
- `sink` - AdGuard Home
- `kicia` - n.eko (Firefox WebRTC)
- `watch` - changedetection.io
- `deck` - Glance dashboard
- `ram` - Marreta
- `pad` - Dumbpad
- `speedtest` - Speedtest-Tracker
- configuration.yaml:

 Loads default set of integrations. Do not remove.
default_config:

# Load frontend themes from the themes folder
frontend:
  themes: !include_dir_merge_named themes

automation: !include automations.yaml
script: !include scripts.yaml
scene: !include scenes.yaml
http:
    use_x_forwarded_for: true
    trusted_proxies:
      - 172.16.0.0/12
      - 127.0.0.1
      - ::1

Yet, 400 error is still here, latest logs:

2025-11-16 21:39:52.561 ERROR (MainThread) [homeassistant.components.http.forwarded] Invalid IP address in X-Forwarded-For: {remote_ip}
2025-11-16 21:39:53.576 ERROR (MainThread) [homeassistant.components.http.forwarded] Invalid IP address in X-Forwarded-For: {remote_ip}
2025-11-16 21:41:43.748 ERROR (MainThread) [homeassistant.components.http.forwarded] Invalid IP address in X-Forwarded-For: {remote_ip}
2025-11-16 21:41:44.762 ERROR (MainThread) [homeassistant.components.http.forwarded] Invalid IP address in X-Forwarded-For: {remote_ip}