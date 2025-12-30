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

### Port forwarding not working

**Check Gluetun logs**:
```bash
docker logs gluetun | grep -i "port forward"
```

**Expected output**:
```
✔ [port forwarding] forwarded port XXXXX
```

**If no port forwarded**:
- Verify `VPN_PORT_FORWARDING=on` in environment
- ProtonVPN free accounts don't support port forwarding (requires paid plan)
- Try restarting Gluetun container

### Downloads slow or not starting

**Check VPN connection**:
```bash
docker exec gluetun wget -qO- https://api.ipify.org
```

**Check qBittorrent is using forwarded port**:
1. Get forwarded port: `docker logs gluetun | grep "forwarded port"`
2. In qBittorrent Settings → Connection, set that port

---

## Security Notes

✅ **All torrent traffic encrypted** via WireGuard VPN
✅ **Killswitch enabled** - if VPN drops, qBittorrent cannot reach internet
✅ **No DNS leaks** - Gluetun handles DNS via Cloudflare (1.1.1.1)
✅ **LAN access restricted** - qBittorrent only accessible from `192.168.1.0/24`

⚠️ **Important**: Never expose qBittorrent directly to the internet without Caddy authentication or VPN

---

## Next Steps

Once this stack is running:

1. Deploy **media-arr** stack (Prowlarr, Radarr, Sonarr, Lidarr)
2. Configure arr apps to use qBittorrent as download client
3. Deploy **media-streaming** stack (Jellyfin, Navidrome)
4. Start adding media!

---

**Stack Status**: ⏳ Pending Deployment
**Last Updated**: 2025-12-07
