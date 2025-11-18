# Vaultwarden - Password Manager

Self-hosted Bitwarden-compatible password manager.

## ⚠️ CRITICAL SERVICE

**This service contains ALL your passwords. Handle with extreme care!**

- Always backup before any changes
- Test restore procedure before production migration
- Have emergency password access ready

## Service Information

- **Image:** `vaultwarden/server:latest`
- **Domain:** `21376942.rabalski.eu`
- **Data:** `/opt/vaultwarden/data/`
- **Network:** `caddy_net`

## Deployment

### Prerequisites

```bash
# Create data directory
sudo mkdir -p /opt/vaultwarden/data
```

### Via Portainer

1. **Stacks → Add Stack → Repository**
2. **Repository URL:** `https://github.com/JakuRab/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/vaultwarden/docker-compose.yml`
5. **Environment variables:** Add from `.env.template`
6. **Deploy**

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SIGNUPS_ALLOWED` | Allow new registrations | `false` |
| `WEBSOCKET_ENABLED` | Enable WebSocket notifications | `true` |
| `DOMAIN` | Public URL | `https://21376942.rabalski.eu` |
| `SMTP_*` | Email settings for notifications | (optional) |
| `ADMIN_TOKEN` | Token for /admin panel | (optional) |

### Admin Panel

Access `/admin` for administrative functions.

**Note:** The Caddyfile has basic auth protecting `/admin`:
```caddy
@admin path /admin*
basic_auth @admin {
    MoonAndStar $2a$14$...hashed_password...
}
```

## Backup Procedures

### Method 1: Full Directory Backup (Recommended)

```bash
# Stop Vaultwarden for consistent backup
docker stop vaultwarden

# Backup entire data directory
sudo tar -czf vaultwarden-$(date +%Y%m%d).tar.gz -C /opt/vaultwarden/data .

# Restart
docker start vaultwarden
```

### Method 2: Bitwarden CLI Export

```bash
# Install Bitwarden CLI
npm install -g @bitwarden/cli

# Login to your vault
bw login --server https://21376942.rabalski.eu

# Export (encrypted JSON - RECOMMENDED)
bw export --format encrypted_json --password STRONG_PASSWORD > vault-export.json

# Store encrypted backup securely (not in Git!)
```

### Method 3: Database Only

```bash
# The database file contains all vault data
cp /opt/vaultwarden/data/db.sqlite3 ~/backups/vaultwarden-db-$(date +%Y%m%d).sqlite3
```

### What's in the data directory

- `db.sqlite3` - Main database (users, vault items)
- `rsa_key.*` - RSA keys for encryption
- `attachments/` - File attachments
- `sends/` - Bitwarden Send files
- `icon_cache/` - Favicon cache

## Restore Procedures

### Full Restore

```bash
docker stop vaultwarden
sudo rm -rf /opt/vaultwarden/data/*
sudo tar -xzf vaultwarden-YYYYMMDD.tar.gz -C /opt/vaultwarden/data/
docker start vaultwarden
```

### Test Restore (Before Migration!)

```bash
# Create test directory
mkdir -p /tmp/vaultwarden-test

# Extract backup
tar -xzf vaultwarden-YYYYMMDD.tar.gz -C /tmp/vaultwarden-test/

# Run test instance on different port
docker run -d --name vaultwarden-test \
  -v /tmp/vaultwarden-test:/data \
  -p 8080:80 \
  vaultwarden/server:latest

# Test at http://localhost:8080
# Login and verify your data is intact

# Cleanup test
docker stop vaultwarden-test
docker rm vaultwarden-test
rm -rf /tmp/vaultwarden-test
```

## Migration Safety Checklist

Before migrating to Portainer Git deployment:

- [ ] Full backup created
- [ ] Backup verified (test restore)
- [ ] Export via Bitwarden CLI (encrypted)
- [ ] Alternative password access ready (printed, hardware key, etc.)
- [ ] Rollback procedure documented
- [ ] DNS/Caddy config tested separately

## Troubleshooting

### Can't login

```bash
# Check container is running
docker ps | grep vaultwarden

# Check logs
docker logs vaultwarden

# Verify database exists
ls -la /opt/vaultwarden/data/db.sqlite3
```

### WebSocket notifications not working

1. Ensure `WEBSOCKET_ENABLED=true`
2. Check Caddy proxies WebSocket correctly
3. Verify browser console for WebSocket errors

### Admin panel 403 Forbidden

- Check Caddy basic_auth credentials
- Verify ADMIN_TOKEN is set (if required)

## Security Notes

- Keep `SIGNUPS_ALLOWED=false` after initial setup
- Use strong admin panel password
- Regular backups (automated)
- Monitor for failed login attempts
- Consider IP restrictions via Caddy

## Resources

- **Official Wiki:** https://github.com/dani-garcia/vaultwarden/wiki
- **Bitwarden Clients:** https://bitwarden.com/download/
