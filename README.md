# Homelab Infrastructure

GitOps-managed homelab infrastructure running on Docker with Portainer orchestration.

## 🏗️ Architecture Overview

- **Reverse Proxy**: Caddy with Cloudflare DNS-01 ACME
- **Network**: Single external Docker network (`caddy_net`) for all services
- **DNS**: Split-horizon (Cloudflare public + AdGuard Home internal)
- **Access**: LAN (192.168.1.0/24) + Tailscale VPN only (private-by-default)
- **Orchestration**: Portainer CE with Git auto-sync
- **Server**: `clockworkcity` (Ubuntu 24.04.3 LTS)

## 📁 Repository Structure

```
.
├── stacks/                      # Docker Compose stacks
│   ├── caddy/                  # Reverse proxy (custom build with Cloudflare plugin)
│   ├── n8n/                    # Workflow automation
│   ├── home-assistant/         # Home automation
│   ├── monitoring/             # Prometheus + Grafana + Blackbox
│   ├── portainer/              # Container management
│   └── ...                     # Other services
├── linux/                       # Desktop environment configs
│   ├── configs/
│   │   ├── hyprland/           # Wayland compositor (Almalexia workstation)
│   │   └── nvim/               # Editor documentation
├── homelabbing/                 # Legacy structure (deprecated)
│   ├── homelab.md              # Architecture documentation
│   └── convos/                 # Historical setup notes
├── docs/                        # Documentation
│   ├── deployment.md           # How to deploy stacks
│   ├── portainer-setup.md      # Portainer Git integration
│   └── disaster-recovery.md    # Complete rebuild procedures
├── scripts/                     # Automation scripts
│   ├── init-server.sh          # Fresh server setup
│   └── deploy-stack.sh         # Stack deployment helper
└── README.md                    # This file
```

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

See [`docs/deployment.md`](docs/deployment.md) for detailed walkthrough.

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

**Total:** 17 services • See **[Migration Tracker](docs/migration-tracker.md)** for detailed information

## 📖 Documentation

- **[Architecture Overview](homelabbing/homelab.md)**: Complete network topology, service catalog, data layout
- **[Deployment Guide](docs/deployment.md)**: Step-by-step stack deployment
- **[Portainer Setup](docs/portainer-setup.md)**: Git integration and webhook configuration
- **[Disaster Recovery](docs/disaster-recovery.md)**: Rebuild from scratch procedures

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

## 🔄 Migration Status

**Total Services:** 17 (see [`docs/migration-tracker.md`](docs/migration-tracker.md) for complete inventory)

**Phase 1 - Foundation:**
- [x] Git repository setup
- [x] Secrets management structure
- [x] Documentation framework
- [ ] Push to GitHub
- [ ] n8n test migration ⭐

**Phase 2 - Critical Services:**
- [ ] AdGuard Home (DNS)
- [ ] Home Assistant
- [ ] Vaultwarden (requires careful backup)
- [ ] Monitoring stack

**Phase 3 - Medium Priority:**
- [ ] SearXNG
- [ ] Changedetection.io
- [ ] Glance
- [ ] n.eko

**Phase 4 - Low Priority:**
- [ ] Speedtest Tracker
- [ ] Dumbpad
- [ ] Marreta
- [ ] Cloudflare DDNS (evaluate if needed)

**Infrastructure (Keep Manual):**
- [x] Caddy (too critical for auto-deploy)
- [x] Portainer (bootstrap service)
- [x] Nextcloud AIO (special deployment model)
- [x] Tailscale (systemd service, not containerized)

See **[Migration Tracker](docs/migration-tracker.md)** for detailed status and service information.

## 🏗️ Future Plans

- Migrate to Supermicro platform (see `homelabbing/homelab.md` §15)
- Implement GitHub Actions for validation
- Add Renovate for automated dependency updates
- Expand monitoring with Loki for log aggregation

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
- **Discussions**: Architecture questions and ideas
- **Documentation**: Start with `homelabbing/homelab.md`

## 📜 License

Personal infrastructure - use at your own risk. No warranty provided.

---

**Last updated**: 2025-11-18
**Maintainer**: Kuba Rabalski
