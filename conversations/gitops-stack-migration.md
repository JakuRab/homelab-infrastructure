# GitOps Stack Migration - Session Notes

**Date:** 2025-11-18
**Duration:** ~3 hours
**Status:** Phase 1 complete, n8n test migration successful

---

## Overview

This session established a professional GitOps infrastructure for the homelab, migrating from manual Docker Compose deployments to Git-based management with Portainer auto-sync.

---

## What Was Accomplished

### 1. Repository Architecture Created

**Dual-repository structure:**
- **Main repo:** `https://github.com/JakuRab/homelab-infrastructure` (public)
- **Secrets repo:** `https://github.com/JakuRab/homelab-secrets` (private)

**Key files created:**
- `.gitignore` - Prevents committing secrets
- `README.md` - Repository overview with service table
- `GETTING_STARTED.md` - Quick start guide
- `SERVICE_INVENTORY.md` - Complete service reference

### 2. Documentation Suite

**In `docs/` directory:**
- `deployment.md` - Complete deployment procedures
- `portainer-setup.md` - Git integration & auto-sync configuration
- `disaster-recovery.md` - Rebuild from scratch procedures
- `migration-tracker.md` - Detailed status for all 16 services
- `n8n-migration-test.md` - Test migration walkthrough
- `service-clarifications.md` - Findings on Marreta and Cloudflare DDNS

### 3. n8n Test Migration (SUCCESS ✅)

**Steps completed:**
1. Created GitHub repositories
2. Pushed initial code
3. Cloned secrets repo to server (`~/homelab-secrets`)
4. Deployed n8n via Portainer Git integration
5. Configured 5-minute polling for auto-sync
6. Verified Portainer has full control (not "Limited")
7. Service accessible at https://n8n.rabalski.eu

**Webhook note:** GitHub webhooks can't reach Portainer due to `gate` firewall rules (LAN + Tailscale only). Using polling instead - this maintains security.

### 4. Stack Configurations Created

**9 new service stacks added to repository:**

| Service | docker-compose.yml | .env.template | README |
|---------|:------------------:|:-------------:|:------:|
| AdGuard Home | ✅ | ✅ | ✅ |
| Vaultwarden | ✅ | ✅ | ✅ |
| SearXNG | ✅ | ✅ | - |
| Changedetection | ✅ | - | - |
| Glance | ✅ | - | - |
| n.eko | ✅ | ✅ | - |
| Marreta | ✅ | - | - |
| Dumbpad | ✅ | - | - |
| Speedtest Tracker | ✅ | ✅ | - |

**All services include Glance labels** for automatic dashboard discovery.

### 5. Service Clarifications

**Marreta (`ram.rabalski.eu`):**
- Identified as paywall bypass / reading accessibility tool
- Self-hosted alternative to 12ft.io
- Image: `ghcr.io/tiagocoutinh0/marreta:latest`
- Stateless service, easy migration

**Cloudflare DDNS:**
- Service does NOT exist in current deployment
- Was listed but never implemented
- Action: Test if public IP is static (monitor for 1 week)
- If static, remove from inventory; if dynamic, deploy DDNS

---

## Current Repository Structure

```
/home/kuba/aiTools/
├── stacks/                      # 15 service stacks
│   ├── adguardhome/            # NEW
│   ├── caddy/                  # Existing
│   ├── changedetection/        # NEW
│   ├── dumbpad/                # NEW
│   ├── glance/                 # NEW
│   ├── homeassistant/          # Existing
│   ├── marreta/                # NEW
│   ├── n8n/                    # MIGRATED ✅
│   ├── neko/                   # NEW
│   ├── net_monitor/            # Existing
│   ├── portainer/              # Existing
│   ├── searxng/                # NEW
│   ├── speedtest-tracker/      # NEW
│   ├── tailscale/              # Existing
│   └── vaultwarden/            # NEW
├── docs/                        # Documentation
├── scripts/                     # Automation (initial-setup.sh)
├── .secrets-templates/          # Actual secrets (separate Git repo)
├── homelabbing/                 # Legacy (homelab.md still reference)
└── linux/                       # Desktop configs
```

---

## Migration Status

### Completed
- [x] Git repository setup
- [x] Secrets management structure
- [x] Documentation framework
- [x] n8n test migration
- [x] All stack configurations created

### Phase 2 - Critical Services (Next)
- [ ] AdGuard Home (DNS - affects all services)
- [ ] Home Assistant (needs .env.template)
- [ ] Vaultwarden (BACKUP FIRST!)
- [ ] Monitoring Stack

### Phase 3 - Medium Priority
- [ ] SearXNG
- [ ] Changedetection.io
- [ ] Glance
- [ ] n.eko

### Phase 4 - Low Priority
- [ ] Speedtest Tracker
- [ ] Dumbpad
- [ ] Marreta

