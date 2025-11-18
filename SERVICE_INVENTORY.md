# Service Inventory - Quick Reference

Complete list of all homelab services for easy reference.

## Summary Stats

- **Total Services:** 17
- **Critical Services:** 6 (AdGuard, Caddy, Home Assistant, Nextcloud, Portainer, Vaultwarden)
- **Docker Containers:** 14
- **System Services:** 1 (Tailscale)
- **TBD/Evaluate:** 2 (Marreta purpose, Cloudflare DDNS necessity)

---

## By Category

### 🔴 Critical Infrastructure (Cannot afford downtime)

1. **Caddy** - Reverse proxy (all services depend on it)
2. **AdGuard Home** - DNS server (split-horizon routing)
3. **Portainer** - Container management (manages all others)
4. **Tailscale** - VPN for remote access

### 🟡 Critical Services (Important for daily use)

5. **Home Assistant** - Smart home automation
6. **Vaultwarden** - Password manager (EXTREMELY sensitive)
7. **Nextcloud AIO** - File sync & collaboration

### 🟢 Monitoring & Operations

8. **Prometheus** - Metrics collection
9. **Grafana** - Metrics visualization
10. **Blackbox Exporter** - Probe monitoring
11. **Changedetection.io** - Website change monitoring
12. **Speedtest Tracker** - Internet speed monitoring

### 🔵 Productivity & Tools

13. **n8n** - Workflow automation
14. **SearXNG** - Privacy-respecting search
15. **n.eko** - Browser isolation
16. **Dumbpad** - Note-taking/pastebin
17. **Glance** - Dashboard

### ⚪ TBD/Evaluate

- **Marreta** - Purpose unclear, needs clarification
- **Cloudflare DDNS** - May be redundant with Caddy's Cloudflare integration

---

## By Domain

| Domain | Service | Container/Type |
|--------|---------|----------------|
| `rabalski.eu` | Redirect to Home Assistant | N/A |
| `21376942.rabalski.eu` | Vaultwarden | Docker |
| `cloud.rabalski.eu` | Nextcloud AIO | Docker (special) |
| `deck.rabalski.eu` | Glance | Docker |
| `dom.rabalski.eu` | Home Assistant | Docker |
| `grafana.rabalski.eu` | Grafana | Docker (part of net_monitor) |
| `kicia.rabalski.eu` | n.eko | Docker |
| `n8n.rabalski.eu` | n8n | Docker |
| `pad.rabalski.eu` | Dumbpad | Docker |
| `portainer.rabalski.eu` | Portainer | Docker |
| `prometheus.rabalski.eu` | Prometheus | Docker (part of net_monitor) |
| `ram.rabalski.eu` | Marreta | Docker |
| `search.rabalski.eu` | SearXNG | Docker |
| `sink.rabalski.eu` | AdGuard Home | Docker |
| `speedtest.rabalski.eu` | Speedtest Tracker | Docker |
| `watch.rabalski.eu` | Changedetection.io | Docker |
| N/A (port 443) | Caddy | Docker |
| N/A (overlay) | Tailscale | systemd |

---

## By Data Criticality

### 🔐 CRITICAL DATA (Must backup, cannot lose)

1. **Vaultwarden** (`/opt/vaultwarden/data/`)
   - Encrypted password vault
   - Loss = catastrophic

2. **Nextcloud** (`/mnt/ncdata/`)
   - User files, photos, documents
   - Loss = major data loss

3. **Home Assistant** (`/opt/homeassistant/config/`)
   - Automations, dashboards, device configs
   - Loss = months of configuration work

### ⚠️ IMPORTANT DATA (Should backup regularly)

4. **AdGuard Home** (`/opt/adguardhome/conf/`)
   - DNS rewrites, filters, settings
   - Loss = service disruption until reconfigured

5. **n8n** (`/opt/n8n/data/`)
   - Workflows, credentials
   - Loss = need to rebuild workflows

6. **Grafana** (part of monitoring stack)
   - Dashboards, data sources
   - Loss = need to rebuild dashboards

### ℹ️ REPLACEABLE (Can rebuild from config)

7. **Prometheus** - Time-series data (historical)
8. **Changedetection.io** - Monitoring history
9. **Speedtest Tracker** - Test history
10. **SearXNG** - Minimal config
11. **n.eko** - Session-based
12. **Glance** - Config in repo
13. **Dumbpad** - Notes (depends on usage)

