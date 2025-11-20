# Pre-Migration Checklist

**⚠️ CRITICAL: Complete this checklist BEFORE migrating any service to Portainer Git**

This checklist prevents data loss and ensures safe migrations.

---

## Universal Pre-Migration Steps (ALL Services)

### 1. Identify Data Locations

```bash
# Check container volumes
docker inspect CONTAINER_NAME | grep -A 10 Mounts

# List all volumes
docker volume ls | grep SERVICE_NAME
```

Document:
- [ ] Volume mount paths
- [ ] Configuration file locations
- [ ] Database locations
- [ ] Any persistent data

### 2. Backup Everything

```bash
# Create backup directory
mkdir -p ~/backups/$(date +%Y%m%d)

# For bind mounts (e.g., /opt/SERVICE/):
sudo tar -czf ~/backups/$(date +%Y%m%d)/SERVICE-data.tar.gz \
  -C /opt/SERVICE .

# For named volumes:
docker run --rm \
  -v SERVICE_volume:/source:ro \
  -v ~/backups/$(date +%Y%m%d):/backup \
  alpine tar czf /backup/SERVICE-volume.tar.gz -C /source .

# Backup container config
docker inspect CONTAINER_NAME > ~/backups/$(date +%Y%m%d)/SERVICE-inspect.json
```

Checklist:
- [ ] All volumes backed up
- [ ] Configuration files backed up
- [ ] Container inspect saved
- [ ] Backup verified (can extract files)
- [ ] Backup stored in safe location

### 3. Document Current State

```bash
# Save current docker-compose (if exists)
docker compose -f /path/to/docker-compose.yml config > ~/backups/$(date +%Y%m%d)/SERVICE-compose.yml

# Save environment variables
docker inspect CONTAINER_NAME | jq '.[0].Config.Env' > ~/backups/$(date +%Y%m%d)/SERVICE-env.json

# Test the service is working
curl -I https://SERVICE.rabalski.eu
```

Checklist:
- [ ] Current compose file saved
- [ ] Environment variables documented
- [ ] Service tested and working
- [ ] Screenshots of critical settings (if GUI-based)

### 4. Verify Stack Configuration

Check the Git repository has:
- [ ] `stacks/SERVICE/docker-compose.yml` exists
- [ ] `.env.template` created (if secrets needed)
- [ ] README.md with service documentation
- [ ] Volume paths match current deployment
- [ ] Container names match Caddyfile (if applicable)
- [ ] All necessary ports exposed

### 5. Create Rollback Plan

Document:
- [ ] Exact commands to restore from backup
- [ ] Expected downtime
- [ ] Service dependencies (what else breaks if this fails?)
- [ ] Alternative access methods (IP, hosts file, etc.)

Example rollback commands:
```bash
# Stop Portainer-managed stack
# (via Portainer UI or: docker stop CONTAINER)

# Restore data
sudo rm -rf /opt/SERVICE/*
sudo tar -xzf ~/backups/YYYYMMDD/SERVICE-data.tar.gz -C /opt/SERVICE/

# Redeploy old way
cd /old/location
docker compose up -d
```

---

## Service-Specific Checklists

### Critical Services (Extra Caution Required)

#### AdGuard Home
- [ ] Export DNS rewrites list
- [ ] Screenshot all filter settings
- [ ] Backup `/opt/adguardhome/conf/AdGuardHome.yaml`
- [ ] Document custom DNS settings
- [ ] **Have alternative DNS ready** (router, /etc/hosts, or Cloudflare)

#### Vaultwarden
- [ ] Export vault via Bitwarden CLI (encrypted JSON)
- [ ] Full database backup
- [ ] Test restore on separate instance
- [ ] **Have emergency password access** (printed list, hardware key)
- [ ] Notify yourself - expect downtime

#### Home Assistant
- [ ] Backup `/opt/homeassistant/config/`
- [ ] Export automations
- [ ] Screenshot dashboards
- [ ] Document Zigbee device mappings
- [ ] **Verify USB device path** for Zigbee dongle

#### Nextcloud AIO
- [ ] Backup mastercontainer volume
- [ ] Export Nextcloud data
- [ ] **Note:** Cannot fully migrate to Portainer Git (special deployment)
- [ ] Document disaster recovery only

---

## Migration Day Checklist

### Before Stopping Current Container

1. [ ] Final backup completed
2. [ ] Service is currently working
3. [ ] Rollback plan tested (at least mentally walkthrough)
4. [ ] Off-peak hours chosen (if service is critical)
5. [ ] Alternative access configured (if DNS-dependent)

### During Migration

1. [ ] Stop container: `docker stop CONTAINER_NAME`
2. [ ] **Verify data still exists:** `ls -la /opt/SERVICE/`
3. [ ] Remove container: `docker rm CONTAINER_NAME`
4. [ ] **Double-check data:** `ls -la /opt/SERVICE/`
5. [ ] Deploy via Portainer Git
6. [ ] Verify data mounted correctly: `docker inspect NEW_CONTAINER | grep Mounts`

### After Migration

1. [ ] Service accessible
2. [ ] Data intact (login works, files present, etc.)
3. [ ] Portainer shows full control
4. [ ] Auto-sync configured (if desired)
5. [ ] Update migration tracker
6. [ ] Keep backup for at least 7 days

---

## Red Flags - STOP Migration

**Do NOT proceed if:**
- ❌ You don't have a backup
- ❌ You can't test the backup
- ❌ The service is business-critical and you're alone
- ❌ You don't understand what the service does
- ❌ Volume paths are unclear
- ❌ It's a production service and it's peak hours
- ❌ You haven't slept in 24 hours (seriously)

**In these cases:**
- Document everything
- Come back when you're prepared
- Ask for help if needed

---

## Lessons Learned

### 2025-11-20: AdGuard Home Data Loss

**What happened:**
- Migrated AdGuard Home to Portainer Git
- Old container stopped and removed
- Data directories existed but were EMPTY
- Lost all DNS rewrites and configuration

**Why it happened:**
- Did not backup AdGuardHome.yaml before migration
- Assumed data would persist from old deployment
- Old container might have used different volume paths

**Prevention:**
- Always backup BEFORE stopping container
- Verify backup contains expected files
- Check volume paths match between old and new deployment

### Future Incidents

(Document here as we encounter them)

---

## Quick Reference Commands

### Backup
```bash
# Single command for common bind mount
sudo tar -czf ~/backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /opt/SERVICE .
```

### Restore
```bash
# Single command restore
sudo tar -xzf ~/backup-TIMESTAMP.tar.gz -C /opt/SERVICE/
```

### Verify
```bash
# Check data exists
ls -la /opt/SERVICE/

# Check backup contents without extracting
tar -tzf ~/backup-TIMESTAMP.tar.gz | head -20
```

---

**Remember:** Backups are useless if you never test restoring them!

**Last Updated:** 2025-11-20
