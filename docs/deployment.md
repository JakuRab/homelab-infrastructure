# Deployment Guide

Complete guide for deploying homelab services using GitOps with Portainer.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [First-Time Setup](#first-time-setup)
3. [Deploying a Stack](#deploying-a-stack)
4. [Configuring Auto-Sync](#configuring-auto-sync)
5. [Managing Secrets](#managing-secrets)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Server (`clockworkcity`)

1. **Docker & Docker Compose**
   ```bash
   # Verify installation
   docker --version
   docker compose version
   ```

2. **External Docker network**
   ```bash
   # Create once (if not exists)
   docker network create caddy_net

   # Verify
   docker network ls | grep caddy_net
   ```

3. **Portainer CE**
   ```bash
   # Should be accessible at https://portainer.rabalski.eu
   docker ps | grep portainer
   ```

### On Local Machine

1. **Git configured with GitHub access**
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your@email.com"
   ```

2. **SSH access to server**
   ```bash
   ssh user@clockworkcity
   ```

---

## First-Time Setup

### 1. Create GitHub Repositories

#### Main Infrastructure Repository

1. Go to https://github.com/new
2. Create repository:
   - Name: `homelab-infrastructure`
   - Visibility: **Public** or Private (your choice)
   - Don't initialize (we have content)

#### Secrets Repository

1. Go to https://github.com/new
2. Create repository:
   - Name: `homelab-secrets`
   - Visibility: **PRIVATE** (mandatory!)
   - Don't initialize

### 2. Push Code to GitHub

#### Push Main Repository

```bash
cd /home/kuba/aiTools

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/homelab-infrastructure.git

# Initial commit
git add .
git commit -m "Initial commit: homelab infrastructure

- Structured stacks for all services
- Environment templates for secrets
- Comprehensive documentation
- Ready for Portainer Git integration"

# Push
git push -u origin main
```

#### Push Secrets Repository

```bash
cd /home/kuba/aiTools/.secrets-templates

# Initialize git
git init
git branch -m main

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/homelab-secrets.git

# Commit (secrets ARE included here!)
git add .
git commit -m "Initial secrets for homelab services

PRIVATE REPOSITORY - Contains production credentials"

# Push
git push -u origin main
```

### 3. Deploy Secrets to Server

```bash
# On server
ssh user@clockworkcity

# Clone secrets repo
git clone https://github.com/YOUR_USERNAME/homelab-secrets.git ~/homelab-secrets

# Verify secrets are present
ls -la ~/homelab-secrets/stacks/*/
```

---

## Deploying a Stack

### Method 1: Portainer Git Integration (Recommended)

This method allows Portainer to automatically pull and deploy from your Git repository.

#### Step-by-Step

1. **Open Portainer**
   - Navigate to https://portainer.rabalski.eu
   - Log in with your credentials

2. **Create New Stack**
   - Go to: **Stacks → Add Stack**
   - Choose: **Repository**

3. **Configure Git Source**

   **Repository URL:**
   ```
   https://github.com/YOUR_USERNAME/homelab-infrastructure
   ```

   **Repository reference:**
   ```
   refs/heads/main
   ```

   **Compose path:**
   ```
   stacks/n8n/docker-compose.yml
   ```
   *(Replace `n8n` with your service name)*

4. **Add Environment Variables**

   Click **+ Add environment variable** for each secret:

   **For n8n example:**
   - `GENERIC_TIMEZONE` = `Europe/Warsaw`
   - `N8N_HOST` = `n8n.rabalski.eu`
   - `N8N_PROTOCOL` = `https`
   - etc.

   *Tip: Copy from `~/homelab-secrets/stacks/n8n/.env` on server*

5. **Enable Auto-Update (Optional)**

   - Check: ☑ **Automatic updates**
   - This enables periodic Git polling
   - For webhook-based updates, see [Configuring Auto-Sync](#configuring-auto-sync)

6. **Deploy**
   - Click **Deploy the stack**
   - Wait for containers to start
   - Check logs for errors

#### Verify Deployment

```bash
# On server
docker ps | grep n8n
docker logs n8n

# Test service
curl -I https://n8n.rabalski.eu
```

### Method 2: Server-Side Deployment (Legacy)

For services that require custom builds or aren't ready for Portainer Git integration.

```bash
# On server
cd ~/homelab
git clone https://github.com/YOUR_USERNAME/homelab-infrastructure.git .

# Link secrets
ln -s ~/homelab-secrets/stacks/SERVICE_NAME/.env ~/homelab/stacks/SERVICE_NAME/.env

# Deploy
cd stacks/SERVICE_NAME
docker compose up -d

# Verify
docker ps | grep SERVICE_NAME
```

---

## Configuring Auto-Sync

Enable push-triggered deployments so Portainer redeploys immediately when you push to GitHub.

### Option 1: Portainer Webhook (Simple)

1. **In Portainer:**
   - Go to stack details
   - Find **Webhooks** section
   - Copy the webhook URL

2. **In GitHub:**
   - Go to repository → Settings → Webhooks → Add webhook
   - Payload URL: *paste Portainer webhook*
   - Content type: `application/json`
   - Trigger: **Just the push event**
   - Active: ☑
   - Add webhook

3. **Test:**
   ```bash
   # Make a small change
   echo "# Test change" >> stacks/n8n/README.md
   git add stacks/n8n/README.md
   git commit -m "test: trigger webhook"
   git push

   # Watch Portainer redeploy automatically
   ```

### Option 2: GitHub Actions (Advanced)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Portainer

on:
  push:
    branches: [ main ]
    paths:
      - 'stacks/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Portainer Webhook
        run: |
          curl -X POST ${{ secrets.PORTAINER_WEBHOOK_URL }}
```

Add `PORTAINER_WEBHOOK_URL` to repository secrets.

---

## Managing Secrets

### Updating Secrets

1. **Edit secrets locally:**
   ```bash
   cd /home/kuba/aiTools/.secrets-templates
   vim stacks/SERVICE_NAME/.env
   ```

2. **Commit and push:**
   ```bash
   git add stacks/SERVICE_NAME/.env
   git commit -m "Update SERVICE_NAME secrets"
   git push
   ```

3. **Update on server:**
   ```bash
   ssh user@clockworkcity
   cd ~/homelab-secrets
   git pull
   ```

4. **Redeploy stack:**
   - In Portainer: Stack → **Redeploy**
   - Or via CLI: `docker compose up -d --force-recreate`

### Using Docker Secrets (Recommended for Production)

More secure than environment variables:

```bash
# On server
# Create secret from file
docker secret create n8n_encryption_key ~/homelab-secrets/stacks/n8n/encryption.key

# Reference in docker-compose.yml
services:
  n8n:
    secrets:
      - n8n_encryption_key
    environment:
      - N8N_ENCRYPTION_KEY_FILE=/run/secrets/n8n_encryption_key

secrets:
  n8n_encryption_key:
    external: true
```

---

## Troubleshooting

### Stack shows "Limited" control in Portainer

**Cause:** Stack was deployed outside of Portainer (via `docker compose up`)

**Solution:**
1. Stop the stack: `docker compose down`
2. Redeploy via Portainer Git integration
3. Portainer will now have full control

### Portainer can't access GitHub repository

**For private repos:**

1. **Create GitHub Personal Access Token:**
   - GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate new token with `repo` scope
   - Copy token

2. **In Portainer:**
   - Settings → Registries → Add registry
   - Choose: GitHub
   - Add credentials with token

### Auto-update not working

**Check:**
1. Webhook URL is correct in GitHub
2. Portainer can reach the internet (no firewall blocking)
3. Recent deliveries in GitHub webhook settings show success (200 OK)

**Test webhook manually:**
```bash
curl -X POST "https://portainer.rabalski.eu/api/webhooks/WEBHOOK_ID"
```

### Environment variables not loading

**Verify:**
1. Variables are set in Portainer UI (Stack → Editor → Environment variables)
2. No typos in variable names
3. Check container logs: `docker logs CONTAINER_NAME`

**Alternative:** Use `.env` file on server:

```yaml
# In docker-compose.yml
services:
  app:
    env_file:
      - /path/to/.env
```

### Network errors: "network caddy_net not found"

**Fix:**
```bash
# On server
docker network create caddy_net

# Verify
docker network ls | grep caddy_net
```

### Service not accessible via domain

**Checklist:**
1. Container is running: `docker ps | grep SERVICE`
2. Container is on `caddy_net`: `docker inspect CONTAINER | grep caddy_net`
3. Caddy has vhost for domain (check `stacks/caddy/Caddyfile`)
4. AdGuard Home has DNS rewrite: `SERVICE.rabalski.eu → 192.168.1.10`
5. Test locally: `curl -I https://SERVICE.rabalski.eu` from LAN client

---

## Next Steps

- [Portainer Setup Guide](portainer-setup.md) - Advanced Portainer configuration
- [Disaster Recovery](disaster-recovery.md) - Complete rebuild procedures
- [Architecture Overview](../homelabbing/homelab.md) - Network topology and design

---

**Questions?** Open an issue in the GitHub repository.
