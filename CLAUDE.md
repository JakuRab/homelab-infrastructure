# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Repository Overview

**Purpose:** GitOps-managed homelab infrastructure combining self-hosted services, desktop configurations, and AI-assisted development workflows.

**Main Components:**
- **Homelab stacks**: Docker Compose services for Portainer deployment (17 services)
- **Desktop configs**: Hyprland/Plasma configurations for Almalexia workstation
- **Documentation**: Architecture guides, runbooks, and migration tracking
- **AI workspace**: Topic-based conversation logs and project planning

**Version Control:**
- Main repository: Git-tracked, ready for GitHub push
- Secrets: Separate private repository (referenced but not committed)
- Configuration: `.gitignore` protects `.env` files, keys, certificates

---

## Infrastructure Overview

### Active Systems

**Production Server: `clockworkcity`**
- OS: Ubuntu 24.04.3 LTS
- IP: 192.168.1.10 (static DHCP reservation)
- Role: Edge server (Caddy reverse proxy, AdGuard DNS)
- Services: Core infrastructure + 7 remaining services
- Tailscale: 100.98.21.87 (clockworkcity.tail7d1f88.ts.net)
- Status: Transitioning to dedicated router/firewall role

**Media Server: `narsis`**
- OS: Debian 13 (Trixie)
- IP: 192.168.1.11 (static DHCP reservation)
- Tailscale: 100.87.23.43 (narsis.tail7d1f88.ts.net, IPv6: fd7a:115c:a1e0::a037:172b)
- Hardware: Supermicro X10SRL-F, Xeon E5-2660 v4, 32GB ECC DDR4
- Storage:
  - Boot: 120GB SATA SSD in caddy bay #1 (via HBA, `/var` moved to `/home` for space)
  - Data: 480GB NVMe (Docker data root at /mnt/nvme/docker)
  - Hot-swap: 24× 2.5" bays available
- Docker: v29.0.4, Portainer at https://192.168.1.11:9443
- IPMI: Accessible, credentials reset, fan mode "Optimal"
- Status: **Production** - 10 services migrated and running
- Notes: See `docs/homelab/homelab.md` §2 and `docs/homelab/narsis-migration.md`

**Workstation: `Almalexia`**
- OS: OpenSUSE Tumbleweed
- IP: 192.168.1.20 (static DHCP reservation)
- Shell: zsh with Starship prompt (Catppuccin theme)
- Terminal: Ghostty (JetBrains Mono Nerd Font)
- Desktop: Hyprland (Wayland, primary) / Plasma (secondary)
- Role: Development machine, config editing, remote management

### Network Architecture

**LAN:** 192.168.1.0/24
- Gateway: TP-Link Archer AX55 Pro (192.168.1.1)
- DNS: AdGuard Home on clockworkcity (192.168.1.10)
- Printer: Epson L3270 (192.168.1.201)

**Access Control:**
- Default: LAN + Tailscale only (private-by-default)
- Reverse Proxy: Caddy with Cloudflare DNS-01 ACME
- All services: `https://<subdomain>.rabalski.eu`
- DNS Split-Horizon:
  - Public: Cloudflare authoritative
  - Internal: AdGuard rewrites `*.rabalski.eu` → 192.168.1.10

**Docker Networking:**
- External network: `caddy_net` (must exist, created manually)
- All web services connect to `caddy_net` for Caddy reverse proxy access

---

## Repository Structure

