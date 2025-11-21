# GitOps Migration - Quick Reference

**Last Updated:** 2025-11-21
**Main Repo:** https://github.com/JakuRab/homelab-infrastructure
**Secrets Repo:** https://github.com/JakuRab/homelab-secrets (private)

---

## Current Progress

**Migrated:** 13/13 services (100%) ✅ COMPLETE!

### ✅ All Migrations Complete
1. **n8n** - https://n8n.rabalski.eu (workflow automation)
2. **AdGuard Home** - https://sink.rabalski.eu (DNS)
3. **Home Assistant** - https://dom.rabalski.eu (smart home)
4. **Vaultwarden** - https://21376942.rabalski.eu (passwords)
5. **Monitoring Stack** - Prometheus + Grafana + Blackbox
6. **Glance** - https://deck.rabalski.eu (dashboard)
7. **Dumbpad** - https://pad.rabalski.eu (notepad)
8. **Speedtest Tracker** - https://speedtest.rabalski.eu (network testing)
9. **SearXNG** - https://search.rabalski.eu (search engine)
10. **Changedetection.io** - https://watch.rabalski.eu (website monitoring)
11. **n.eko** - https://kicia.rabalski.eu (browser sharing)
12. **Browser Services** - Selenium Grid + browserless-chrome (support services)
13. **Marreta** - https://ram.rabalski.eu (paywall bypass)

### Infrastructure Services (Manual - By Design)
- **Caddy** - Too critical, manual deployment
- **Portainer** - Bootstrap service
- **Nextcloud AIO** - Special deployment model
- **Tailscale** - systemd service (not containerized)

---

## Server Info

- **Hostname:** clockworkcity
- **OS:** Ubuntu 24.04.3 LTS
- **SSH:** `ssh clockworkcity` (user: sothasil)
- **Access:** LAN (192.168.1.10) + Tailscale only
- **Portainer:** https://portainer.rabalski.eu

---

## Key Paths on Server

```
/opt/                          # Most service data directories
├── adguardhome/
├── glance/
├── homeassistant/
├── n8n/
└── vaultwarden/

/home/sothasil/                # Some services
└── vaultwarden/data/          # Actual Vaultwarden location

/srv/configs/net_monitor/      # Monitoring configs
/mnt/ncdata/                   # Nextcloud data (dedicated SSD)
```

---

## Standard Migration Workflow

### 1. Pre-Migration (CRITICAL!)
```bash
# SSH to server
ssh clockworkcity

# Identify data location
docker inspect SERVICE_NAME | grep -A 5 "Mounts"

# Backup data volumes
docker run --rm -v SERVICE_volume:/data -v $(pwd):/backup \
  alpine tar czf /backup/SERVICE-backup-$(date +%Y%m%d).tar.gz -C /data .

# OR backup bind mount
sudo tar czf ~/SERVICE-backup-$(date +%Y%m%d).tar.gz /path/to/data/

# Verify backup exists and has size
ls -lh ~/SERVICE-backup-*.tar.gz
```

### 2. Update Git Repository (Local)
```bash
cd /home/kuba/aiTools

# Ensure docker-compose.yml is correct
# - Container name matches Caddyfile expectations
# - Volumes match actual server paths
# - All environment variables defined
# - Glance labels added

# Push to GitHub
git add stacks/SERVICE_NAME/
git commit -m "feat: prepare SERVICE_NAME for migration"
git push
```

### 3. Deploy via Portainer

**In Portainer UI:**
1. Stacks → Add Stack → Repository
2. **Repository URL:** `https://github.com/JakuRab/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/SERVICE_NAME/docker-compose.yml`
5. **Environment variables:** Copy from `~/homelab-secrets/stacks/SERVICE_NAME/.env`
6. **Automatic updates:** ✅ Enable (5 min polling)
7. Deploy stack

### 4. Verify Migration
```bash
# Check container status
ssh clockworkcity 'docker ps | grep SERVICE_NAME'

# Check logs
ssh clockworkcity 'docker logs SERVICE_NAME'

# Test service URL
curl -I https://SERVICE.rabalski.eu

# Verify in Portainer
# - Check "Full Control" (not "Limited")
# - Auto-sync enabled
```

---

## Common Issues & Fixes

### Container Name Mismatch
**Problem:** Caddy can't find container
**Fix:** Ensure `container_name` in docker-compose.yml matches Caddyfile reverse proxy target

