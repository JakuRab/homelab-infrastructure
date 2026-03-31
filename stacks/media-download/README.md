# Media Download Stack

**Purpose**: VPN-protected torrent downloading via Gluetun (ProtonVPN) + qBittorrent

**Components**:
- **Gluetun**: VPN client container (WireGuard to ProtonVPN)
- **qBittorrent**: Torrent client (all traffic routed through Gluetun)

---

## Prerequisites

### 1. Create External Networks

On narsis, create the `media_net` network (if not already created):

```bash
ssh athires@192.168.1.11

# Create media_net (shared across all media stacks)
docker network create media_net

# Verify both networks exist
docker network ls | grep -E 'caddy_net|media_net'
```

### 2. Create Storage Directories

```bash
# Create directory structure on narsis
ssh athires@192.168.1.11

sudo mkdir -p /mnt/nvme/services/media/config/gluetun
sudo mkdir -p /mnt/nvme/services/media/config/qbittorrent
sudo mkdir -p /mnt/nvme/services/media/downloads/incomplete
sudo mkdir -p /mnt/nvme/services/media/downloads/complete/{movies,tv,music}

# Set ownership (replace 1000:1000 with your PUID:PGID from 'id' command)
sudo chown -R 1000:1000 /mnt/nvme/services/media
```

### 3. Get ProtonVPN WireGuard Credentials

1. Log in to https://account.protonvpn.com/downloads
2. Navigate to **WireGuard configuration**
3. Select a server (or use "Random" for your preferred country)
4. Copy the following values:
   - **PrivateKey** → `WIREGUARD_PRIVATE_KEY`
   - **Address** → `WIREGUARD_ADDRESSES` (usually `10.2.0.2/32`)

---

## Deployment via Portainer

### Step 1: Deploy Stack

1. Open Portainer: `https://192.168.1.11:9443`
2. Navigate to: **Stacks → Add Stack**
3. Choose: **Repository**
4. Configure:
   - **Name**: `media-download`
   - **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `stacks/media-download/docker-compose.yml`

### Step 2: Add Environment Variables

Click **+ Add environment variable** for each:

| Variable | Value | Example |
|----------|-------|---------|
| `WIREGUARD_PRIVATE_KEY` | From ProtonVPN config | `aBcDeFgHiJkLmNoPqRsTuVwXyZ1234567890=` |
| `WIREGUARD_ADDRESSES` | From ProtonVPN config | `10.2.0.2/32` |
| `VPN_SERVER_COUNTRIES` | Preferred country | `Netherlands` |
| `PUID` | Your user ID (run `id`) | `1000` |
| `PGID` | Your group ID (run `id`) | `1000` |
| `TZ` | Your timezone | `Europe/Warsaw` |
| `QBITTORRENT_PORT` | Web UI port | `8080` |

### Step 3: Deploy

1. Click **Deploy the stack**
2. Wait for containers to start (~30-60 seconds)
3. Check logs for any errors

---

## Verification

### Check Container Status

```bash
ssh athires@192.168.1.11
docker ps | grep -E 'gluetun|qbittorrent'
```

Expected output:
```
CONTAINER ID   IMAGE                    STATUS         PORTS
abc123...      qmcgaw/gluetun:latest    Up 2 minutes   0.0.0.0:8080->8080/tcp, 0.0.0.0:8888->8888/tcp
def456...      lscr.io/.../qbittorrent  Up 2 minutes   (using gluetun's network)
```

### Verify VPN Connection

```bash
# Check Gluetun logs for successful connection
docker logs gluetun | grep -i "connected"

# Expected output should show:
# ✔ [VPN] connected to ProtonVPN
# ✔ [port forwarding] forwarded port XXXXX
```

### Verify IP Address (Should NOT be your home IP)

```bash
# Check qBittorrent's public IP (via Gluetun)
docker exec gluetun wget -qO- https://api.ipify.org
```

