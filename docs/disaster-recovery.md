# Disaster Recovery Guide

Complete procedures for rebuilding your homelab infrastructure from scratch using Git repositories.

## Recovery Scenarios

1. [Complete Server Rebuild](#complete-server-rebuild) - Server hardware failure or fresh OS install
2. [Single Service Recovery](#single-service-recovery) - One service failed or needs reset
3. [Network Configuration Loss](#network-configuration-loss) - DNS, reverse proxy, or network issues
4. [Secrets Loss](#secrets-loss) - Environment variables or credentials lost

---

## Complete Server Rebuild

**Scenario:** Fresh Ubuntu installation or complete server replacement

**Time estimate:** 2-4 hours

**Prerequisites:**
- GitHub repositories accessible
- Backup of secrets repository
- Physical or remote access to server

### Step 1: Base System Setup (30 min)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl git vim htop

# Set static IP (if not using DHCP reservation)
# Edit netplan config: /etc/netplan/01-netcfg.yaml
sudo netplan apply

# Set hostname
sudo hostnamectl set-hostname clockworkcity
```

### Step 2: Install Docker (15 min)

```bash
# Install Docker from official repository
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (V2)
sudo apt install docker-compose-plugin

# Verify
docker --version
docker compose version
```

### Step 3: Network Setup (20 min)

```bash
# Create external Docker network
docker network create caddy_net

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate Tailscale
sudo tailscale up --accept-routes --accept-dns

# Apply Tailscale stability configs (from repo)
# (We'll do this after cloning the repo)
```

### Step 4: Clone Repositories (10 min)

```bash
# Create directory structure
mkdir -p ~/homelab
cd ~/homelab

# Clone infrastructure repo
git clone https://github.com/YOUR_USERNAME/homelab-infrastructure.git .

# Clone secrets repo
git clone https://github.com/YOUR_USERNAME/homelab-secrets.git ~/homelab-secrets

# Verify structure
ls -la stacks/
ls -la ~/homelab-secrets/stacks/
```

### Step 5: Deploy Tailscale Hardening (10 min)

```bash
# Apply systemd overrides and health checks
sudo mkdir -p /etc/systemd/system/tailscaled.service.d
sudo cp stacks/tailscale/tailscaled.service.d/override.conf /etc/systemd/system/tailscaled.service.d/

sudo install -m 0755 stacks/tailscale/tailscale-healthcheck.sh /usr/local/bin/
sudo install -m 0644 stacks/tailscale/tailscale-health.service /etc/systemd/system/
sudo install -m 0644 stacks/tailscale/tailscale-health.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable --now tailscale-health.timer
sudo systemctl status tailscale-health.timer
```

### Step 6: Deploy Portainer (15 min)

```bash
# Create data directory
sudo mkdir -p /opt/portainer/data

# Link secrets
ln -s ~/homelab-secrets/stacks/portainer/.env ~/homelab/stacks/portainer/.env 2>/dev/null || true

# Deploy
cd ~/homelab/stacks/portainer
docker compose up -d

# Wait for startup
sleep 10

# Verify
docker ps | grep portainer
curl -I http://localhost:9000
```

**Important:** Complete Portainer initial setup via web UI:
1. Navigate to `http://192.168.1.10:9000`
2. Create admin user
3. Select "Get Started" for local environment

### Step 7: Deploy Caddy with Cloudflare (20 min)

```bash
# Create directories
sudo mkdir -p /opt/caddy/{data,config}

# Link secrets
ln -s ~/homelab-secrets/stacks/caddy/.env ~/homelab/stacks/caddy/.env

# Build custom Caddy with Cloudflare DNS plugin
cd ~/homelab/stacks/caddy
mkdir -p .docker
DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache

# Deploy
docker compose up -d

# Wait for certificate acquisition
sleep 30

# Verify
docker logs caddy
docker exec caddy caddy list-modules | grep cloudflare

# Test HTTPS
curl -I https://portainer.rabalski.eu
```

### Step 8: Configure DNS (AdGuard Home) (15 min)

**If restoring existing AdGuard:**

```bash
# Restore AdGuard Home configuration backup
sudo mkdir -p /opt/adguardhome/conf
sudo tar -xzf /path/to/adguardhome-backup.tar.gz -C /opt/adguardhome/conf

# Deploy
cd ~/homelab/stacks/adguardhome
docker compose up -d
```

**If fresh install:**

1. Deploy AdGuard Home stack
2. Access `https://sink.rabalski.eu`
3. Complete setup wizard
4. Add DNS rewrites for all `*.rabalski.eu → 192.168.1.10`

### Step 9: Deploy Remaining Services (30-60 min)

**Option A: Via Portainer UI (Recommended)**

For each service:
1. Portainer → Stacks → Add Stack → Repository
2. URL: `https://github.com/YOUR_USERNAME/homelab-infrastructure`
3. Path: `stacks/SERVICE/docker-compose.yml`
4. Add environment variables from `~/homelab-secrets/stacks/SERVICE/.env`
5. Deploy

**Option B: Via CLI**

```bash
# For each service
cd ~/homelab/stacks/SERVICE
ln -s ~/homelab-secrets/stacks/SERVICE/.env .env
docker compose up -d
```

**Service deployment order:**
1. ✅ Portainer (done)
2. ✅ Caddy (done)
3. AdGuard Home / DNS
4. Monitoring (Prometheus + Grafana)
5. Home Assistant
6. Vaultwarden
7. Nextcloud AIO (special procedure)
8. n8n
9. Other services

### Step 10: Restore Data Volumes (varies)

For services with persistent data:

```bash
# Example: Restore Vaultwarden database
docker run --rm \
  -v vaultwarden_data:/target \
  -v /path/to/backup:/backup \
  alpine sh -c "cd /target && tar -xzf /backup/vaultwarden-data.tar.gz"

# Restart service
docker restart vaultwarden
```

### Step 11: Verify All Services (20 min)

```bash
# Check all containers running
docker ps

# Test each service
for service in dom 21376942 search cloud portainer sink kicia watch deck; do
  echo "Testing $service.rabalski.eu..."
  curl -I "https://$service.rabalski.eu"
done

# Check Portainer stack status
# (All should show "running")
```

### Step 12: Configure Router/Firewall

1. **Static DHCP reservation:**
   - MAC: `[server MAC]`
   - IP: `192.168.1.10`

2. **Port forwarding (if exposing services publicly):**
   - External 443 → `192.168.1.10:443` (Caddy HTTPS)
   - External 8443 → `192.168.1.10:8443` (Caddy alt port)

**Recovery Complete!** 🎉

---

## Single Service Recovery

**Scenario:** One service is broken or needs reset

### Reset Service to Clean State

```bash
# Stop and remove container
docker stop SERVICE
docker rm SERVICE

# OPTIONAL: Remove data (if you want fresh start)
docker volume rm SERVICE_data

# Redeploy
cd ~/homelab/stacks/SERVICE
docker compose up -d

# Or via Portainer: Stack → Redeploy
```

### Restore Service from Backup

```bash
# Stop service
docker stop SERVICE

# Restore data
docker run --rm \
  -v SERVICE_data:/target \
  -v /backups:/backup \
  alpine sh -c "rm -rf /target/* && tar -xzf /backup/SERVICE-latest.tar.gz -C /target"

# Start service
docker start SERVICE
```

---

## Network Configuration Loss

**Scenario:** Caddy config lost, DNS broken, or routing issues

### Restore Caddy Configuration

```bash
# Pull latest from Git
cd ~/homelab
git pull

# Reload Caddy
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# Or rebuild completely
cd ~/homelab/stacks/caddy
docker compose down
docker compose up -d
```

### Fix DNS Rewrites (AdGuard)

**Manual restore:**
1. Access AdGuard Home: `https://sink.rabalski.eu`
2. Filters → DNS rewrites
3. Add each: `SERVICE.rabalski.eu → 192.168.1.10`

**Or restore from backup:**
```bash
# Restore AdGuardHome.yaml
sudo cp /path/to/backup/AdGuardHome.yaml /opt/adguardhome/conf/
docker restart adguardhome
```

### Recreate Docker Network

```bash
# If caddy_net was deleted
docker network create caddy_net

# Reconnect all services
for service in $(docker ps --format '{{.Names}}'); do
  docker network connect caddy_net $service 2>/dev/null
done

# Restart Caddy
docker restart caddy
```

---

## Secrets Loss

**Scenario:** `.env` files deleted or secrets repo lost

### Restore from Secrets Repo

```bash
# Re-clone secrets repo
cd ~
rm -rf homelab-secrets
git clone https://github.com/YOUR_USERNAME/homelab-secrets.git

# Verify secrets present
cat ~/homelab-secrets/stacks/caddy/.env
```

### Manual Secret Recreation

If secrets repo is also lost, you'll need to regenerate:

**Cloudflare API Token:**
1. Cloudflare Dashboard → Profile → API Tokens
2. Create Token → Edit zone DNS template
3. Zone Resources: Include → Specific zone → `rabalski.eu`
4. Copy token to `~/homelab-secrets/stacks/caddy/.env`

**Grafana Password:**
```bash
# Generate secure password
openssl rand -base64 32

# Update in secrets repo
echo "GF_ADMIN_PASSWORD=NEW_PASSWORD" >> ~/homelab-secrets/stacks/net_monitor/.env
```

**n8n Encryption Key:**
```bash
# Check if recoverable from existing installation
docker exec n8n cat /home/node/.n8n/.n8n_encryption_key

# If lost, you cannot decrypt old credentials
# Generate new key for fresh start:
openssl rand -base64 32
```

---

## Data Backup Strategy

Prevent disasters with regular backups!

### Critical Data to Back Up

1. **Docker volumes:**
   - Portainer data
   - Vaultwarden database
   - Home Assistant config
   - n8n workflows & credentials
   - AdGuard Home config

2. **Configuration files:**
   - Git repositories (already backed up on GitHub)
   - Secrets repository (GitHub + encrypted offline backup)

3. **System configuration:**
   - `/etc/netplan/` (network config)
   - `/etc/systemd/system/` (systemd overrides)
   - Tailscale auth keys

### Automated Backup Script

Create `scripts/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup all named volumes
for volume in $(docker volume ls -q | grep -v '^[0-9a-f]\{64\}$'); do
  echo "Backing up volume: $volume"
  docker run --rm \
    -v "$volume:/source:ro" \
    -v "$BACKUP_DIR:/backup" \
    alpine tar czf "/backup/$volume.tar.gz" -C /source .
done

# Backup secrets repo
cd ~/homelab-secrets
git archive --format=tar.gz HEAD -o "$BACKUP_DIR/homelab-secrets.tar.gz"

echo "Backup complete: $BACKUP_DIR"
```

Run weekly via cron:
```bash
# Add to crontab
0 2 * * 0 /home/user/homelab/scripts/backup.sh
```

### Off-Site Backup

**Sync to remote location:**
```bash
# Using rsync
rsync -avz /backups/ user@remote:/backups/clockworkcity/

# Or using rclone to cloud storage
rclone sync /backups/ remote:homelab-backups/
```

---

## Recovery Testing

**Test your recovery procedures quarterly!**

### Test Checklist

- [ ] Verify Git repos are accessible
- [ ] Confirm secrets repo has all current .env files
- [ ] Test Docker installation script on clean VM
- [ ] Verify backups can be restored
- [ ] Document any issues found
- [ ] Update this guide with fixes

### Quick Test Procedure

```bash
# On test VM or container
curl -fsSL https://get.docker.com | sh
docker network create caddy_net
git clone https://github.com/YOUR_USERNAME/homelab-infrastructure.git
cd homelab-infrastructure/stacks/SERVICE
docker compose up -d
# Verify service works
```

---

## Emergency Contacts & Resources

**Key Information:**
- Cloudflare account: `your@email.com`
- Domain registrar: [Registrar Name]
- GitHub account: `YOUR_USERNAME`
- Tailscale account: `your@email.com`

**Important URLs:**
- Cloudflare Dashboard: https://dash.cloudflare.com
- Tailscale Admin: https://login.tailscale.com/admin
- GitHub Repos: https://github.com/YOUR_USERNAME

**Documentation:**
- This guide: `docs/disaster-recovery.md`
- Architecture: `homelabbing/homelab.md`
- Deployment: `docs/deployment.md`

---

**Remember:** The best disaster recovery is prevention through:
1. Regular automated backups
2. Version-controlled configuration (Git)
3. Documented procedures (this guide!)
4. Periodic recovery testing

Stay prepared! 🛡️
