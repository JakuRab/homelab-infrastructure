# Homelab Infrastructure

Public repository containing GitOps-managed Docker Compose stacks for Portainer deployment.

> **Note**: This repository contains only service deployment configurations. Documentation, workspace conversations, and desktop configs are in a separate private repository (`homelab-docs`).

## 🏗️ Architecture Overview

- **Reverse Proxy**: Caddy with Cloudflare DNS-01 ACME
- **Network**: Single external Docker network (`caddy_net`) for all services
- **DNS**: Split-horizon (Cloudflare public + AdGuard Home internal)
- **Access**: LAN (192.168.1.0/24) + Tailscale VPN only (private-by-default)
- **Orchestration**: Portainer CE with Git auto-sync
- **Servers**:
  - `clockworkcity` (Ubuntu 24.04.3 LTS) - Edge server, reverse proxy
  - `narsis` (Debian 13 Trixie) - Application server

## 📁 Repository Structure

```
.
├── stacks/                      # Docker Compose stacks (Portainer GitOps)
│   ├── caddy/                  # Reverse proxy (Cloudflare DNS plugin)
│   ├── adguardhome/            # DNS & ad blocking
│   ├── homeassistant/          # Home automation
│   ├── vaultwarden/            # Password manager
│   ├── n8n/                    # Workflow automation
│   ├── net_monitor/            # Prometheus + Grafana + Blackbox
│   ├── searxng/                # Metasearch engine
│   ├── glance/                 # Dashboard
│   ├── changedetection/        # Website monitoring
│   ├── neko/                   # Browser isolation (Firefox)
│   ├── dumbpad/                # Note-taking
│   ├── marreta/                # Pastebin/snippet manager
│   ├── speedtest-tracker/      # Internet speed monitoring
│   ├── browser-services/       # Selenium Grid
│   ├── portainer/              # Container management
│   └── tailscale/              # VPN systemd configs
├── CLAUDE.md                    # AI assistant guidance (symlink to homelab-docs)
├── .gitignore                   # Git ignore rules
└── README.md                    # This file
```

**Documentation repository** (`homelab-docs`, private):
- Complete architecture documentation
- Migration guides and runbooks
- AI workspace and conversation logs
- Desktop environment configurations

## 🚀 Quick Start

### Prerequisites

1. **GitHub repositories created:**
   - Main repo: `homelab-infrastructure` (this repo)
   - Secrets repo: `homelab-secrets` (private)

2. **Server setup:**
   - Docker and Docker Compose installed
   - External network created: `docker network create caddy_net`
   - Portainer deployed and accessible

### Deploy a Stack via Portainer

1. **In Portainer UI:**
   - Navigate to: **Stacks → Add Stack → Repository**

2. **Configure Git source:**
   - Repository URL: `https://github.com/YOUR_USERNAME/homelab-infrastructure`
   - Reference: `refs/heads/main`
   - Compose path: `stacks/STACK_NAME/docker-compose.yml`

3. **Add secrets:**
   - Use `.env.template` as reference
   - Add environment variables in Portainer UI, or
   - Link secrets from `homelab-secrets` repo on server

4. **Enable auto-sync (optional):**
   - Check "Automatic updates"
   - Configure webhook for push-triggered deployments

See documentation repository (`homelab-docs`) for detailed deployment guides.

## 🔐 Secrets Management

**Secrets are NOT in this repository!**

- `.env.template` files show required variables
- Actual secrets live in separate **private** repository: `homelab-secrets`
- Deploy secrets to server at: `~/homelab-secrets/stacks/STACK_NAME/.env`
- Reference in Portainer or use Docker Secrets

See secrets repo README for deployment instructions.

## 🌐 Active Services

All services accessible via `https://<subdomain>.rabalski.eu`:

