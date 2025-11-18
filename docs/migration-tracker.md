# Service Migration Tracker

Complete inventory and migration status for all homelab services.

## Migration Overview

**Total Services:** 17
**Migrated:** 0
**In Progress:** 1 (n8n - test case)
**Pending:** 16

---

## Service Inventory

### ✅ Already in Repository Structure

| Service | Subdomain | Compose File | Stack Dir | Status |
|---------|-----------|--------------|-----------|--------|
| Caddy | N/A (reverse proxy) | ✅ | `stacks/caddy/` | Needs review |
| Home Assistant | `dom` | ✅ | `stacks/homeassistant/` | Pending |
| n8n | `n8n` | ✅ | `stacks/n8n/` | **TEST CASE** |
| Monitoring Stack | `prometheus`, `grafana` | ✅ | `stacks/net_monitor/` | Pending |
| Portainer | `portainer` | ✅ | `stacks/portainer/` | Bootstrap (manual) |

### ⏳ Need to Create Stack Directories

| Service | Subdomain | Container Name | Priority | Notes |
|---------|-----------|----------------|----------|-------|
| AdGuard Home | `sink` | `adguardhome` | **HIGH** | DNS critical |
| Vaultwarden | `21376942` | `vaultwarden` | **HIGH** | Secrets export needed |
| Nextcloud AIO | `cloud` | `nextcloud-aio-*` | **HIGH** | Special deployment |
| SearXNG | `search` | `searxng` | MEDIUM | Metasearch engine |
| Changedetection.io | `watch` | `changedetection` | MEDIUM | Website monitoring |
| Glance | `deck` | `glance` | MEDIUM | Dashboard |
| n.eko | `kicia` | `neko` | MEDIUM | Browser isolation |
| Marreta | `ram` | `marreta` | LOW | (Purpose?) |
| Dumbpad | `pad` | `dumbpad` | LOW | Note-taking |
| Speedtest Tracker | `speedtest` | `speedtest-tracker` | LOW | Network testing |
| Cloudflare DDNS | N/A | `cloudflare-ddns` | LOW | May be redundant |

---

## Detailed Service Information

### 1. AdGuard Home
- **Subdomain:** `sink.rabalski.eu`
- **Purpose:** DNS server with ad-blocking, DNS rewrites for internal routing
- **Critical:** YES - Required for split-horizon DNS
- **Data Location:** `/opt/adguardhome/conf/`, `/opt/adguardhome/work/`
- **Secrets:** Admin password
- **Special Notes:** Contains DNS rewrites for all `*.rabalski.eu` domains
- **Migration Priority:** **HIGH** - Critical infrastructure

**Stack Files Needed:**
- [ ] `stacks/adguardhome/docker-compose.yml`
- [ ] `stacks/adguardhome/.env.template`
- [ ] `stacks/adguardhome/README.md`
- [ ] Backup/restore docs for DNS rewrites

---

### 2. Caddy
- **Subdomain:** N/A (listens on :443 for all `*.rabalski.eu`)
- **Purpose:** Reverse proxy with automatic HTTPS (Cloudflare DNS-01)
- **Critical:** YES - All services depend on it
- **Data Location:** `/opt/caddy/data/`, `/opt/caddy/config/`
- **Secrets:** `CF_API_TOKEN` (Cloudflare)
- **Special Notes:** Custom Dockerfile for Cloudflare DNS plugin
- **Migration Priority:** **HIGH** - But stay on manual deployment (too critical)

**Status:** ✅ Already in `stacks/caddy/`