### 🔄 STATELESS (No persistent data)

14. **Caddy** - Config in Git, certificates auto-renewed
15. **Portainer** - Can rebuild (backed up separately)
16. **Blackbox Exporter** - No persistent state
17. **Tailscale** - Cloud-managed state

---

## By Deployment Method

### 📦 Git-Managed (or will be)

**Migrated:**
- None yet

**Ready to migrate:**
- n8n (test case)
- Home Assistant
- Monitoring stack
- All Phase 3 & 4 services

### 🔧 Manual Deployment (Keep as-is)

**Should stay manual:**
- Caddy (too critical)
- Portainer (bootstrap service)
- Nextcloud AIO (special deployment model)
- Tailscale (systemd, not Docker)

---

## By Migration Priority

### 🔥 Phase 1: Foundation
- [x] Git setup
- [x] Secrets structure
- [x] Documentation
- [ ] n8n test migration ⭐

### 🔥 Phase 2: Critical (After n8n success)
1. AdGuard Home
2. Home Assistant
3. Vaultwarden (with extreme care)
4. Monitoring stack

### 🟡 Phase 3: Medium Priority
5. SearXNG
6. Changedetection.io
7. Glance
8. n.eko

### 🟢 Phase 4: Low Priority
9. Speedtest Tracker
10. Dumbpad
11. Marreta (TBD)
12. Cloudflare DDNS (evaluate first)

---

## Resource Requirements

### High CPU/Memory
- **Home Assistant** - Continuous automation processing
- **Nextcloud AIO** - Multiple containers (Apache, DB, Redis, etc.)
- **Prometheus** - Time-series database
- **n.eko** - Browser instance (Firefox)

### Medium
- **Caddy** - Proxies all traffic
- **Grafana** - Dashboard rendering
- **n8n** - Workflow execution
- **Vaultwarden** - Moderate usage

### Low
- **AdGuard Home** - DNS is lightweight
- **Portainer** - Management UI
- **SearXNG** - Proxy for search engines
- **Changedetection.io** - Periodic checks
- **Speedtest Tracker** - Scheduled tests
- **Glance** - Static dashboard
- **Dumbpad** - Simple note storage
- **Blackbox Exporter** - Probe checks
- **Tailscale** - Minimal overhead

---

## Network Dependencies

### Required by ALL services
- **Caddy** - Reverse proxy
- **AdGuard Home** - DNS resolution
- **Tailscale** - Remote access (optional but useful)

### Services with special network needs
- **Home Assistant** - USB passthrough for Zigbee
- **n.eko** - WebRTC ports
- **Nextcloud AIO** - Host network for mastercontainer
- **Monitoring** - Access to all services for probes

---

## Secrets Inventory

### API Tokens
- Cloudflare API token (Caddy)
- Various integration tokens (Home Assistant)
- SMTP credentials (multiple services)

### Passwords
- Grafana admin
- Vaultwarden admin token
- Nextcloud master password
- n8n encryption key
- AdGuard Home admin
- Portainer admin
- n.eko access password
- Dumbpad auth (if configured)

### Certificates
- Auto-managed by Caddy (Let's Encrypt)
- Stored in Caddy data volume

---

## Questions to Answer

1. **Marreta (`ram.rabalski.eu`):**
   - What is this service?
   - What container/image?
   - Is it actively used?

2. **Cloudflare DDNS:**
   - Still needed with Caddy's Cloudflare integration?
   - Does Caddy update A/AAAA records or just TXT for ACME?
   - Can we consolidate?

3. **Vaultwarden Export:**
   - Preferred export method?
   - Test restore before migration?
   - Alternative password access during migration?

---

## Next Actions

**Before starting migrations:**

1. [ ] Clarify Marreta purpose and usage
2. [ ] Evaluate Cloudflare DDNS necessity
3. [ ] Plan Vaultwarden backup/export strategy
4. [ ] Push repositories to GitHub
5. [ ] Complete n8n test migration

**After n8n success:**

6. [ ] Document lessons learned
7. [ ] Update migration procedures based on findings
8. [ ] Begin Phase 2 critical service migrations

---

**See Also:**
- **[Migration Tracker](docs/migration-tracker.md)** - Detailed migration status
- **[Architecture Overview](homelabbing/homelab.md)** - Network topology
- **[Deployment Guide](docs/deployment.md)** - How to deploy services

**Last Updated:** 2025-11-18
