# AdGuard Home - DNS & Ad Blocking

Self-hosted DNS server with ad blocking and privacy protection.

## Service Information

- **Image:** `adguard/adguardhome:latest`
- **Domain:** `sink.rabalski.eu`
- **DNS Port:** 53 (TCP/UDP)
- **Location:** Running on OPNsense (clockworkcity, 192.168.1.1)
- **Network:** `caddy_net`

## Critical Role

**AdGuard Home provides split-horizon DNS for the entire homelab:**

- All `*.rabalski.eu` domains are rewritten to `192.168.1.11` (narsis)
- This allows LAN clients to reach services directly via Caddy on narsis
- Without AdGuard, internal DNS resolution breaks

## Current Architecture

- **AdGuard Home:** Running on OPNsense (192.168.1.1)
- **Caddy (reverse proxy):** Running on narsis (192.168.1.11)
- **All services:** Running on narsis (192.168.1.11)

## DNS Rewrites Configuration

**Critical:** These rewrites enable split-horizon DNS for all homelab services.

Add in AdGuard Home → Filters → DNS rewrites:

### Complete Service List

| Service | Domain | IP |
|---------|--------|-----|
| Root redirect | `rabalski.eu` | `192.168.1.11` |
| Home Assistant | `dom.rabalski.eu` | `192.168.1.11` |
| Vaultwarden | `21376942.rabalski.eu` | `192.168.1.11` |
| SearXNG | `search.rabalski.eu` | `192.168.1.11` |
| Portainer | `portainer.rabalski.eu` | `192.168.1.11` |
| AdGuard | `sink.rabalski.eu` | `192.168.1.1` |
| n.eko | `kicia.rabalski.eu` | `192.168.1.11` |
| Changedetection | `watch.rabalski.eu` | `192.168.1.11` |
| Glance | `deck.rabalski.eu` | `192.168.1.11` |
| n8n | `n8n.rabalski.eu` | `192.168.1.11` |
| Marreta | `ram.rabalski.eu` | `192.168.1.11` |
| Dumbpad | `pad.rabalski.eu` | `192.168.1.11` |
| Speedtest | `speedtest.rabalski.eu` | `192.168.1.11` |
| Prometheus | `prometheus.rabalski.eu` | `192.168.1.11` |
| Grafana | `grafana.rabalski.eu` | `192.168.1.11` |
| qBittorrent | `qbit.rabalski.eu` | `192.168.1.11` |
| Prowlarr | `prowlarr.rabalski.eu` | `192.168.1.11` |
| Radarr | `radarr.rabalski.eu` | `192.168.1.11` |
| Sonarr | `sonarr.rabalski.eu` | `192.168.1.11` |
| Lidarr | `lidarr.rabalski.eu` | `192.168.1.11` |
| Jellyfin | `media.rabalski.eu` | `192.168.1.11` |
| Navidrome | `music.rabalski.eu` | `192.168.1.11` |

**Shortcut:** Use wildcard rewrite:
- Domain: `*.rabalski.eu`
- Answer: `192.168.1.11`
- **Exception:** `sink.rabalski.eu` → `192.168.1.1` (AdGuard on OPNsense)

**Recommended Upstream DNS:**
```
https://dns.cloudflare.com/dns-query
https://dns.quad9.net/dns-query
https://dns.google/dns-query
```

## Backup

AdGuard Home config is backed up automatically via OPNsense config backups.

## Troubleshooting

### DNS not resolving

```bash
# Check if AdGuard is listening (on OPNsense)
# Access via OPNsense web UI or SSH

# Test resolution from any LAN client
nslookup dom.rabalski.eu 192.168.1.1

# Test from narsis
nslookup dom.rabalski.eu
```

### Clients not using AdGuard

- OPNsense DHCP automatically assigns 192.168.1.1 as DNS
- Verify: `nslookup google.com` should show `192.168.1.1` as server

## Resources

- **Official Docs:** https://adguard.com/en/adguard-home/overview.html
- **GitHub:** https://github.com/AdguardTeam/AdGuardHome