```
aiTools/
├── stacks/                          # Docker Compose services (GitOps ready)
│   ├── caddy/                       # Reverse proxy (Cloudflare DNS plugin)
│   ├── homeassistant/               # Home automation (Zigbee via SONOFF dongle)
│   ├── vaultwarden/                 # Password manager
│   ├── n8n/                         # Workflow automation
│   ├── adguardhome/                 # DNS + ad blocking
│   ├── net_monitor/                 # Prometheus + Grafana + Blackbox
│   ├── portainer/                   # Container management
│   ├── searxng/                     # Metasearch engine
│   ├── neko/                        # Browser isolation (Firefox)
│   ├── changedetection/             # Website monitoring
│   ├── glance/                      # Dashboard
│   ├── dumbpad/                     # Note-taking
│   ├── marreta/                     # (Service TBD)
│   ├── speedtest-tracker/           # Internet speed monitoring
│   ├── browser-services/            # Browser-related services
│   └── tailscale/                   # VPN configs (systemd, not containerized)
│
├── docs/                            # Documentation hub
│   ├── homelab/
│   │   └── homelab.md              # **PRIMARY REFERENCE** - Complete architecture
│   ├── guides/
│   │   ├── GETTING_STARTED.md      # Quick start guide
│   │   ├── SERVICE_INVENTORY.md    # Service catalog
│   │   └── HYPRPANEL_SETUP.md      # Desktop environment setup
│   ├── deployment.md                # Stack deployment via Portainer
│   ├── portainer-setup.md           # Git integration configuration
│   ├── disaster-recovery.md         # Complete rebuild procedures
│   ├── migration-tracker.md         # Service migration status
│   ├── pre-migration-checklist.md   # Migration planning
│   ├── n8n-migration-test.md        # Test case documentation
│   └── service-clarifications.md    # Service-specific notes
│
├── workspace/                       # AI conversation logs (topic-based)
│   ├── homelab/
│   │   └── conversations/           # Homelab setup discussions
│   ├── gitops/
│   │   └── conversations/           # GitOps migration planning
│   ├── linux_desktop/               # Desktop environment work
│   └── example_topic/               # Template structure
│
├── config/                          # Desktop configurations & secrets
│   ├── .secrets-templates/          # Template for secrets management
│   └── (configs to be organized)
│
├── archive/                         # Deprecated/old files
│
├── scripts/                         # Automation scripts
│
├── README.md                        # Project README (GitOps overview)
└── CLAUDE.md                        # This file
```

---

## Key Architecture Principles

### Homelab Services

**Deployment Model:**
- **GitOps**: Portainer pulls from Git repository
- **Secrets**: Separate management (never committed)
- **Networking**: All services on `caddy_net`, proxied via Caddy
- **DNS**: Internal AdGuard rewrites for LAN access
- **TLS**: Let's Encrypt via Cloudflare DNS-01 (wildcard *.rabalski.eu)

**Service Pattern:**
```yaml
services:
  service-name:
    image: ...
    container_name: service-name
    restart: unless-stopped
    volumes:
      - /opt/service-name/config:/config  # Persistent config
    networks:
      - caddy_net
    environment:
      # From .env or Portainer environment variables

networks:
  caddy_net:
    external: true  # Pre-created, shared across all services
```

**Caddy Reverse Proxy:**
- Custom build with Cloudflare DNS plugin (see `stacks/caddy/Dockerfile`)
- Gate matcher: Only allow LAN (192.168.1.0/24, 192.168.0.0/24) + Tailscale (100.64.0.0/10)
- Each service gets vhost block in Caddyfile
- Reload without restart: `docker exec caddy caddy reload --config /etc/caddy/Caddyfile`

### Desktop Environment (Almalexia)

**Configuration Sync:**
- Source: `config/` directory in this repo (to be organized)
- Target: System paths (`~/.config/hypr/`, etc.)
- Method: `rsync` for manual sync or direct editing

**Development Workflow:**
1. Edit configs in repo
2. Test locally or sync to server
3. Commit changes
4. Push to GitHub (for Portainer auto-deployment)

---

## Active Services

All accessible via `https://<subdomain>.rabalski.eu` (LAN + Tailscale only):

