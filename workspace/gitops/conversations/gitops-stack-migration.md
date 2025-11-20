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

---

## Session 2: Critical Services Migration (2025-11-20)

**Duration:** ~2 hours
**Status:** 3/16 services migrated, pre-migration safeguards created

### What Was Accomplished

#### 1. AdGuard Home Migration ✅

**Challenges encountered:**
- Container name mismatch (`adguardhome` vs `adguard` expected by Caddy)
- Port 3000 not initially exposed for setup wizard
- **Data loss:** Configuration not backed up before migration
  - Lost all DNS rewrites
  - Had to reconfigure from scratch

**Resolution:**
- Fixed container name to match Caddyfile
- Exposed port 3000 temporarily for initial setup
- Completed setup wizard and reconfigured DNS rewrites
- Removed port 3000 after setup complete
- Migration successful ✅

**Lessons learned:**
- Always backup BEFORE stopping containers
- Container names must match Caddy reverse proxy expectations
- Temporary ports may be needed for setup wizards

#### 2. Pre-Migration Checklist Created 🛡️

**File:** `docs/pre-migration-checklist.md`

Created comprehensive safeguards to prevent future data loss:
- Universal pre-migration steps (backup, verify, document)
- Service-specific checklists (AdGuard, Vaultwarden, HA, Nextcloud)
- Red flags that should stop migration
- Rollback plan requirements
- Documented AdGuard data loss incident

**Key sections:**
- Backup procedures for bind mounts and volumes
- Verification steps before migration
- Rollback procedures
- Service-specific considerations

#### 3. Home Assistant Migration ✅

**Proper process followed:**
- ✅ Backup taken FIRST (learned from AdGuard mistake)
- ✅ Volume identified: `homeassistant_ha_config`
- ✅ Configured as external volume (preserves data)
- ✅ Added Glance labels
- ✅ Created .env.template and README.md
- ✅ All data preserved (automations, devices, configuration)
- ✅ Zigbee USB dongle working correctly

**Migration successful** - All smart home functionality intact

### Migration Progress

**Completed:** 3/16 services (19%)
- ✅ n8n (test case) - Session 1
- ✅ AdGuard Home (critical DNS) - Session 2
- ✅ Home Assistant (smart home) - Session 2

**Remaining Critical:**
- ⏳ Vaultwarden (passwords - requires extreme care!)
- ⏳ Monitoring stack (Prometheus + Grafana)

**Phase 3 (Medium):**
- SearXNG, Changedetection, Glance, n.eko

**Phase 4 (Low):**
- Speedtest Tracker, Dumbpad, Marreta

**Infrastructure (Manual):**
- Caddy, Portainer, Nextcloud AIO, Tailscale

### Files Created/Updated

**New files:**
- `docs/pre-migration-checklist.md` - Comprehensive safety checklist
- `stacks/homeassistant/.env.template` - Environment variables
- `stacks/homeassistant/README.md` - Full documentation

**Updated files:**
- `stacks/adguardhome/docker-compose.yml` - Fixed container name, ports
- `stacks/adguardhome/README.md` - Complete DNS rewrites list
- `stacks/homeassistant/docker-compose.yml` - External volume, Glance labels

### Git Commits Today

1. `fix: correct AdGuard container name to match Caddyfile`
2. `fix: expose port 3000 for AdGuard initial setup`
3. `cleanup: remove port 3000 from AdGuard after setup complete`
4. `docs: add pre-migration checklist and safeguards`
5. `feat: prepare Home Assistant for migration`

### Key Learnings

#### What Went Well ✅
- Pre-migration checklist prevented data loss on Home Assistant
- External volume configuration preserved all HA data
- Glance labels working for dashboard discovery
- GitOps workflow functioning smoothly

#### What Could Be Improved ⚠️
- Should have backed up AdGuard before migration
- Need to verify container names against Caddyfile expectations
- Port requirements should be checked beforehand

#### Process Improvements 📝
- **Always** follow pre-migration checklist
- **Always** backup before stopping containers
- **Always** verify data exists after backup
- **Always** test restore procedure (at least mentally)

### Next Session Priorities

1. **Vaultwarden migration** (EXTREME CARE REQUIRED)
   - Full backup with verification
   - Export via Bitwarden CLI
   - Test restore on separate instance
   - Have emergency password access ready
   
2. **Monitoring stack** (Multi-container complexity)
   - Good test for complex stacks
   - Already has compose file and configs

3. **Easy wins** (Build confidence)
   - Marreta (stateless)
   - Glance (dashboard)
   - Changedetection

### Statistics

**Total time invested:** ~5 hours (across 2 sessions)
**Services migrated:** 3/16 (19%)
**Documentation created:** 8 major files
**Lines of infrastructure code:** ~900+
**Git commits:** 10+

### Current State

**All migrated services:**
- ✅ Accessible via HTTPS
- ✅ Portainer has full control
- ✅ Auto-sync enabled (5 min polling)
- ✅ Glance labels configured
- ✅ Documented with README

**Infrastructure health:**
- DNS working (AdGuard Home)
- Smart home working (Home Assistant)
- Workflow automation working (n8n)
- All services on `caddy_net`
- TLS certificates valid

---

**Session 2 completed successfully!** 🎉

*Last updated: 2025-11-20*