| Service | Subdomain | Description | Migration Status |
|---------|-----------|-------------|------------------|
| **Critical Services** | | | |
| AdGuard Home | `sink` | DNS & ad blocking | Pending |
| Caddy | N/A | Reverse proxy (all traffic) | Manual deploy |
| Home Assistant | `dom` | Home automation (Zigbee) | Pending |
| Nextcloud AIO | `cloud` | File sync & collaboration | Manual deploy |
| Portainer | `portainer` | Container management | Manual deploy |
| Vaultwarden | `21376942` | Password manager | Pending |
| **Monitoring & Tools** | | | |
| Monitoring Stack | `prometheus`, `grafana` | Network monitoring | Pending |
| Changedetection.io | `watch` | Website monitoring | Not started |
| Glance | `deck` | Dashboard | Not started |
| Speedtest Tracker | `speedtest` | Internet speed tracking | Not started |
| **Productivity** | | | |
| n8n | `n8n` | Workflow automation | **Test case** ⭐ |
| n.eko | `kicia` | Browser isolation (Firefox) | Not started |
| SearXNG | `search` | Metasearch engine | Not started |
| Dumbpad | `pad` | Note-taking/pastebin | Not started |
| Marreta | `ram` | (TBD) | Not started |
| **Infrastructure** | | | |
| Tailscale | N/A | VPN (systemd service) | Docs only |
| Cloudflare DDNS | N/A | Dynamic DNS (TBD if needed) | Evaluate |

**Total:** 17 services

## 📖 Documentation

All documentation is in the separate `homelab-docs` private repository:

- **Architecture Overview**: Complete network topology, service catalog, data layout
- **Deployment Guides**: Step-by-step stack deployment procedures
- **Migration Documentation**: narsis migration summary and lessons learned
- **Disaster Recovery**: Rebuild from scratch procedures
- **Workspace**: AI-assisted conversation logs organized by topic

## 🛠️ Common Operations

### Deploy new service

1. Create stack directory: `stacks/SERVICE_NAME/`
2. Add `docker-compose.yml` with `caddy_net` network
3. Create `.env.template` for required variables
4. Add Caddy vhost block to `stacks/caddy/Caddyfile`
5. Deploy via Portainer Git integration
6. Add DNS rewrite in AdGuard Home

### Update existing stack

**If using Git auto-sync:**
```bash
# Edit locally
vim stacks/SERVICE_NAME/docker-compose.yml

# Commit and push
git add stacks/SERVICE_NAME/
git commit -m "Update SERVICE_NAME configuration"
git push

# Portainer auto-redeploys (if webhook configured)
```

**If using manual trigger:**
- Push changes to GitHub
- In Portainer: Stack → **Pull and redeploy**

### Sync configs to server (legacy method)

For services not yet migrated to Portainer Git:
```bash
rsync -av stacks/SERVICE_NAME/ user@clockworkcity:/path/on/server/
```

## 🔄 Migration Status (2025-11-26)

**Repository published to GitHub** ✅

**Services migrated to narsis** (10 of 17):
- ✅ Glance, SearXNG, Changedetection.io
- ✅ Dumbpad, Browser-services, Marreta
- ✅ Speedtest Tracker, n.eko
- ✅ Monitoring stack (Prometheus + Grafana + Blackbox)
- ✅ n8n

**Services remaining on clockworkcity** (7):
- AdGuard Home (DNS)
- Home Assistant (USB device passthrough)
- Vaultwarden (requires careful backup)
- Nextcloud AIO (special deployment model)
- Caddy (edge server, reverse proxy)
- Portainer (bootstrap service)
- Tailscale (systemd service)

See `homelab-docs` repository for detailed migration documentation and lessons learned.

## 🏗️ Future Plans

- Complete service migration to narsis
- Implement GitHub Actions for compose file validation
- Add Renovate for automated dependency updates
- Expand monitoring with Loki for log aggregation
- Evaluate ZFS setup for narsis bulk storage

## 📝 Development

**Main PC:** `Almalexia` (OpenSUSE Tumbleweed)
- Shell: `zsh`
- Terminal: `ghostty`
- DE: Hyprland (Wayland, primary) / Plasma (secondary)

**Workflow:**
1. Edit configs in this repo
2. Commit and push to GitHub
3. Portainer pulls and deploys automatically
4. Test and validate
5. Document changes

## 🆘 Support

- **Issues**: Use GitHub Issues for bug reports
- **Documentation**: See `homelab-docs` repository for complete documentation

## 📜 License

Personal infrastructure - use at your own risk. No warranty provided.

---

**Last updated**: 2025-11-27
**Maintainer**: Kuba Rabalski