| Service | Subdomain | Container | Purpose | Status |
|---------|-----------|-----------|---------|--------|
| **Critical Infrastructure** |
| Caddy | N/A | `caddy` | Reverse proxy (all HTTPS) | Production |
| Portainer | `portainer` | `portainer` | Container management | Production |
| AdGuard Home | `sink` | `adguard` | DNS + ad blocking | Production |
| **Home & Productivity** |
| Home Assistant | `dom` | `homeassistant` | Home automation (Zigbee) | Production |
| Vaultwarden | `21376942` | `vaultwarden` | Password manager | Production |
| Nextcloud AIO | `cloud` | Host:12000 | File sync (AIO model) | Production |
| n8n | `n8n` | `n8n` | Workflow automation | Production |
| **Monitoring & Tools** |
| Prometheus | `prometheus` | `prometheus` | Metrics collection | Production |
| Grafana | `grafana` | `grafana` | Metrics visualization | Production |
| Blackbox Exporter | N/A | `blackbox` | Network probing | Production |
| Speedtest Tracker | `speedtest` | `speedtest-tracker` | Speed monitoring | Production |
| Changedetection.io | `watch` | `changedetection` | Website monitoring | Production |
| **Utilities** |
| SearXNG | `search` | `searxng` | Metasearch engine | Production |
| Glance | `deck` | `glance` | Dashboard | Production |
| n.eko | `kicia` | `neko` | Browser isolation (Firefox) | Production |
| Dumbpad | `pad` | `dumbpad` | Note-taking | Production |
| Marreta | `ram` | `marreta` | (TBD) | Production |

**Infrastructure Services (Non-Containerized):**
- Tailscale: systemd service (VPN overlay network)

---

## Primary Documentation Reference

**For all homelab questions, consult first:**
- **File**: `docs/homelab/homelab.md`
- **Size**: ~85KB, comprehensive
- **Contains**:
  - Complete network topology
  - Service catalog with domains
  - Data layout and storage strategy
  - Runbooks for common operations
  - Docker Compose library (canonical patterns)
  - Migration plans to Supermicro platform
  - Security model and access control
  - Disaster recovery procedures
  - Caddyfile reference

**Other Key Documentation:**
- `stacks/*/README.md` - Service-specific deployment notes
- `docs/deployment.md` - Portainer Git deployment walkthrough
- `docs/migration-tracker.md` - Service migration status
- `docs/disaster-recovery.md` - Full rebuild procedures

---

## Common Workflows

### Deploying New Service via Portainer Git

1. **Create stack directory**: `stacks/SERVICE_NAME/`
2. **Add compose file**: `docker-compose.yml` with `caddy_net` network
3. **Create env template**: `.env.template` for required variables
4. **Add Caddy vhost**: Edit `stacks/caddy/Caddyfile`, add service block with `import gate`
5. **Commit and push**: `git add . && git commit && git push`
6. **Deploy in Portainer**:
   - Stacks → Add Stack → Repository
   - URL: GitHub repo URL
   - Compose path: `stacks/SERVICE_NAME/docker-compose.yml`
   - Add environment variables
   - Enable auto-sync (optional)
7. **Add DNS rewrite**: AdGuard Home: `<service>.rabalski.eu` → `192.168.1.10`
8. **Validate**: `curl -I https://<service>.rabalski.eu` from LAN

### Updating Existing Service

**With Git auto-sync:**
```bash
# Edit locally
vim stacks/SERVICE_NAME/docker-compose.yml

# Commit and push
git add stacks/SERVICE_NAME/
git commit -m "Update SERVICE_NAME: description"
git push

# Portainer auto-deploys (if webhook configured)
```

**Manual trigger:**
- Push changes to GitHub
- Portainer → Stack → Pull and redeploy

### Caddy Operations

```bash
# Reload Caddyfile after edits (no downtime)
docker exec caddy caddy validate --config /etc/caddy/Caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Verify Cloudflare plugin loaded
docker exec caddy caddy list-modules | grep dns.providers.cloudflare

# View recent logs
docker logs caddy --since 60s

# Rebuild after Dockerfile changes
cd ~/caddy  # on clockworkcity
mkdir -p .docker
DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache
docker compose up -d
```

### Tailscale Management

