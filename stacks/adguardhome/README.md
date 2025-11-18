# AdGuard Home - DNS & Ad Blocking

Self-hosted DNS server with ad blocking and privacy protection.

## Service Information

- **Image:** `adguard/adguardhome:latest`
- **Domain:** `sink.rabalski.eu`
- **DNS Port:** 53 (TCP/UDP)
- **Data:** `/opt/adguardhome/conf/`, `/opt/adguardhome/work/`
- **Network:** `caddy_net`

## Critical Role

**AdGuard Home provides split-horizon DNS for the entire homelab:**

- All `*.rabalski.eu` domains are rewritten to `192.168.1.10`
- This allows LAN clients to reach services directly via Caddy
- Without AdGuard, internal DNS resolution breaks

## Deployment

### Prerequisites

```bash
# Create directories on server
sudo mkdir -p /opt/adguardhome/{conf,work}
```

### Via Portainer

1. **Stacks → Add Stack → Repository**
2. **Repository URL:** `https://github.com/JakuRab/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/adguardhome/docker-compose.yml`
5. **Deploy**

### First-Time Setup

1. Access: `https://sink.rabalski.eu`
2. Complete setup wizard
3. Set admin password
4. Configure upstream DNS (Cloudflare, Quad9, etc.)
5. **Critical:** Add DNS rewrites for all services

## DNS Rewrites Configuration

Add these rewrites in AdGuard Home → Filters → DNS rewrites:

| Domain | Answer |
|--------|--------|
| `*.rabalski.eu` | `192.168.1.10` |

Or individual entries:
- `dom.rabalski.eu` → `192.168.1.10`
- `21376942.rabalski.eu` → `192.168.1.10`
- `search.rabalski.eu` → `192.168.1.10`
- `cloud.rabalski.eu` → `192.168.1.10`
- `portainer.rabalski.eu` → `192.168.1.10`
- `sink.rabalski.eu` → `192.168.1.10`
- ... (all other services)

## Backup

### Export Configuration

```bash
# Backup AdGuard Home config
sudo tar -czf adguardhome-backup-$(date +%Y%m%d).tar.gz \
  -C /opt/adguardhome conf/

# Most important file:
# /opt/adguardhome/conf/AdGuardHome.yaml
```

### Restore

```bash
docker stop adguardhome
sudo tar -xzf adguardhome-backup-YYYYMMDD.tar.gz -C /opt/adguardhome/
docker start adguardhome
```

## Troubleshooting

### DNS not resolving

```bash
# Check if AdGuard is listening
sudo ss -tulpn | grep :53

# Test resolution
nslookup dom.rabalski.eu 192.168.1.10

# Check container logs
docker logs adguardhome
```

### Port 53 already in use

```bash
# Find what's using port 53
sudo lsof -i :53

# On Ubuntu, systemd-resolved often uses port 53
# Disable it or change its port
sudo systemctl disable systemd-resolved
```

### Clients not using AdGuard

- Set router DHCP to use `192.168.1.10` as DNS
- Or configure manually on each client
- Verify: `nslookup google.com` should show `192.168.1.10` as server

## Resources

- **Official Docs:** https://adguard.com/en/adguard-home/overview.html
- **GitHub:** https://github.com/AdguardTeam/AdGuardHome
