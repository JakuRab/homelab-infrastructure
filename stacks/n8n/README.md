# n8n - Workflow Automation

Fair-code licensed workflow automation tool for technical people.

## Service Information

- **Image:** `n8nio/n8n:latest`
- **Domain:** `n8n.rabalski.eu` (not yet in Caddyfile)
- **Data:** `/opt/n8n/data` → `/home/node/.n8n`
- **Port:** 5678 (internal)
- **Network:** `caddy_net`

## Deployment

### Prerequisites

1. **Create data directory on server:**
   ```bash
   sudo mkdir -p /opt/n8n/data
   sudo chown 1000:1000 /opt/n8n/data
   ```

2. **Secrets configured:**
   - Environment variables from `.env.template`
   - Or use environment variables in Portainer UI

### Via Portainer (Recommended)

1. **Stacks → Add Stack → Repository**
2. **Repository:** `https://github.com/YOUR_USERNAME/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/n8n/docker-compose.yml`
5. **Environment variables:**
   - Copy from `~/homelab-secrets/stacks/n8n/.env`
   - Or use defaults from `.env.template`
6. **Deploy**

### Via CLI (Legacy)

```bash
# On server
cd ~/homelab/stacks/n8n
ln -s ~/homelab-secrets/stacks/n8n/.env .env
docker compose up -d
```

## Configuration

### Environment Variables

See `.env.template` for all options.

**Required:**
- `N8N_HOST` - Domain name (e.g., `n8n.rabalski.eu`)
- `N8N_PROTOCOL` - `https` (behind Caddy)
- `GENERIC_TIMEZONE` - Your timezone

**Optional:**
- `N8N_ENCRYPTION_KEY` - For encrypting credentials (auto-generated if not set)
- `DB_SQLITE_POOL_SIZE` - SQLite connection pool (default: 1)
- `N8N_RUNNERS_ENABLED` - Enable workflow runners (default: true)

### Reverse Proxy (Caddy)

**Add to `stacks/caddy/Caddyfile`:**

```caddy
n8n.rabalski.eu {
    import gate
    reverse_proxy n8n:5678
}
```

Then reload Caddy:
```bash
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

### DNS Configuration

Add rewrite in AdGuard Home:
- Domain: `n8n.rabalski.eu`
- IP: `192.168.1.10`

## First-Time Setup

1. **Access n8n:** `https://n8n.rabalski.eu`
2. **Create owner account** (first user becomes admin)
3. **Configure:**
   - Email settings (optional)
   - Workflow settings
   - Credentials

## Data Management

### Database Location

n8n uses SQLite by default:
```
/opt/n8n/data/database.sqlite
```

### Reset n8n (Fresh Start)

```bash
# Stop container
docker stop n8n

# Remove database (keeps other files like encryption key)
sudo rm /opt/n8n/data/database.sqlite

# Or complete wipe
sudo rm -rf /opt/n8n/data/*

# Restart
docker start n8n
```

### Backup

```bash
# Stop n8n for consistent backup
docker stop n8n

# Backup entire data directory
sudo tar -czf /backups/n8n-$(date +%Y%m%d).tar.gz -C /opt/n8n/data .

# Restart
docker start n8n
```

### Restore

```bash
docker stop n8n
sudo rm -rf /opt/n8n/data/*
sudo tar -xzf /backups/n8n-YYYYMMDD.tar.gz -C /opt/n8n/data
sudo chown -R 1000:1000 /opt/n8n/data
docker start n8n
```

## Troubleshooting

### Can't access via domain

**Check:**
1. Container is running: `docker ps | grep n8n`
2. On caddy_net: `docker inspect n8n | grep caddy_net`
3. Caddy has vhost configured
4. DNS rewrite in AdGuard Home
5. Test: `curl -I https://n8n.rabalski.eu`

### Workflows not executing

**Check logs:**
```bash
docker logs n8n -f
```

**Common issues:**
- Webhook URL misconfigured
- Credentials not properly encrypted
- Insufficient permissions on data directory

### Permission errors

```bash
# Fix ownership
sudo chown -R 1000:1000 /opt/n8n/data

# Restart container
docker restart n8n
```

### Lost encryption key

If `N8N_ENCRYPTION_KEY` is lost:
- Existing credentials cannot be decrypted
- Must reset database or manually update all credentials
- **Prevention:** Back up `/opt/n8n/data/.n8n_encryption_key`

## Useful Commands

```bash
# View logs
docker logs n8n -f

# Restart service
docker restart n8n

# Execute commands in container
docker exec -it n8n sh

# Check environment
docker exec n8n env | grep N8N

# Database size
sudo du -sh /opt/n8n/data/database.sqlite
```

## Resources

- **Official Docs:** https://docs.n8n.io/
- **Community Forum:** https://community.n8n.io/
- **Workflow Library:** https://n8n.io/workflows/

## Notes

- n8n is fair-code licensed (Apache 2.0 with Commons Clause)
- Self-hosted version is free for personal use
- Enterprise features require license
