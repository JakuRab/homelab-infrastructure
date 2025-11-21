# GitOps Operations Guide

**Purpose:** Comprehensive reference for managing Docker services via GitOps on this infrastructure
**Target:** Future migrations, new service deployments, disaster recovery
**Last Updated:** 2025-11-21

---

## Table of Contents

1. [Repository Architecture](#repository-architecture)
2. [Portainer GitOps Integration](#portainer-gitops-integration)
3. [Adding New Services](#adding-new-services)
4. [Server Migration Procedure](#server-migration-procedure)
5. [Common Operations](#common-operations)
6. [Troubleshooting](#troubleshooting)
7. [Best Practices](#best-practices)

---

## Repository Architecture

### Dual-Repository Model

**Public Repository:** `homelab-infrastructure`
- Location: https://github.com/JakuRab/homelab-infrastructure
- Contains: Docker Compose files, documentation, scripts
- Purpose: Infrastructure as Code (IaC)
- Safe to share publicly (no secrets)

**Private Repository:** `homelab-secrets`
- Location: https://github.com/JakuRab/homelab-secrets
- Contains: `.env` files with sensitive data
- Purpose: Secret management
- Must remain private

### Directory Structure

```
homelab-infrastructure/
├── stacks/                     # Service configurations
│   ├── SERVICE_NAME/
│   │   ├── docker-compose.yml  # Required
│   │   ├── .env.template       # Optional (documents required env vars)
│   │   ├── README.md           # Optional (service-specific docs)
│   │   └── configs/            # Optional (config files)
│   └── ...
├── docs/                       # General documentation
├── scripts/                    # Automation scripts
├── workspace/                  # Working notes
├── README.md                   # Repository overview
└── .gitignore                  # Prevents committing secrets

homelab-secrets/
└── stacks/
    ├── SERVICE_NAME/
    │   └── .env                # Actual secrets
    └── ...
```

### Critical Files

**`.gitignore`** (in homelab-infrastructure):
```gitignore
# Secrets
.env
*.env
!.env.template
**/secrets/
*.key
*.pem

# Sensitive configs
**/config.yml
!**/.env.template
```

---

## Portainer GitOps Integration

### How Auto-Sync Works

1. **Push to Git** → Changes committed to main branch
2. **Portainer polls** → Every 5 minutes, checks for updates
3. **Auto-redeploy** → If changes detected, redeploys stack
4. **Zero downtime** → Services updated automatically

### Deployment Configuration

**When creating a new stack in Portainer:**

| Field | Value | Notes |
|-------|-------|-------|
| Repository URL | `https://github.com/JakuRab/homelab-infrastructure` | Public repo |
| Reference | `refs/heads/main` | Track main branch |
| Compose path | `stacks/SERVICE_NAME/docker-compose.yml` | Relative path |
| Stack name | `SERVICE_NAME` | Must match for volume naming |
| Automatic updates | ✅ Enabled | |
| Fetch interval | 5 minutes | Polls every 5 min |
| Re-pull image | ✅ Enabled | Updates Docker images |
| Environment variables | Add via UI | From `homelab-secrets` repo |

### Environment Variables in Portainer

**Two approaches:**

1. **Via Portainer UI** (recommended):
   - Copy from `~/homelab-secrets/stacks/SERVICE_NAME/.env` on server
   - Paste into Portainer's environment variable section
   - Portainer stores them encrypted

2. **Via .env file** (not recommended for GitOps):
   - Portainer Git integration doesn't auto-load .env files
   - Would need manual update each time

### Webhook vs Polling

**Current setup:** Polling (5-minute intervals)

**Why not webhooks?**
- GitHub webhooks can't reach Portainer (blocked by Caddy `gate` directive)
- LAN + Tailscale only access maintains security
- Polling is reliable and sufficient for homelab use

---

## Adding New Services

### Step-by-Step Process

#### 1. Create Stack Directory Locally

```bash
cd /path/to/homelab-infrastructure
mkdir -p stacks/NEW_SERVICE
cd stacks/NEW_SERVICE
```

#### 2. Create docker-compose.yml

**Minimum viable compose file:**

```yaml
services:
  service-name:
    image: docker/image:tag
    container_name: service-name
    restart: unless-stopped
    environment:
      - ENV_VAR=${ENV_VAR}
    volumes:
      - service-data:/data
    labels:
      - "glance.name=Service Name"
      - "glance.icon=si:icon-name"
      - "glance.url=https://service.rabalski.eu"
      - "glance.description=Short description"
    networks:
      - caddy_net

volumes:
  service-data:

networks:
  caddy_net:
    external: true
```

**Key requirements:**
- Must connect to `caddy_net` for reverse proxy access
- Use `${ENV_VAR}` syntax for secrets
- Add Glance labels for dashboard discovery
- Use `restart: unless-stopped` for auto-recovery

#### 3. Create .env.template

```bash
# Service Name Configuration

# Required variables
VARIABLE_NAME=description_or_example_value

# Optional variables
OPTIONAL_VAR=default_value
```

**Purpose:**
- Documents what environment variables are needed
- Provides example values
- Helps future deployments

#### 4. Create README.md (Optional)

```markdown
# Service Name

Brief description of what this service does.

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| VAR_NAME | Yes | What it does | `value` |

## Data Persistence

- Volume: `service-data` at `/data`
- Purpose: What data is stored

## Backup Procedure

How to backup this service's data.

## Troubleshooting

Common issues and solutions.
```

#### 5. Push to Git

```bash
git add stacks/NEW_SERVICE/
git commit -m "feat: add NEW_SERVICE stack"
git push
```

#### 6. Add Secrets (if needed)

```bash
# On server
ssh clockworkcity
cd ~/homelab-secrets/stacks
mkdir NEW_SERVICE
cd NEW_SERVICE

# Create .env file
cat > .env << 'EOF'
VARIABLE_NAME=actual_secret_value
EOF

# Push to secrets repo
git add .
git commit -m "feat: add NEW_SERVICE secrets"
git push
```

#### 7. Deploy via Portainer

1. Navigate to **Stacks → Add Stack → Repository**
2. Fill in configuration (see table above)
3. Add environment variables from secrets repo
4. Enable automatic updates
5. Deploy the stack

#### 8. Verify Deployment

```bash
# Check container is running
ssh clockworkcity 'docker ps | grep NEW_SERVICE'

# Check logs
ssh clockworkcity 'docker logs NEW_SERVICE --tail 50'

# Test HTTPS access
curl -I https://service.rabalski.eu

# Verify auto-sync is working
# In Portainer: Stacks → NEW_SERVICE → check last update time
```

---

## Server Migration Procedure

### Scenario: Moving to new hardware

#### Prerequisites

1. New server with Ubuntu 24.04 LTS
2. Docker and Docker Compose installed
3. Portainer CE installed
4. Caddy reverse proxy configured
5. `caddy_net` network created
6. SSH access configured

#### Migration Steps

**1. Clone Repositories**

```bash
# On new server
ssh new-server

# Clone infrastructure repo (public)
git clone https://github.com/JakuRab/homelab-infrastructure.git ~/infrastructure

# Clone secrets repo (private - requires authentication)
git clone https://github.com/JakuRab/homelab-secrets.git ~/homelab-secrets
```

**2. Backup Data from Old Server**

```bash
# On old server - backup all persistent volumes
for service in adguardhome homeassistant vaultwarden speedtest-tracker; do
  docker run --rm \
    -v ${service}_data:/data \
    -v ~/backups:/backup \
    alpine tar czf /backup/${service}-$(date +%Y%m%d).tar.gz -C /data .
done

# Copy backups to new server
rsync -avz ~/backups/ new-server:~/backups/
```

**3. Restore Data on New Server**

```bash
# On new server - restore volumes before deploying stacks
for service in adguardhome homeassistant vaultwarden speedtest-tracker; do
  docker volume create ${service}_data
  docker run --rm \
    -v ${service}_data:/data \
    -v ~/backups:/backup \
    alpine tar xzf /backup/${service}-DATE.tar.gz -C /data
done
```

**4. Deploy Services via Portainer**

For each service in `~/infrastructure/stacks/`:
1. Add stack via Portainer Git integration
2. Copy env vars from `~/homelab-secrets/stacks/SERVICE/.env`
3. Enable auto-sync
4. Deploy

**5. Update DNS**

Point domain records to new server IP:
```
*.rabalski.eu → NEW_SERVER_IP
```

**6. Verify All Services**

```bash
# Quick health check script
#!/bin/bash
SERVICES=(
  "https://sink.rabalski.eu"      # AdGuard
  "https://dom.rabalski.eu"       # Home Assistant
  "https://21376942.rabalski.eu"  # Vaultwarden
  "https://n8n.rabalski.eu"       # n8n
  # ... add all services
)

for service in "${SERVICES[@]}"; do
  echo -n "Checking $service... "
  if curl -s -o /dev/null -w "%{http_code}" "$service" | grep -q "200\|302"; then
    echo "✅ OK"
  else
    echo "❌ FAILED"
  fi
done
```

**7. Decommission Old Server**

Only after confirming everything works on new server!

---

## Common Operations

### Updating a Service Configuration

```bash
# 1. Edit compose file locally
cd /path/to/homelab-infrastructure
vim stacks/SERVICE_NAME/docker-compose.yml

# 2. Test locally (optional)
docker compose -f stacks/SERVICE_NAME/docker-compose.yml config

# 3. Commit and push
git add stacks/SERVICE_NAME/
git commit -m "fix: update SERVICE_NAME configuration"
git push

# 4. Wait 5 minutes OR manually trigger in Portainer
# Portainer → Stacks → SERVICE_NAME → Pull and redeploy
```

### Updating Service Secrets

```bash
# 1. Update secrets on server
ssh clockworkcity
cd ~/homelab-secrets/stacks/SERVICE_NAME
vim .env

# 2. Commit to secrets repo
git add .env
git commit -m "feat: update SERVICE_NAME credentials"
git push

# 3. Update in Portainer UI
# Portainer → Stacks → SERVICE_NAME → Editor → Environment variables
# Update the changed values

# 4. Redeploy stack
# Portainer → Stacks → SERVICE_NAME → Update the stack
```

### Viewing Logs

```bash
# Via SSH
ssh clockworkcity 'docker logs SERVICE_NAME --tail 100 --follow'

# Via Portainer
# Containers → SERVICE_NAME → Logs → Auto-refresh
```

### Accessing Container Shell

```bash
# Via SSH
ssh clockworkcity 'docker exec -it SERVICE_NAME /bin/sh'

# Via Portainer
# Containers → SERVICE_NAME → Console → Connect
```

### Backing Up a Service

```bash
# For named volumes
ssh clockworkcity
docker run --rm \
  -v SERVICE_volume:/data \
  -v ~/backups:/backup \
  alpine tar czf /backup/SERVICE-$(date +%Y%m%d).tar.gz -C /data .

# For bind mounts
ssh clockworkcity
tar czf ~/backups/SERVICE-$(date +%Y%m%d).tar.gz /path/to/data/

# Download backup
scp clockworkcity:~/backups/SERVICE-DATE.tar.gz ./
```

### Restoring a Service

```bash
# For named volumes
ssh clockworkcity
docker volume create SERVICE_volume
docker run --rm \
  -v SERVICE_volume:/data \
  -v ~/backups:/backup \
  alpine tar xzf /backup/SERVICE-DATE.tar.gz -C /data

# For bind mounts
ssh clockworkcity
sudo tar xzf ~/backups/SERVICE-DATE.tar.gz -C /path/to/data/
```

---

## Troubleshooting

### Stack Won't Deploy

**Symptom:** Portainer shows error when deploying

**Common causes:**
1. **Syntax error in compose file**
   - Check: `docker compose -f stacks/SERVICE/docker-compose.yml config`
   - Look for: YAML indentation, missing colons, wrong quotes

2. **Missing external network**
   - Check: `ssh clockworkcity 'docker network ls | grep caddy_net'`
   - Fix: `ssh clockworkcity 'docker network create caddy_net'`

3. **Missing environment variables**
   - Check compose file for `${VARIABLES}`
   - Ensure all required vars are set in Portainer UI

4. **Port conflicts**
   - Check: `ssh clockworkcity 'docker ps' | grep PORT`
   - Fix: Change port in compose file or stop conflicting container

### Auto-Sync Not Working

**Symptom:** Changes pushed to Git don't deploy automatically

**Diagnosis:**
1. Check last update time in Portainer
2. Look for errors in Portainer logs
3. Verify repository URL is correct
4. Check GitHub is accessible from server

**Common fixes:**
- **Wrong branch:** Ensure Reference is `refs/heads/main`
- **Polling disabled:** Re-enable automatic updates
- **GitHub outage:** Wait and retry
- **Network issue:** Check server can reach GitHub

### Container Crash Loops

**Symptom:** Container constantly restarting

**Diagnosis:**
```bash
# Check logs for errors
ssh clockworkcity 'docker logs SERVICE_NAME --tail 100'

# Check container inspect
ssh clockworkcity 'docker inspect SERVICE_NAME'
```

**Common causes:**
1. **Missing environment variables** → Add to Portainer
2. **Invalid configuration** → Check mounted config files
3. **Permission issues** → Check volume ownership
4. **Port already in use** → Change exposed ports
5. **Health check failing** → Disable or adjust healthcheck

### Service Not Accessible via HTTPS

**Symptom:** Can't reach https://service.rabalski.eu

**Diagnosis checklist:**
1. ✅ Container running? `docker ps | grep SERVICE`
2. ✅ On caddy_net? `docker inspect SERVICE | grep caddy_net`
3. ✅ Caddy config correct? Check Caddyfile has entry
4. ✅ DNS resolving? `dig service.rabalski.eu`
5. ✅ Port exposed? Check compose file ports section (usually not needed with reverse proxy)

**Common fixes:**
- Add service to `caddy_net` in compose file
- Add reverse proxy entry to Caddyfile
- Restart Caddy: `ssh clockworkcity 'docker restart caddy'`

### Volume Data Not Persisting

**Symptom:** Data lost after container restart

**Diagnosis:**
```bash
# Check what volumes are mounted
ssh clockworkcity 'docker inspect SERVICE_NAME | grep -A 10 Mounts'

# Check if volume exists
ssh clockworkcity 'docker volume ls | grep SERVICE'
```

**Common causes:**
1. **No volume defined** → Add volume section to compose
2. **Wrong stack name** → Named volumes use format `stackname_volumename`
3. **Bind mount path doesn't exist** → Create directory first
4. **Volume not mounted** → Check volumes: section in service

### Portainer Shows "Limited Control"

**Symptom:** Stack deployed but Portainer says "Limited control"

**Cause:** Stack was deployed outside Portainer (e.g., via `docker compose up`)

**Fix:** Redeploy via Portainer Git integration
1. Stop and remove old stack: `docker compose down`
2. Deploy via Portainer → Add Stack → Repository
3. Portainer now has full control

---

## Best Practices

### Version Control

✅ **DO:**
- Commit after every working change
- Use descriptive commit messages: `feat:`, `fix:`, `docs:`
- Test changes locally before pushing
- Keep commit history clean

❌ **DON'T:**
- Commit secrets to main repository
- Push broken configurations
- Make changes directly on server
- Skip documentation updates

### Security

✅ **DO:**
- Keep secrets in private repository
- Use `.env.template` for documentation
- Rotate credentials regularly
- Use strong random passwords
- Review Portainer access logs

❌ **DON'T:**
- Hardcode secrets in compose files
- Share secrets repository publicly
- Use default passwords
- Disable TLS/HTTPS
- Skip security updates

### Container Configuration

✅ **DO:**
- Always use `restart: unless-stopped`
- Add health checks where applicable
- Use specific image tags (not `latest`)
- Add Glance labels for discovery
- Connect services to `caddy_net`
- Use named volumes for data
- Document environment variables

❌ **DON'T:**
- Use `restart: always` (prevents manual stops)
- Run containers as root unnecessarily
- Expose unnecessary ports
- Use anonymous volumes
- Forget to add labels
- Skip documentation

### Resource Management

✅ **DO:**
- Set resource limits for heavy services
- Use `shm_size` for browsers (Selenium, browserless)
- Monitor disk space usage
- Clean old Docker images: `docker image prune`
- Clean unused volumes: `docker volume prune`

❌ **DON'T:**
- Let images accumulate unchecked
- Ignore disk space warnings
- Run too many services on underpowered hardware

### Monitoring

✅ **DO:**
- Check Glance dashboard regularly
- Monitor Prometheus/Grafana alerts
- Review container logs periodically
- Test backups regularly
- Document incidents and solutions

❌ **DON'T:**
- Ignore warnings
- Skip log rotation
- Assume backups work without testing

### Documentation

✅ **DO:**
- Update README.md when adding services
- Document environment variables in .env.template
- Note special configurations in service README
- Keep MIGRATION_QUICK_REF.md current
- Document troubleshooting steps

❌ **DON'T:**
- Leave configurations undocumented
- Skip creating .env.template files
- Forget to update guides after changes

---

## Quick Reference Commands

### Git Operations
```bash
# Push changes
git add . && git commit -m "description" && git push

# Check status
git status

# View recent commits
git log --oneline -10

# Undo last commit (keep changes)
git reset --soft HEAD~1
```

### Docker Operations
```bash
# List running containers
docker ps

# View logs
docker logs SERVICE_NAME --tail 100 -f

# Restart service
docker restart SERVICE_NAME

# Execute command in container
docker exec SERVICE_NAME command

# View container resource usage
docker stats

# Clean system
docker system prune -a --volumes  # WARNING: Removes unused data!
```

### SSH Operations
```bash
# Connect to server
ssh clockworkcity

# Copy file to server
scp file.txt clockworkcity:/path/

# Copy file from server
scp clockworkcity:/path/file.txt ./

# Execute remote command
ssh clockworkcity 'command'
```

### Portainer Operations
- Access: https://portainer.rabalski.eu
- Stacks: Add, update, remove via GUI
- Logs: Real-time via web interface
- Console: Web-based terminal access

---

## Emergency Procedures

### Complete System Down

If entire server fails:

1. **Restore from backups:**
   - Follow [Server Migration Procedure](#server-migration-procedure)
   - Deploy on new/repaired hardware
   - Estimated time: 1-2 hours

2. **Priority order:**
   1. Caddy (reverse proxy)
   2. Portainer (management)
   3. AdGuard (DNS)
   4. Vaultwarden (passwords)
   5. Home Assistant (smart home)
   6. Everything else

### Single Service Failure

1. **Check logs:** `docker logs SERVICE_NAME`
2. **Try restart:** `docker restart SERVICE_NAME`
3. **Check recent Git changes:** Was config updated?
4. **Rollback if needed:** Revert Git commit, wait for auto-sync
5. **Restore from backup:** If data corrupted

### Lost Access to Portainer

1. **Reset admin password:**
   ```bash
   ssh clockworkcity
   docker stop portainer
   docker run --rm -v portainer_data:/data alpine sh -c "rm /data/portainer.db"
   docker start portainer
   # Access Portainer, will prompt for new admin user
   ```

2. **Redeploy stacks manually** if needed:
   ```bash
   cd ~/infrastructure/stacks/SERVICE_NAME
   docker compose up -d
   ```

### Secrets Repository Lost

If `homelab-secrets` repo is lost:

1. **Extract from Portainer:**
   - Each stack stores env vars
   - Export via Portainer UI

2. **Reconstruct from server:**
   ```bash
   ssh clockworkcity
   docker inspect SERVICE_NAME | grep -A 20 "Env"
   ```

3. **Reset critical passwords:**
   - Vaultwarden (if accessible)
   - AdGuard admin
   - Any others you remember

---

## Appendix: Service Inventory

### Migrated Services (13)

| Service | URL | Purpose | Critical |
|---------|-----|---------|----------|
| AdGuard Home | sink.rabalski.eu | DNS + Ad blocking | Yes |
| Home Assistant | dom.rabalski.eu | Smart home | Yes |
| Vaultwarden | 21376942.rabalski.eu | Password manager | Yes |
| Monitoring Stack | prometheus/grafana.rabalski.eu | Metrics | No |
| Glance | deck.rabalski.eu | Dashboard | No |
| n8n | n8n.rabalski.eu | Workflow automation | No |
| SearXNG | search.rabalski.eu | Search engine | No |
| Changedetection | watch.rabalski.eu | Website monitoring | No |
| Speedtest Tracker | speedtest.rabalski.eu | Speed tests | No |
| Dumbpad | pad.rabalski.eu | Notepad | No |
| n.eko | kicia.rabalski.eu | Browser sharing | No |
| Marreta | ram.rabalski.eu | Paywall bypass | No |
| Browser Services | Internal | Selenium + browserless | Support |

### Infrastructure (Manual - 4)

| Service | Purpose | Deployment |
|---------|---------|------------|
| Caddy | Reverse proxy | Manual |
| Portainer | Management UI | Manual |
| Nextcloud AIO | File sync | AIO master |
| Tailscale | VPN | systemd |

---

**END OF GUIDE**

For questions or updates, refer to:
- Main repo: https://github.com/JakuRab/homelab-infrastructure
- Migration history: `workspace/gitops/conversations/gitops-stack-migration.md`
- Quick reference: `MIGRATION_QUICK_REF.md`