### Infrastructure (Keep Manual)
- [x] Caddy - Too critical for auto-deploy
- [x] Portainer - Bootstrap service
- [x] Nextcloud AIO - Special deployment model
- [x] Tailscale - systemd service

---

## How to Continue Migration

### For Any Service

1. **In Portainer:**
   - Stacks → Add Stack → Repository
   - URL: `https://github.com/JakuRab/homelab-infrastructure`
   - Reference: `refs/heads/main`
   - Path: `stacks/SERVICE_NAME/docker-compose.yml`

2. **Add environment variables:**
   - Copy from `~/homelab-secrets/stacks/SERVICE_NAME/.env`
   - Or use values from `.env.template`

3. **Enable automatic updates:**
   - Check "Automatic updates"
   - Set fetch interval (5 minutes)

4. **Deploy**

### Before Migrating Vaultwarden

**CRITICAL - Do these steps first:**

1. Full backup:
   ```bash
   docker stop vaultwarden
   sudo tar -czf ~/vaultwarden-backup-$(date +%Y%m%d).tar.gz -C /opt/vaultwarden/data .
   docker start vaultwarden
   ```

2. Test restore on separate instance

3. Export via Bitwarden CLI (encrypted)

4. Have emergency password access ready

See `stacks/vaultwarden/README.md` for detailed procedures.

---

## Key Commands

### Push changes to GitHub
```bash
cd /home/kuba/aiTools
git add .
git commit -m "description of changes"
git push
```

### Check n8n auto-sync
- Portainer will pull changes within 5 minutes
- Check Stack → n8n for last update time

### Update secrets on server
```bash
ssh user@clockworkcity
cd ~/homelab-secrets
git pull
```

### Migrate a service
1. Stop current deployment: `docker stop SERVICE && docker rm SERVICE`
2. Deploy via Portainer Git integration
3. Verify service works
4. Check Portainer shows full control

---

## Technical Decisions Made

### 1. Polling vs Webhooks
**Decision:** Use 5-minute polling
**Reason:** GitHub webhooks blocked by Caddy `gate` (LAN + Tailscale only). Polling maintains security model while providing auto-sync.

### 2. Environment Variables
**Decision:** Enter in Portainer UI, not via .env files
**Reason:** Portainer Git integration doesn't auto-load .env files. UI approach keeps secrets visible in Portainer but never in main Git repo.

### 3. Secrets Repository
**Decision:** Separate private GitHub repo
**Reason:** Full GitOps approach - everything in version control but properly separated. Easy to sync across machines.

### 4. Services to Keep Manual
**Decision:** Caddy, Portainer, Nextcloud AIO stay on manual deployment
**Reason:** Too critical (Caddy), bootstrap dependency (Portainer), or special deployment model (Nextcloud AIO).

---

## Issues Encountered

### 1. GitHub Outage (Cloudflare)
**Problem:** GitHub returned 500 errors during push
**Resolution:** Waited for recovery (~20 minutes), retried push successfully

### 2. Webhook Connection Failed
**Problem:** GitHub webhook couldn't reach Portainer (403 Forbidden)
**Root cause:** Caddy `gate` blocks public internet
**Resolution:** Switched to polling-based auto-sync

### 3. Wrong Directory for Git Commands
**Problem:** Bash commands executed in .secrets-templates instead of main repo
**Resolution:** Always use `cd /home/kuba/aiTools` before Git operations

---

## Files to Review Before Next Session

1. `docs/migration-tracker.md` - Detailed status for each service
2. `stacks/vaultwarden/README.md` - Backup procedures before migration
3. `stacks/adguardhome/README.md` - DNS rewrite configuration
4. `SERVICE_INVENTORY.md` - Quick reference for all services

---

## Next Session Priorities

1. **Test n8n auto-sync** - Verify it picked up the Glance label changes
2. **Migrate AdGuard Home** - Critical DNS service
3. **Backup Vaultwarden** - Prepare for migration
4. **Update Home Assistant stack** - Add .env.template and README
5. **Monitor public IP** - Determine if DDNS is needed

---

## Useful Links

- **Main repo:** https://github.com/JakuRab/homelab-infrastructure
- **Secrets repo:** https://github.com/JakuRab/homelab-secrets
- **Portainer:** https://portainer.rabalski.eu
- **n8n:** https://n8n.rabalski.eu
- **GitHub status:** https://www.githubstatus.com/

---

## Summary

Today we successfully established a professional GitOps workflow for the homelab:

- **16 services** inventoried and documented
- **9 new stack configurations** created
- **1 service migrated** (n8n - test case)
- **Dual-repo architecture** for infrastructure + secrets
- **Auto-sync enabled** via Portainer polling

The foundation is complete. Future sessions can focus on migrating remaining services one by one, with all configurations and documentation already in place.

---

**Session completed successfully!** 🎉

*Last updated: 2025-11-18*