This should return a ProtonVPN server IP, NOT your home IP (31.178.228.90).

### Access qBittorrent Web UI

1. **Local access** (from Almalexia or LAN):
   ```
   http://192.168.1.11:8080
   ```

2. **Default credentials**:
   - Username: `admin`
   - Password: Check logs: `docker logs qbittorrent 2>&1 | grep -i password`

3. **Change password immediately** in Settings → Web UI

---

## Configuration

### qBittorrent Initial Setup

After first login, configure:

1. **Settings → Downloads**:
   - Default Save Path: `/downloads/incomplete`
   - Keep incomplete torrents in: `/downloads/incomplete`
   - Copy .torrent files to: `/downloads/torrents` (optional)

2. **Settings → Connection**:
   - Port used for incoming connections: Use the forwarded port from Gluetun logs
   - Enable UPnP/NAT-PMP: **Disable** (not needed with port forwarding)

3. **Settings → BitTorrent**:
   - Privacy: Enable "Anonymous mode"
   - Torrent Queueing: Recommended to limit to 3 active downloads

4. **Settings → Web UI**:
   - Change the default password
   - Enable "Bypass authentication for clients on localhost"
   - Optional: Enable CSRF protection

### Category Setup (for arr apps)

Create categories for automatic organization:

1. **Settings → Downloads → Categories**
2. Add categories:
   - `radarr` → Save path: `/downloads/complete/movies`
   - `sonarr` → Save path: `/downloads/complete/tv`
   - `lidarr` → Save path: `/downloads/complete/music`

This allows arr apps to assign categories automatically.

---

## Integration with Caddy (Reverse Proxy)

If you want to access qBittorrent via `https://qbit.rabalski.eu`:

1. **Update Caddyfile** on clockworkcity (or commit to Git):

```caddyfile
# ===========================
# qBittorrent (via Gluetun)
# ===========================
qbit.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://192.168.1.11:8080 {
    header_up -X-Forwarded-For
    header_up X-Forwarded-For  {remote_ip}
    header_up X-Real-IP        {remote_ip}
    header_up X-Forwarded-Proto {scheme}
    header_up Host             {host}
  }
}
```

2. **Reload Caddy**:

```bash
ssh athires@192.168.1.11
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

3. **Add DNS rewrite** in AdGuard Home:
   - `qbit.rabalski.eu` → `192.168.1.11`

4. **Access**: `https://qbit.rabalski.eu`

---

## Troubleshooting

### Quick Diagnostic Commands

```bash
# Full health check (run all of these)
docker ps | grep -E 'gluetun|qbittorrent|port-sync'      # Container status
docker exec gluetun cat /tmp/gluetun/forwarded_port       # Gluetun's forwarded port
docker exec gluetun wget -qO- http://localhost:8080/api/v2/app/preferences 2>/dev/null | grep -o '"listen_port":[0-9]*'  # qBittorrent's configured port
docker exec qbittorrent netstat -tlnp | grep -E "(8080|567)"  # Listening ports
docker logs port-sync --since 5m                           # port-sync status
```

### Gluetun won't start / VPN not connecting

**Check logs**:
```bash
docker logs gluetun --tail 50
```

**Common issues**:
- Invalid `WIREGUARD_PRIVATE_KEY`: Verify from ProtonVPN account
- Firewall blocking VPN: Check if UDP port 51820 is accessible
- ProtonVPN server down: Try different `SERVER_COUNTRIES`

**Solution**: Restart with different server:
```bash
# In Portainer, change VPN_SERVER_COUNTRIES to another country and redeploy
```

### qBittorrent not accessible

**Check if using Gluetun's network**:
```bash
docker inspect qbittorrent | grep -i networkmode
# Should show: "NetworkMode": "container:gluetun"
```

**Check Gluetun port exposure**:
```bash
docker port gluetun
# Should show: 8080/tcp -> 0.0.0.0:8080
```

### qBittorrent Shows "Firewalled" Status