```bash
# Check status
tailscale status --self

# Fix connectivity issues (clean re-login)
sudo tailscale logout
sudo systemctl restart tailscaled
sudo tailscale up --accept-dns=true --accept-routes=true

# Apply stability config (if not already done)
# See docs/homelab/homelab.md §9.4a for systemd override + health timer
```

### Network Diagnostics

```bash
# Check what's listening on 443
sudo ss -tnlp | grep ':443'

# DNS resolution test (internal)
nslookup service.rabalski.eu 192.168.1.10

# Test from LAN client
curl -I https://service.rabalski.eu

# Container DNS resolution
docker exec -it caddy getent hosts container-name
```

---

## Special Considerations

### Caddy Custom Build
- Uses Dockerfile that downloads Caddy binary with Cloudflare DNS plugin
- Changes to Caddyfile: reload only
- Changes to Dockerfile: full rebuild required
- Source: `stacks/caddy/Dockerfile`

### Nextcloud AIO
- Managed by AIO mastercontainer (not standard compose)
- Data: Dedicated SSD at `/mnt/ncdata` on clockworkcity
- Caddy proxies: `cloud.rabalski.eu` → `http://host.docker.internal:12000`
- Do not manage via standard stack patterns

### Network Monitoring Stack
- Deployed via Portainer stack
- Uses Docker bind-mounts from `/srv/configs/net_monitor` (on server)
- Prometheus file_sd: Drop targets in `file_sd/*.yml` for auto-discovery
- Dashboards: Grafana provisioned from `grafana/dashboards/`
- Comprehensive guides: `stacks/net_monitor/*.md`

### Media Server (narsis) Setup Notes
- BIOS: Latest version 3.4 (does not support NVMe boot)
- Boot: SATA SSD in caddy bay #1, HBA boot support "BIOS and OS"
- Fans: Replaced server fans with Arctic P8, IPMI fan mode set to "Optimal"
- NVMe: Formatted ext4, mounted at `/mnt/nvme`, available for Docker/data
- IPMI: Web accessible, credentials reset via `ipmitool`
- Shell: zsh with Starship (Catppuccin Macchiato)
- See: `docs/homelab/homelab.md` §2 "Media Server Boot & Access Notes"

### Tailscale Stability
- clockworkcity uses systemd overrides + health-check timer
- Prevents daemon hangs, auto-restarts if offline
- Config files: `stacks/tailscale/` (deploy to `/etc/systemd/system/`)

---

## AI Workspace Structure

**Purpose**: Track AI-assisted conversations by topic

**Pattern**:
```
workspace/TOPIC_NAME/
├── conversations/
│   └── YYYY-MM-DD_description.md   # Timestamped discussion logs
├── TOPIC_OVERVIEW.md               # Topic summary (optional)
└── outputs/                        # Generated files (optional)
```

**Active Topics**:
- `homelab/` - Service setup, troubleshooting, architecture
- `gitops/` - Migration to GitOps model
- `linux_desktop/` - Hyprland/Plasma configuration
- `example_topic/` - Template for new topics

---

## Secrets Management

**Policy**: Secrets NEVER committed to this repository

**Structure**:
- `.env.template` files document required variables
- Actual secrets: Separate private repo or Portainer environment variables
- Git ignores: `**/.env`, `*.key`, `*.pem`, `**/secrets/`

**Required Secrets**:
- `CF_API_TOKEN`: Cloudflare API token (Zone:Read + DNS:Edit) for Caddy ACME
- Service-specific: See each stack's `.env.template`

---

## Migration Status

**Current Phase**: Phase 1-3 complete (2025-11-26)