**Action Items:**
- [ ] Review current setup
- [ ] Document manual deployment workflow
- [ ] Keep on server-side deployment (don't migrate to Portainer Git)
- [ ] Create deployment runbook

---

### 3. Changedetection.io
- **Subdomain:** `watch.rabalski.eu`
- **Purpose:** Website change monitoring and notifications
- **Critical:** NO
- **Data Location:** `/opt/changedetection/datastore/`
- **Secrets:** API tokens for notifications (optional)
- **Migration Priority:** MEDIUM

**Stack Files Needed:**
- [ ] `stacks/changedetection/docker-compose.yml`
- [ ] `stacks/changedetection/.env.template`
- [ ] `stacks/changedetection/README.md`

---

### 4. Cloudflare DDNS
- **Status:** ❌ **SERVICE DOES NOT EXIST**
- **Finding:** No Cloudflare DDNS service currently deployed in infrastructure
- **Reason listed:** May have been planned but never implemented

**Investigation Results:**
- No compose files found
- No container running
- No Caddyfile entries
- Caddy only updates TXT records for ACME (not A/AAAA records)

**Do you need DDNS?**
- **If public IP is static:** NO - service not needed
- **If public IP is dynamic:** YES - deploy DDNS service

**Action Required:**
1. Test public IP stability for 1 week:
   ```bash
   # Monitor IP changes
   0 */6 * * * echo "$(date): $(curl -s https://api.ipify.org)" >> ~/ip-log.txt
   ```
2. If IP is static → Remove from inventory
3. If IP changes → Create and deploy DDNS stack

**Stack Files (only if needed):**
- [ ] Confirm IP is dynamic
- [ ] `stacks/cloudflare-ddns/docker-compose.yml`
- [ ] `stacks/cloudflare-ddns/.env.template`
- [ ] `stacks/cloudflare-ddns/README.md`

**Recommended Image (if deploying):** `oznu/cloudflare-ddns`

---

### 5. Dumbpad
- **Subdomain:** `pad.rabalski.eu`
- **Purpose:** Simple note-taking/pastebin
- **Critical:** NO
- **Data Location:** `/opt/dumbpad/data/`
- **Secrets:** None (or basic auth)
- **Migration Priority:** LOW

**Stack Files Needed:**
- [ ] `stacks/dumbpad/docker-compose.yml`
- [ ] `stacks/dumbpad/.env.template`
- [ ] `stacks/dumbpad/README.md`

---

### 6. Glance
- **Subdomain:** `deck.rabalski.eu`
- **Purpose:** Homepage dashboard with service links
- **Critical:** NO (convenience)
- **Data Location:** `/opt/glance/config.yml`
- **Secrets:** None
- **Special Notes:** Uses Glance labels from other containers
- **Migration Priority:** MEDIUM

**Stack Files Needed:**
- [ ] `stacks/glance/docker-compose.yml`
- [ ] `stacks/glance/.env.template`
- [ ] `stacks/glance/README.md`
- [ ] `stacks/glance/glance.yml` (dashboard config)

---

### 7. Home Assistant
- **Subdomain:** `dom.rabalski.eu`
- **Purpose:** Home automation platform (Zigbee via SONOFF dongle)
- **Critical:** YES (for smart home)
- **Data Location:** `/opt/homeassistant/config/`
- **Secrets:** Various integrations (API keys, passwords)
- **Special Notes:** USB device passthrough for Zigbee dongle
- **Migration Priority:** **HIGH**

**Status:** ✅ Compose file exists in `stacks/homeassistant/`

**Action Items:**
- [ ] Review existing docker-compose.yml
- [ ] Create .env.template
- [ ] Document USB device configuration
- [ ] Create README.md
- [ ] Document backup/restore for automations

---

### 8. Marreta
- **Subdomain:** `ram.rabalski.eu`
- **Purpose:** Paywall bypass and reading accessibility tool (self-hosted alternative to 12ft.io)
- **Critical:** NO
- **Data Location:** None (stateless service)
- **Secrets:** None required
- **Special Notes:** Removes paywalls, ads, and distractions from web articles
- **Docker Image:** `ghcr.io/tiagocoutinh0/marreta:latest`
- **Migration Priority:** LOW

**Stack Files Needed:**
- [ ] `stacks/marreta/docker-compose.yml`
- [ ] `stacks/marreta/.env.template` (likely not needed - stateless)
- [ ] `stacks/marreta/README.md`

**Resources:**
- Main project: https://github.com/manualdousuario/marreta
- Public instance: https://marreta.pcdomanual.com

---

### 9. n8n
- **Subdomain:** `n8n.rabalski.eu` (not yet in Caddyfile)
- **Purpose:** Workflow automation
- **Critical:** NO (but useful)
- **Data Location:** `/opt/n8n/data/`
- **Secrets:** N8N_ENCRYPTION_KEY, host configs
- **Migration Priority:** **TEST CASE** ⭐

**Status:** ✅ Stack ready, documentation complete

**Action Items:**
- [x] Stack directory created
- [x] .env.template created
- [x] README.md created
- [ ] Add to Caddyfile
- [ ] Test Portainer Git deployment
- [ ] Configure webhook
- [ ] Validate full workflow

---

### 10. n.eko (Browser Isolation)
- **Subdomain:** `kicia.rabalski.eu`
- **Purpose:** Firefox browser accessible via WebRTC
- **Critical:** NO
- **Data Location:** Minimal (session-based)
- **Secrets:** Password for browser access
- **Special Notes:** Requires special capabilities (SYS_ADMIN?)
- **Migration Priority:** MEDIUM

**Stack Files Needed:**
- [ ] `stacks/neko/docker-compose.yml`
- [ ] `stacks/neko/.env.template`
- [ ] `stacks/neko/README.md`
- [ ] Document security considerations

---

### 11. Monitoring Stack (Prometheus + Grafana + Blackbox)
- **Subdomains:** `prometheus.rabalski.eu`, `grafana.rabalski.eu`
- **Purpose:** Network monitoring, metrics, alerting
- **Critical:** NO (but very useful)
- **Data Location:** `/srv/configs/net_monitor/`
- **Secrets:** Grafana admin password
- **Special Notes:** Multi-container stack with file_sd targets
- **Migration Priority:** MEDIUM (good test for complex stacks)

**Status:** ✅ Already in `stacks/net_monitor/`

**Action Items:**
- [ ] Review existing setup
- [ ] Verify all configs present
- [ ] Create comprehensive README.md
- [ ] Document adding new monitoring targets
- [ ] Test migration after n8n succeeds

---

### 12. Nextcloud AIO
- **Subdomain:** `cloud.rabalski.eu`
- **Purpose:** File sync, collaboration, office suite
- **Critical:** YES (for data)
- **Data Location:** `/mnt/ncdata/` (dedicated SSD)
- **Secrets:** Master password, database credentials
- **Special Notes:**
  - Uses AIO mastercontainer (special deployment)
  - NOT a standard docker-compose stack
  - Proxied to `host.docker.internal:12000`
  - Data on dedicated mount point
- **Migration Priority:** **HIGH** (but complex)

**Stack Files Needed:**
- [ ] `stacks/nextcloud/docker-compose.yml` (for AIO master only)
- [ ] `stacks/nextcloud/.env.template`
- [ ] `stacks/nextcloud/README.md` (detailed AIO setup)
- [ ] Document backup/restore procedures
- [ ] Document upgrade procedures

**Special Considerations:**
- Cannot fully migrate to Portainer (AIO manages itself)
- Can document deployment in Git
- Focus on disaster recovery procedures

---

### 13. Portainer
- **Subdomain:** `portainer.rabalski.eu`
- **Purpose:** Docker container management UI
- **Critical:** YES (for management)
- **Data Location:** `/opt/portainer/data/`
- **Secrets:** Admin password (set in UI)
- **Special Notes:** Bootstrap service - deploys everything else
- **Migration Priority:** Keep manual deployment

**Status:** ✅ Already in `stacks/portainer/`

**Action Items:**
- [ ] Document manual deployment (don't migrate to Git)
- [ ] Keep as server-side deployment
- [ ] Document backup/restore of Portainer data
- [ ] Create disaster recovery procedure

---

### 14. SearXNG
- **Subdomain:** `search.rabalski.eu`
- **Purpose:** Privacy-respecting metasearch engine
- **Critical:** NO
- **Data Location:** Minimal (config files)
- **Secrets:** Secret key for sessions
- **Migration Priority:** MEDIUM

**Stack Files Needed:**
- [ ] `stacks/searxng/docker-compose.yml`
- [ ] `stacks/searxng/.env.template`
- [ ] `stacks/searxng/README.md`
- [ ] `stacks/searxng/settings.yml` (SearXNG config)

---

### 15. Speedtest Tracker
- **Subdomain:** `speedtest.rabalski.eu`
- **Purpose:** Automated internet speed testing and tracking
- **Critical:** NO
- **Data Location:** `/opt/speedtest-tracker/config/`, database
- **Secrets:** App key, database password
- **Migration Priority:** LOW

**Stack Files Needed:**
- [ ] `stacks/speedtest-tracker/docker-compose.yml`
- [ ] `stacks/speedtest-tracker/.env.template`
- [ ] `stacks/speedtest-tracker/README.md`

---

### 16. Vaultwarden
- **Subdomain:** `21376942.rabalski.eu`
- **Purpose:** Self-hosted Bitwarden password manager
- **Critical:** **EXTREMELY HIGH** - Contains all passwords
- **Data Location:** `/opt/vaultwarden/data/`
- **Secrets:** Admin token (hashed in Caddyfile), SMTP credentials
- **Special Notes:**
  - Already has basic auth in Caddy for /admin
  - Database contains encrypted password vault
  - MUST have reliable backup before any changes
- **Migration Priority:** **HIGH** (but be VERY careful)

**Stack Files Needed:**
- [ ] `stacks/vaultwarden/docker-compose.yml`
- [ ] `stacks/vaultwarden/.env.template`
- [ ] `stacks/vaultwarden/README.md`
- [ ] **CRITICAL:** Backup/restore documentation
- [ ] Export procedure before migration
- [ ] Test restore procedure

**Safety Checklist Before Migration:**
- [ ] Full backup of `/opt/vaultwarden/data/`
- [ ] Export all passwords to encrypted file
- [ ] Test restore on separate instance
- [ ] Document rollback procedure
- [ ] Have alternative password access ready

---

### 17. Tailscale (System Service)
- **Subdomain:** N/A (VPN overlay network)
- **Purpose:** Secure remote access, MagicDNS
- **Critical:** YES (for remote access)
- **Data Location:** `/var/lib/tailscale/`
- **Secrets:** Auth keys
- **Special Notes:**
  - NOT a Docker container (systemd service)
  - Already has hardening configs in repo
  - Health check timer configured
- **Migration Priority:** Document only (not containerized)

**Status:** ✅ Configs in `stacks/tailscale/`

**Action Items:**
- [ ] Already documented
- [ ] Create deployment guide
- [ ] No migration needed (stays as systemd service)

---

## Migration Strategy

### Phase 1: Foundation (Complete First)
1. ✅ Git repository setup
2. ✅ Secrets management structure
3. ✅ Documentation framework
4. ⏳ Push to GitHub
5. ⏳ **n8n test migration** (validates entire workflow)

### Phase 2: Critical Services (After n8n Success)
**Order:** Based on criticality and complexity

1. **AdGuard Home** - DNS critical, must work
2. **Home Assistant** - High value, medium complexity
3. **Vaultwarden** - EXTREME CARE, full backup first
4. **Monitoring Stack** - Complex multi-container test

### Phase 3: Medium Priority Services
5. **SearXNG** - Simple service
6. **Changedetection.io** - Simple service
7. **Glance** - Simple service
8. **n.eko** - Medium complexity

### Phase 4: Low Priority Services
9. **Speedtest Tracker** - Nice to have
10. **Dumbpad** - Nice to have
11. **Marreta** - TBD based on usage
12. **Cloudflare DDNS** - Evaluate if still needed

### Infrastructure Services (Keep Manual)
- **Caddy** - Too critical, stay on server-side deployment
- **Portainer** - Bootstrap service, manual deployment
- **Nextcloud AIO** - Special deployment, document only
- **Tailscale** - System service, not containerized

---

## Progress Tracking

### Migration Completion Checklist

For each service:
- [ ] Stack directory created
- [ ] `docker-compose.yml` created
- [ ] `.env.template` created with all variables
- [ ] Actual secrets added to secrets repo
- [ ] `README.md` with setup/troubleshooting
- [ ] Backup procedure documented
- [ ] Current deployment stopped
- [ ] Deployed via Portainer Git integration
- [ ] Service accessible and tested
- [ ] Webhook configured (if desired)
- [ ] Migration notes documented

### Repository Completion
- [ ] All services documented
- [ ] Migration tracker up to date
- [ ] Architecture diagram created
- [ ] Disaster recovery tested
- [ ] README.md updated with status

---

## Notes & Questions

### Vaultwarden Export Strategy

**Safe export options:**

1. **Bitwarden CLI Export:**
   ```bash
   # Install Bitwarden CLI
   npm install -g @bitwarden/cli

   # Login
   bw login --server https://21376942.rabalski.eu

   # Export (encrypted)
   bw export --format encrypted_json --password STRONG_PASSWORD > vault-backup.json

   # Store encrypted backup in safe location
   ```

2. **Database Backup:**
   ```bash
   # Stop Vaultwarden
   docker stop vaultwarden

   # Backup entire data directory
   tar -czf vaultwarden-full-backup-$(date +%Y%m%d).tar.gz /opt/vaultwarden/data/

   # Restart
   docker start vaultwarden
   ```

3. **Test Restore:**
   - Spin up test instance
   - Restore backup
   - Verify all data intact
   - Only then proceed with production migration

### ✅ Cloudflare DDNS - CLARIFIED

**Finding:** Service does NOT exist in current deployment
- **Status:** ❌ Not deployed (may have been planned but never implemented)
- **Caddy behavior:** Only updates TXT records for ACME challenges, NOT A/AAAA records
- **Current IP:** 31.178.228.90 (per homelab.md)

**Action Required:**
1. Monitor IP stability for 1 week (cron job to log IP changes)
2. **If static:** Remove from inventory (no service needed)
3. **If dynamic:** Deploy DDNS service using `oznu/cloudflare-ddns`

**Alternative:** Use Tailscale for remote access (IP never changes)

See [`docs/service-clarifications.md`](service-clarifications.md) for testing procedure.

### ✅ Marreta - CLARIFIED

**Identified as:** Paywall bypass and reading accessibility tool
- **Image:** `ghcr.io/tiagocoutinh0/marreta:latest`
- **Purpose:** Self-hosted alternative to 12ft.io for removing paywalls and distractions
- **Status:** ✅ Active and in use
- **Migration:** Phase 4 (low priority, stateless service)

See [`docs/service-clarifications.md`](service-clarifications.md) for full details.

---

**Last Updated:** 2025-11-18
**Next Review:** After n8n test migration completes