This is a common issue indicating peers cannot connect to you. Usually caused by:

1. **Port mismatch** between Gluetun forwarded port and qBittorrent listen port
2. **Port bound to loopback only** instead of VPN interface
3. **Stale port forwarding** after extended uptime (2+ days)

**Diagnosis**:
```bash
# Check Gluetun's forwarded port
GLUETUN_PORT=$(docker exec gluetun cat /tmp/gluetun/forwarded_port)
echo "Gluetun forwarded port: $GLUETUN_PORT"

# Check qBittorrent's configured port (via API)
QBT_PORT=$(docker exec gluetun wget -qO- http://localhost:8080/api/v2/app/preferences 2>/dev/null | grep -o '"listen_port":[0-9]*' | cut -d: -f2)
echo "qBittorrent listen port: $QBT_PORT"

# Check if ports match
[ "$GLUETUN_PORT" = "$QBT_PORT" ] && echo "✓ Ports match" || echo "✗ PORT MISMATCH!"

# Check where qBittorrent is listening
docker exec qbittorrent netstat -tlnp | grep "$QBT_PORT"
```

**Expected listening output** (should include VPN interface 10.2.0.x):
```
tcp   0   0   10.2.0.2:56749      0.0.0.0:*   LISTEN   (VPN tunnel - GOOD)
tcp   0   0   172.22.0.8:56749    0.0.0.0:*   LISTEN   (media_net - OK)
tcp   0   0   127.0.0.1:56749     0.0.0.0:*   LISTEN   (loopback - OK)
```

**If listening only on 127.0.0.1** (loopback):
```bash
# Restart qBittorrent to re-bind to all interfaces
docker restart qbittorrent
sleep 10
docker exec qbittorrent netstat -tlnp | grep "$GLUETUN_PORT"
```

**Verify port is externally reachable**:
```bash
VPN_IP=$(docker exec gluetun wget -qO- https://api.ipify.org)
PORT=$(docker exec gluetun cat /tmp/gluetun/forwarded_port)
RESULT=$(docker exec gluetun wget -qO- "http://portcheck.transmissionbt.com/$PORT" 2>/dev/null)
echo "VPN IP: $VPN_IP, Port: $PORT, Open: $RESULT"
# Result should be "1" (open), not "0" (closed)
```

### port-sync Not Working

The `port-sync` sidecar (custom Alpine script) automatically syncs Gluetun's forwarded port to qBittorrent.

**Check port-sync logs**:
```bash
docker logs port-sync --since 10m
```

**Expected output** (working):
```
fetch https://dl-cdn.alpinelinux.org/alpine/v3.xx/main/...
OK: 14.1 MiB in 28 packages
Port synced: 47921
Port synced: 47921
```

The `apk add curl jq` install happens on every container start (before the loop). The install requires the VPN to be up first — it retries automatically every 10 seconds until it succeeds.

**Common errors and fixes**:

| Error | Cause | Fix |
|-------|-------|-----|
| `/bin/sh: curl: not found` | apk install failed (VPN not up yet) | Wait — it retries automatically; or `docker restart port-sync` |
| `curl: (7) Failed to connect to localhost port 8000` | Gluetun API not ready | `docker restart port-sync` after Gluetun is fully connected |
| `curl: (7) Failed to connect to localhost port 8080` | qBittorrent not ready | `docker restart qbittorrent && sleep 10 && docker restart port-sync` |
| Container shows "Restarting" | Script crashed | Check logs for error; restart stack |
| `{"port":0}` from Gluetun | VPN connected but port not yet assigned | Wait 30-60s, port-sync will pick it up on next loop |

**Nuclear option** (restart everything in order):
```bash
cd /home/kuba/aiTools/stacks/media-download
docker compose restart
# Or individually with proper ordering:
docker restart gluetun && sleep 30 && docker restart qbittorrent && sleep 10 && docker restart port-sync
```