**Completed**:
1. ✅ Repository published to GitHub (https://github.com/JakuRab/homelab-infrastructure)
2. ✅ Portainer Git integration tested and working
3. ✅ 10 services migrated to narsis via GitOps deployment
4. ✅ narsis joined to Tailscale network
5. ✅ Infrastructure issues resolved (disk space, permissions, compatibility)

**In Progress**:
- Planning Home Assistant migration (USB device passthrough)
- Planning Vaultwarden migration (critical data backup strategy)

**Next Steps**:
1. Migrate Home Assistant (requires Zigbee USB passthrough configuration)
2. Migrate Vaultwarden (password manager - thorough testing required)
3. Plan media services (Plex, Jellyfin) for narsis
4. Evaluate ZFS setup for narsis bulk storage

**Documentation**:
- `docs/homelab/narsis-migration.md` - Detailed migration log (2025-11-26)
- `docs/homelab/homelab.md` §15.7 - Migration summary
- `docs/migration-tracker.md` - Ongoing status tracking

---

## Static IP Assignments

**DHCP Reservations on TP-Link Archer (192.168.1.1)**:
- `192.168.1.10` - clockworkcity (server)
- `192.168.1.11` - narsis (media server)
- `192.168.1.20` - Almalexia (workstation)
- `192.168.1.201` - EPSONB2S2E9 (printer)
- `192.168.1.2` - MikroTik (secondary router, if active)

---

## Quick Reference Commands

### Docker Network Setup
```bash
# Create caddy_net (run once per server)
docker network create caddy_net
```

### Service Health Checks
```bash
# List all containers
docker ps -a

# Service logs
docker logs <container-name> --since 60s

# Follow logs
docker logs -f <container-name>

# Restart service
docker restart <container-name>
```

### System Updates
```bash
# Almalexia (OpenSUSE)
sudo zypper dup

# clockworkcity / narsis (Debian/Ubuntu)
sudo apt update && sudo apt upgrade -y
```

### narsis Quick Access
```bash
# SSH from Almalexia
ssh athires@192.168.1.11
# or
ssh athires@narsis  # if DNS configured

# IPMI web interface
# Check router for IPMI port IP, or configure static DHCP reservation
```

---

## Development Environment

**Almalexia Configuration**:
- Font: JetBrains Mono Nerd Font (for icon support)
- Prompt: Starship with Catppuccin theme
- SSH config: `~/.ssh/config` with TERM override for server compatibility
- Workflow: Edit → Test → Commit → Push → Portainer deploys

**Server Access**:
- SSH keys preferred (password fallback available)
- Ghostty terminal with proper TERM setting (`xterm-256color`)
- Multi-pane tmux/screen for parallel tasks (optional)

---

## Troubleshooting Quick Links

**Homelab Issues**:
1. Check `docs/homelab/homelab.md` §9-12 (Runbooks, Monitoring, Disaster Recovery)
2. Service-specific: `stacks/SERVICE_NAME/README.md`
3. Network monitoring: `stacks/net_monitor/TROUBLESHOOTING.md`

**Common Issues**:
- **Caddy not starting**: Check CF_API_TOKEN env var, validate Caddyfile
- **Service unreachable**: Verify DNS rewrite, check Caddy logs, test container networking
- **Tailscale offline**: See §9.4a-b in homelab.md for stability fixes
- **Portainer won't deploy**: Check compose syntax, verify caddy_net exists, review environment variables

---

## Additional Notes

**Repository Maintenance**:
- This file (`CLAUDE.md`) should be updated when:
  - New services are added
  - Infrastructure changes (new servers, IP changes)
  - Workflow patterns evolve
  - Major documentation restructuring

**Best Practices**:
- Always consult `docs/homelab/homelab.md` before making infrastructure changes
- Test changes in staging/local before deploying to production
- Document significant changes in workspace conversations
- Keep `.env.template` files updated with new requirements

---

**Last Updated**: 2025-11-26
**Maintainer**: Kuba Rabalski
**Primary Reference**: `docs/homelab/homelab.md`

**Recent Changes** (2025-11-26):
- Updated narsis status to Production with 10 migrated services
- Added Tailscale network information for narsis
- Updated migration status to reflect Phase 1-3 completion
- Added reference to narsis-migration.md documentation