### Path Mismatch
**Problem:** Container crash, missing data
**Fix:** Use `docker inspect` to find actual paths, update compose file

### Missing Environment Variables
**Problem:** Container crash-loop on startup
**Fix:** Check logs, add missing required env vars to compose file or Portainer UI

### SMTP/Optional Features
**Problem:** Crash due to incomplete optional config
**Fix:** Remove or comment out optional env vars unless fully configured

### Secrets with Newlines
**Problem:** Authentication fails
**Fix:** Recreate secret files with `echo -n "password" > /path/to/secret` (no trailing newline)

---

## Docker Volume Management

### Named Volumes (Auto-Managed)
```yaml
volumes:
  service_data:  # Created as stackname_service_data

services:
  app:
    volumes:
      - service_data:/data
```
**Behavior:** Automatically reused if stack name matches. Persists through redeployments.

### External Volumes (Pre-Existing)
```yaml
volumes:
  ha_config:
    external: true
    name: homeassistant_ha_config

services:
  homeassistant:
    volumes:
      - ha_config:/config
```
**Use case:** Reusing volumes from previous deployments

### Bind Mounts (Server Paths)
```yaml
services:
  app:
    volumes:
      - /opt/service/data:/data
```
**Behavior:** Direct mount from host filesystem. Verify paths exist on server.

---

## Network Configuration

All services must be on `caddy_net`:
```yaml
networks:
  caddy_net:
    external: true

services:
  app:
    networks:
      - caddy_net
```

---

## Glance Dashboard Labels

Add to every service for automatic discovery:
```yaml
services:
  app:
    labels:
      - "glance.enable=true"
      - "glance.title=Service Name"
      - "glance.url=https://service.rabalski.eu"
      - "glance.icon=si:iconname"  # Simple Icons
```

---

## Git Commit Format

```bash
# New features/preparations
git commit -m "feat: prepare SERVICE for migration"

# Fixes
git commit -m "fix: correct SERVICE container name"

# Documentation
git commit -m "docs: add SESSION notes"

# All commits include auto-generated footer
```

---

## Critical Lessons Learned

1. **ALWAYS backup BEFORE stopping containers** (learned from AdGuard data loss)
2. **Verify container names match Caddyfile** (AdGuard: `adguardhome` not `adguard`)
3. **Check actual paths with `docker inspect`** (Vaultwarden was in `/home/sothasil/` not `/opt/`)
4. **Named volumes require matching stack names** (Monitoring: stack must be named `net_monitor`)
5. **Remove incomplete optional env vars** (Vaultwarden SMTP crash)
6. **Secrets need no trailing newlines** (Glance AdGuard auth)
7. **Pre-migration checklist prevents disasters** (See `docs/pre-migration-checklist.md`)

---

## Quick Commands

```bash
# Check what's running on server
ssh clockworkcity 'docker ps --format "table {{.Names}}\t{{.Status}}"'

# Check specific service logs
ssh clockworkcity 'docker logs SERVICE_NAME --tail 50'

# Check Docker volumes
ssh clockworkcity 'docker volume ls'

# Inspect container mounts
ssh clockworkcity 'docker inspect SERVICE_NAME | grep -A 10 "Mounts"'

# Push changes to Git
cd /home/kuba/aiTools && git add . && git commit -m "MESSAGE" && git push

# Update secrets on server
ssh clockworkcity 'cd ~/homelab-secrets && git pull'
```

---

## Repository Structure

```
/home/kuba/aiTools/
├── stacks/              # 16 service configurations
│   ├── SERVICE_NAME/
│   │   ├── docker-compose.yml
│   │   ├── .env.template
│   │   └── README.md
├── docs/                # Migration documentation
├── scripts/             # Automation scripts
└── workspace/gitops/    # Session notes
```

---

## GitOps Complete! 🎉

**All migratable services are now under GitOps control.**

### What's Next?

**For comprehensive operations guide, see:** `GITOPS_OPERATIONS_GUIDE.md`
- Adding new services
- Server migration procedures
- Common operations
- Troubleshooting
- Best practices

**For future deployments:**
1. Follow patterns in existing stacks
2. Use Portainer Git integration
3. Document with .env.template and README.md
4. Enable auto-sync (5 min polling)
5. Add Glance labels for discovery

---

**For detailed history, see:** `workspace/gitops/conversations/gitops-stack-migration.md`
**For pre-migration safety:** `docs/pre-migration-checklist.md`
**For full service details:** `docs/migration-tracker.md`