---

### Gluetun Version Compatibility (IMPORTANT)

**Pinned to `qmcgaw/gluetun:v3.39.0`** — do not casually upgrade. Here's why:

| Version | ProtonVPN WireGuard | HTTP Auth | Port API Endpoint |
|---------|--------------------|-----------|--------------------|
| v3.38.0 | ❌ Not supported | None | `/v1/openvpn/portforwarded` |
| **v3.39.0** (current) | ✅ Yes | None | `/v1/openvpn/portforwarded` |
| v3.39.1+ | ✅ Yes | Optional/Mandatory | `/v1/portforward` |
| v3.40.1+ | ✅ Yes | Mandatory | `/v1/portforward` |

**Why v3.39.0:**
- Earliest version supporting ProtonVPN WireGuard
- No HTTP authentication on the control server
- Uses `/v1/openvpn/portforwarded` endpoint (what our script calls)

**If you upgrade Gluetun to v3.39.1+**, you must update port-sync too:
- Change API endpoint in the script: `/v1/openvpn/portforwarded` → `/v1/portforward`
- Either disable auth (`HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH=/dev/null` does NOT work — Gluetun ignores it) or configure an API key in a `config.toml` and set `GTN_APIKEY` env var in port-sync

**Symptoms of a version mismatch:**
- `HTTP 400` from Gluetun API → wrong endpoint (upgrade happened)
- `HTTP 401` from Gluetun API → auth required (using v3.39.1+ without key)
- `{"port":0}` or empty response → wrong endpoint

**Do NOT use `qmcgaw/gluetun:latest`** — it will silently upgrade on the next pull and break port forwarding.

### Port forwarding not working

**Check Gluetun logs**:
```bash
docker logs gluetun | grep -i "port forward"
```

**Expected output**:
```
INFO [port forwarding] starting
INFO [port forwarding] gateway external IPv4 address is X.X.X.X
INFO [port forwarding] port forwarded is XXXXX
INFO [firewall] setting allowed input port XXXXX through interface tun0...
```

**If no port forwarded**:
- Verify `VPN_PORT_FORWARDING=on` in environment
- ProtonVPN free accounts don't support port forwarding (requires paid plan)
- Try restarting Gluetun container

**Stale port forwarding** (port reported but not working):
ProtonVPN NAT-PMP port forwards can expire after extended sessions. The solution is to restart Gluetun:
```bash
docker restart gluetun
# Wait 30-60 seconds for new port assignment
docker exec gluetun cat /tmp/gluetun/forwarded_port
```

### Downloads slow or not starting

**Check VPN connection**:
```bash
docker exec gluetun wget -qO- https://api.ipify.org
```

**Check qBittorrent is using forwarded port**:
1. Get forwarded port: `docker logs gluetun | grep "forwarded port"`
2. In qBittorrent Settings → Connection, set that port

### Torrents Stuck on "Downloading Metadata" with 0 Peers

**Root causes**:
1. **Stale indexer data**: Seed counts in Radarr/Sonarr are cached from indexers, often hours/days old
2. **Dead torrents**: Torrent was active when indexed but seeds have since left
3. **Firewalled status**: Peers can't connect to you (see above)
4. **Private tracker issues**: Tracker rejecting connections

**Diagnosis**:
1. In qBittorrent, right-click torrent → **Trackers** tab
2. Check for errors: "timed out", "unreachable", "unregistered torrent"

**Tracker error meanings**:
| Error | Meaning |
|-------|---------|
| "timed out" / "unreachable" | Network/VPN routing issue or tracker down |
| "host not found" | DNS resolution failing |
| "unregistered torrent" | Torrent removed from private tracker |
| "connection refused" | Tracker blocking VPN IP |

**Fix DNS issues**:
```bash
# Test DNS from inside Gluetun
docker exec gluetun nslookup tracker.opentrackr.org
# Should resolve to an IP address
```

---

## Maintenance

