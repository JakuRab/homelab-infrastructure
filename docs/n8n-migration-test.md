# n8n Migration Test - GitOps Workflow

This document tracks the first test migration of a service (n8n) to the new GitOps workflow.

## Objectives

1. ✅ Verify Git repository structure works
2. ⏳ Test Portainer Git integration with public repo
3. ⏳ Validate secrets management workflow
4. ⏳ Confirm auto-sync functionality
5. ⏳ Document any issues for future migrations

## Pre-Migration Checklist

- [x] Git repository initialized
- [x] Stacks directory created and populated
- [x] `.env.template` created for n8n
- [x] Secrets moved to separate structure
- [x] Documentation written (README.md, deployment guides)
- [x] n8n stack README created
- [ ] Code committed to Git
- [ ] Pushed to GitHub repository
- [ ] Secrets repository pushed to separate private repo

## Migration Steps

### Phase 1: Prepare Local Repository

```bash
cd /home/kuba/aiTools

# Review what will be committed
git status

# Stage all files
git add .

# Create initial commit
git commit -m "Initial commit: GitOps homelab infrastructure

- Restructured configs → stacks/
- Created .env.template files for all services
- Moved secrets to separate directory structure
- Comprehensive documentation (deployment, disaster recovery, Portainer setup)
- README files for each stack
- Ready for Portainer Git integration

Services included:
- Caddy (reverse proxy with Cloudflare DNS plugin)
- n8n (workflow automation)
- Home Assistant
- Monitoring stack (Prometheus + Grafana + Blackbox)
- Portainer
- Tailscale hardening configs"

# Verify commit
git log --oneline
```

### Phase 2: Create GitHub Repositories

**Main Infrastructure:**
1. GitHub → New Repository
2. Name: `homelab-infrastructure`
3. Visibility: Public or Private (your choice)
4. NO README (we have one)
5. Create repository

**Secrets Repository:**
1. GitHub → New Repository
2. Name: `homelab-secrets`
3. Visibility: **PRIVATE** (mandatory!)
4. NO README
5. Create repository

### Phase 3: Push to GitHub

**Main repo:**
```bash
cd /home/kuba/aiTools
git remote add origin https://github.com/YOUR_USERNAME/homelab-infrastructure.git
git push -u origin main
```

**Secrets repo:**
```bash
cd /home/kuba/aiTools/.secrets-templates
git init
git branch -m main
git add .
git commit -m "Initial secrets for homelab infrastructure"
git remote add origin https://github.com/YOUR_USERNAME/homelab-secrets.git
git push -u origin main
```

### Phase 4: Server Preparation

**On clockworkcity:**

```bash
# Clone secrets repo
git clone https://github.com/YOUR_USERNAME/homelab-secrets.git ~/homelab-secrets

# Verify n8n secrets
cat ~/homelab-secrets/stacks/n8n/.env

# Check current n8n deployment
docker ps | grep n8n
docker compose -f /opt/n8n/docker-compose.yml config

# Stop current n8n (if exists)
# NOTE: This preserves data volume!
cd /opt/n8n
docker compose down
```

### Phase 5: Deploy via Portainer

**In Portainer UI:**

1. Navigate to **Stacks → Add Stack**
2. Select **Repository** method
3. Configure:
   - **Name:** `n8n`
   - **Repository URL:** `https://github.com/YOUR_USERNAME/homelab-infrastructure`
   - **Repository reference:** `refs/heads/main`
   - **Compose path:** `stacks/n8n/docker-compose.yml`
4. **Environment variables** (from `~/homelab-secrets/stacks/n8n/.env`):
   - `GENERIC_TIMEZONE=Europe/Warsaw`
   - `N8N_HOST=n8n.rabalski.eu`
   - `N8N_PROTOCOL=https`
   - `N8N_PORT=5678`
   - `N8N_EDITOR_BASE_URL=https://n8n.rabalski.eu`
   - `WEBHOOK_URL=https://n8n.rabalski.eu`
   - `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true`
   - `DB_SQLITE_POOL_SIZE=1`
   - `N8N_RUNNERS_ENABLED=true`
5. ☑ **Enable automatic updates** (optional, for polling)
6. Click **Deploy the stack**

### Phase 6: Configure Webhook

1. **In Portainer:** Copy webhook URL from stack details
2. **In GitHub:**
   - Repository → Settings → Webhooks → Add webhook
   - Payload URL: `[Portainer webhook URL]`
   - Content type: `application/json`
   - Events: Just the push event
   - Active: ☑
   - Add webhook

### Phase 7: Test Auto-Deploy

```bash
# Make a small change
cd /home/kuba/aiTools
echo "# Test webhook trigger" >> stacks/n8n/README.md

# Commit and push
git add stacks/n8n/README.md
git commit -m "test: verify webhook triggers auto-deploy"
git push

# Watch Portainer for automatic redeployment
```

### Phase 8: Add to Caddy (if needed)

**Edit Caddyfile locally:**
```bash
cd /home/kuba/aiTools
vim stacks/caddy/Caddyfile
```

**Add n8n vhost:**
```caddy
# ===========================
# n8n - Workflow Automation
# ===========================
n8n.rabalski.eu {
  import gate
  reverse_proxy n8n:5678
}
```

**Commit and sync:**
```bash
git add stacks/caddy/Caddyfile
git commit -m "feat: add n8n reverse proxy configuration"
git push

# On server: reload Caddy
ssh user@clockworkcity
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### Phase 9: Configure DNS

**In AdGuard Home:**
1. Filters → DNS rewrites
2. Add rewrite:
   - Domain: `n8n.rabalski.eu`
   - IP: `192.168.1.10`
3. Save

### Phase 10: Verify Everything

```bash
# On server
docker ps | grep n8n
docker logs n8n

# Check Portainer control
# Should show full control, not "Limited"

# Test from LAN
curl -I https://n8n.rabalski.eu

# Access via browser
# https://n8n.rabalski.eu
```

## Success Criteria

- [x] Repository structure finalized
- [ ] Code committed and pushed to GitHub
- [ ] Secrets in separate private repo
- [ ] n8n deployed via Portainer Git integration
- [ ] Portainer shows "full" control (not "Limited")
- [ ] Webhook triggers automatic redeployment on push
- [ ] Service accessible via `https://n8n.rabalski.eu`
- [ ] Data persisted from previous deployment
- [ ] Documentation accurate and complete

## Issues Encountered

*(Document any problems and solutions here)*

## Lessons Learned

*(Notes for improving the process for future migrations)*

## Next Steps

After successful n8n migration:

1. Migrate Home Assistant
2. Migrate monitoring stack (multi-container test)
3. Create migration runbook for remaining services
4. Consider GitHub Actions for validation
5. Set up Renovate for dependency updates

---

**Status:** Ready for execution
**Date:** 2025-11-18
**Tester:** Kuba
