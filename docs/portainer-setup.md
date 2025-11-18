# Portainer Setup & Configuration

Detailed guide for configuring Portainer for GitOps workflow with your homelab infrastructure.

## Table of Contents

1. [Restoring Full Stack Control](#restoring-full-stack-control)
2. [Git Integration Setup](#git-integration-setup)
3. [Webhook Configuration](#webhook-configuration)
4. [Stack Templates](#stack-templates)
5. [Best Practices](#best-practices)

---

## Restoring Full Stack Control

If Portainer shows "Limited" control for your existing stacks, here's how to fix it.

### Why "Limited" Control Happens

Portainer labels stacks it manages with special Docker labels:
- `com.docker.compose.project`
- `io.portainer.stack.name`
- `io.portainer.stack.id`

Stacks deployed via `docker compose up` lack these labels, so Portainer can only monitor them, not manage them.

### Solution: Migrate to Portainer Management

**For each "Limited" stack:**

#### Step 1: Document Current State

```bash
# On server
cd /path/to/stack
docker compose config > /tmp/stack-backup.yml

# Note any volumes
docker volume ls | grep stack-name

# Note any custom networks
docker network ls | grep stack-name
```

#### Step 2: Stop and Remove

```bash
# Gracefully stop
docker compose down

# Verify removed
docker ps -a | grep stack-name
```

**Important:** This does NOT delete volumes! Your data is safe unless you use `docker compose down -v`.

#### Step 3: Redeploy via Portainer

1. **Open Portainer UI**
2. **Stacks → Add Stack → Repository**
3. Configure Git source:
   - URL: `https://github.com/YOUR_USERNAME/homelab-infrastructure`
   - Reference: `refs/heads/main`
   - Path: `stacks/STACK_NAME/docker-compose.yml`
4. Add environment variables (from secrets repo)
5. **Deploy**

#### Step 4: Verify

```bash
# Check Portainer labels
docker inspect CONTAINER_NAME | grep -A 5 Labels

# Should see:
# "io.portainer.stack.name": "stack-name"
# "io.portainer.stack.id": "123"
```

Now Portainer has full control!

---

## Git Integration Setup

Configure Portainer to automatically deploy from your Git repositories.

### Option 1: Public Repository (Simple)

No authentication needed:

1. **Stacks → Add Stack → Repository**
2. **Repository URL:** `https://github.com/USERNAME/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/SERVICE/docker-compose.yml`
5. **Deploy**

### Option 2: Private Repository (Recommended)

Requires authentication.

#### Method A: GitHub Personal Access Token

1. **Create token on GitHub:**
   - Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click **Generate new token (classic)**
   - Scopes: Select `repo` (full control of private repositories)
   - Generate and **copy token immediately** (can't see it again!)

2. **Add credentials to Portainer:**
   - Portainer → Settings → Registries → Add registry
   - Registry type: **GitHub**
   - Name: `github-homelab`
   - Username: `YOUR_GITHUB_USERNAME`
   - Personal Access Token: *paste token*
   - Save

3. **Use in stack deployment:**
   - When creating stack from repository
   - Authentication: Select `github-homelab`

#### Method B: SSH Deploy Key (Advanced)

For fine-grained access control:

1. **Generate SSH key on server:**
   ```bash
   ssh-keygen -t ed25519 -C "portainer-deploy-key" -f ~/.ssh/portainer_deploy
   cat ~/.ssh/portainer_deploy.pub
   ```

2. **Add deploy key to GitHub:**
   - Repository → Settings → Deploy keys → Add deploy key
   - Title: `Portainer Deploy Key - clockworkcity`
   - Key: *paste public key*
   - Allow write access: ☐ (read-only is fine)
   - Add key

3. **Configure Portainer:**
   - Portainer → Settings → Custom Templates → Git credentials
   - Add SSH key: paste contents of `~/.ssh/portainer_deploy` (private key)

4. **Use SSH URL in stacks:**
   ```
   git@github.com:USERNAME/homelab-infrastructure.git
   ```

---

## Webhook Configuration

Enable automatic redeployment when you push to GitHub.

### Step 1: Create Portainer Webhook

1. **Open stack in Portainer**
2. **Find "Webhooks" section** (may be under "Stack details")
3. **Copy webhook URL** - looks like:
   ```
   https://portainer.rabalski.eu/api/stacks/webhooks/abc123def456
   ```

### Step 2: Add Webhook to GitHub

1. **Go to repository on GitHub**
2. **Settings → Webhooks → Add webhook**
3. **Configure:**
   - Payload URL: *paste Portainer webhook*
   - Content type: `application/json`
   - Secret: (leave empty or match Portainer if configured)
   - Which events: **Just the push event**
   - Active: ☑
4. **Add webhook**

### Step 3: Test Webhook

1. **Make a small change:**
   ```bash
   echo "# Webhook test" >> stacks/n8n/README.md
   git add stacks/n8n/README.md
   git commit -m "test: verify webhook triggers redeploy"
   git push
   ```

2. **Check GitHub webhook deliveries:**
   - Settings → Webhooks → Recent Deliveries
   - Should see green ✓ with 200 response

3. **Check Portainer:**
   - Stack should show recent activity
   - Logs show redeployment

### Webhook Security (Optional)

For added security, configure webhook secret:

1. **Generate secret:**
   ```bash
   openssl rand -hex 32
   ```

2. **In Portainer:**
   - Stack → Webhooks → Configure secret
   - Paste generated secret

3. **In GitHub webhook:**
   - Secret field: paste same secret

Now only requests with valid signature will trigger deployment.

---

## Stack Templates

Create reusable templates for common deployment patterns.

### Custom Template Example

Portainer → App Templates → Custom Templates → Add Custom Template

**Template for standard service:**

```yaml
version: "3.8"

services:
  {{ .ServiceName }}:
    image: {{ .Image }}
    container_name: {{ .ServiceName }}
    restart: unless-stopped
    volumes:
      - /opt/{{ .ServiceName }}/config:/config
    environment:
      - TZ=Europe/Warsaw
    networks:
      - caddy_net
    labels:
      - "glance.name={{ .DisplayName }}"
      - "glance.url=https://{{ .ServiceName }}.rabalski.eu"

networks:
  caddy_net:
    external: true
```

**Template variables:**
- `ServiceName`: Container/service name
- `Image`: Docker image
- `DisplayName`: Friendly name for Glance dashboard

### Pre-configured Stack Environments

Save common environment variable sets:

1. **Portainer → Environments → Add environment set**
2. **Name:** `homelab-common`
3. **Variables:**
   ```
   TZ=Europe/Warsaw
   PUID=1000
   PGID=1000
   ```
4. **Apply to stacks** when deploying

---

## Best Practices

### 1. Stack Naming Convention

Use consistent names across:
- Directory name: `stacks/SERVICE/`
- Compose project name: `name: SERVICE`
- Container name: `container_name: SERVICE`
- Portainer stack name: `SERVICE`

**Example for n8n:**
- Directory: `stacks/n8n/`
- Compose: `name: n8n`
- Container: `container_name: n8n`
- Portainer: Stack name `n8n`

### 2. Environment Variable Management

**Recommended approach:**

1. **Public config** → `.env.template` in main repo
2. **Secrets** → Secrets repo
3. **Deploy** → Paste into Portainer UI

**Pros:**
- Secrets never in main repo
- Easy to update via UI
- Clear audit trail in Portainer logs

**Alternative for many variables:**

Use env_file in compose:

```yaml
services:
  app:
    env_file:
      - /path/on/server/.env
```

Mount secrets from server filesystem.

### 3. Update Strategy

**Automatic updates:**
- ☑ Enable for non-critical services (n8n, monitoring)
- ☐ Disable for critical services (Caddy, Portainer itself)

**Manual trigger:**
- Review changes in Git first
- Then: Stack → **Pull and redeploy**
- Gives more control

### 4. Rollback Procedure

If deployment breaks:

**Option 1: Git revert**
```bash
# Find last good commit
git log --oneline

# Revert to it
git revert COMMIT_HASH

# Push
git push

# Portainer auto-redeploys old version
```

**Option 2: Portainer UI**
- Stack → **Stop**
- Edit docker-compose.yml inline
- Fix issue
- **Deploy**

**Option 3: Emergency manual deployment**
```bash
# On server
cd /opt/SERVICE
docker compose down
docker compose up -d
```

### 5. Monitoring Stack Health

**In Portainer:**
- Containers → Filter by stack
- Check all containers are "running" (green)
- Review logs for errors

**Via CLI:**
```bash
# Stack status
docker ps --filter "label=com.docker.compose.project=SERVICE"

# Stack logs
docker compose -p SERVICE logs -f

# Resource usage
docker stats $(docker ps --filter "label=com.docker.compose.project=SERVICE" -q)
```

### 6. Backup Before Major Changes

Before migrating critical stacks:

```bash
# Backup Portainer data
docker run --rm \
  -v portainer_data:/source \
  -v /tmp:/backup \
  alpine tar czf /backup/portainer-backup-$(date +%Y%m%d).tar.gz -C /source .

# Backup stack volumes
docker run --rm \
  -v SERVICE_data:/source \
  -v /backups:/backup \
  alpine tar czf /backup/SERVICE-data-$(date +%Y%m%d).tar.gz -C /source .
```

---

## Migration Checklist

Use this checklist when migrating a stack to Portainer Git management:

- [ ] Stack is in `stacks/SERVICE/` directory
- [ ] `.env.template` created with all required variables
- [ ] Actual secrets added to secrets repo
- [ ] `docker-compose.yml` uses `caddy_net` external network
- [ ] README.md exists with service documentation
- [ ] Current stack stopped: `docker compose down`
- [ ] Deployed via Portainer Git integration
- [ ] Environment variables added in Portainer UI
- [ ] Stack deployed successfully
- [ ] Service accessible via domain
- [ ] Webhook configured for auto-updates
- [ ] Tested: push change → auto-redeploy works
- [ ] Documentation updated in main README.md

---

## Common Issues

### Issue: Stack won't deploy from Git

**Check:**
1. Repository URL is correct
2. Branch reference is `refs/heads/main` (not just `main`)
3. Compose path is relative to repo root: `stacks/SERVICE/docker-compose.yml`
4. Authentication configured (for private repos)

**Debug:**
```bash
# Test Git access from Portainer container
docker exec -it portainer sh
apk add git
git clone https://github.com/USER/homelab-infrastructure /tmp/test
ls -la /tmp/test/stacks/
```

### Issue: Webhook not triggering

**Verify:**
1. Webhook URL is exact (no typos)
2. GitHub shows successful delivery (200 OK)
3. Portainer webhook is enabled for the stack
4. No firewall blocking GitHub's webhook IPs

**Test manually:**
```bash
curl -X POST "https://portainer.rabalski.eu/api/stacks/webhooks/WEBHOOK_ID"
```

### Issue: Environment variables not applied

**Check:**
1. Variables are set in Portainer UI
2. Stack was redeployed after adding variables
3. Variable names match compose file

**Verify inside container:**
```bash
docker exec CONTAINER env | grep VARIABLE_NAME
```

---

## Next Steps

- [Deployment Guide](deployment.md) - Full deployment workflows
- [Disaster Recovery](disaster-recovery.md) - Rebuild procedures
- [Main README](../README.md) - Repository overview

---

**Related:** See official [Portainer documentation](https://docs.portainer.io/) for advanced features.