### Automatic Weekly Restart (Recommended)

VPN port forwarding can become stale after extended uptime. A weekly restart ensures fresh port assignments and prevents connectivity issues.

**Included systemd timer files**:
- `media-download-restart.service` - Restarts the stack
- `media-download-restart.timer` - Triggers every Sunday at 4:00 AM

**Installation**:
```bash
# Copy timer files to systemd
sudo cp /home/athires/aiTools/stacks/media-download/media-download-restart.{service,timer} /etc/systemd/system/

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable --now media-download-restart.timer

# Verify timer is scheduled
systemctl list-timers | grep media-download
```

**Timer management**:
```bash
# Check next scheduled run
systemctl list-timers media-download-restart.timer

# Manually trigger restart now
sudo systemctl start media-download-restart.service

# View restart logs
journalctl -u media-download-restart.service

# Disable automatic restarts
sudo systemctl disable media-download-restart.timer
```

**Adjusting frequency**:
```bash
sudo systemctl edit media-download-restart.timer --full
```

Change `OnCalendar=` line:
- **Weekly (default)**: `OnCalendar=Sun *-*-* 04:00:00`
- **Daily**: `OnCalendar=*-*-* 04:00:00`
- **Twice weekly**: `OnCalendar=Wed,Sun *-*-* 04:00:00`
- **Every 3 days**: `OnCalendar=*-*-1,4,7,10,13,16,19,22,25,28,31 04:00:00`

---

## Security Notes

✅ **All torrent traffic encrypted** via WireGuard VPN
✅ **Killswitch enabled** - if VPN drops, qBittorrent cannot reach internet
✅ **No DNS leaks** - Gluetun handles DNS via Cloudflare (1.1.1.1)
✅ **LAN access restricted** - qBittorrent only accessible from `192.168.1.0/24`

⚠️ **Important**: Never expose qBittorrent directly to the internet without Caddy authentication or VPN

---

## Architecture Notes

### Container Network Sharing

All three containers share Gluetun's network namespace:
- **gluetun**: VPN tunnel owner, exposes ports 8080 (qBittorrent WebUI) and 8000 (control API)
- **qbittorrent**: `network_mode: service:gluetun` - all traffic routes through VPN
- **port-sync**: `network_mode: service:gluetun` - accesses both via localhost

**Why restarts sometimes fix issues**:
When containers start, they attach to Gluetun's network namespace. If Gluetun restarts or the namespace becomes stale, dependent containers may lose connectivity to localhost services within the shared namespace. Restarting re-establishes the namespace attachment.

### Port Forwarding Flow

```
ProtonVPN assigns port → Gluetun receives via NAT-PMP → Writes to /tmp/gluetun/forwarded_port
                                                      → Updates iptables firewall rules
                                                      → Exposes via API (:8000/v1/openvpn/portforwarded)
                                                                          ↓
port-sync (Alpine script) polls every 5 min → Reads port → Logs into qBittorrent WebUI
                                                         → Calls /api/v2/app/setPreferences
                                                                          ↓
qBittorrent binds to port on all interfaces → Peers can connect via VPN tunnel (10.2.0.2)
```

**Note**: The API endpoint `/v1/openvpn/portforwarded` is specific to **Gluetun v3.39.0**.
In v3.39.1+ it changed to `/v1/portforward`. See version compatibility table above.

---

## Next Steps

Once this stack is running:

1. Deploy **media-arr** stack (Prowlarr, Radarr, Sonarr, Lidarr)
2. Configure arr apps to use qBittorrent as download client
3. Deploy **media-streaming** stack (Jellyfin, Navidrome)
4. Start adding media!

---

**Stack Status**: ✅ Production
**Last Updated**: 2026-03-31
**Gluetun Version**: Pinned to `v3.39.0` (see version compatibility table before upgrading)
**Known Issues**: Port forwarding may become stale after 2+ days uptime (mitigated by weekly restart timer)
