# Media Arr Stack

**Purpose**: Automated media management and indexing

**Components**:
- **Prowlarr**: Centralized indexer manager (syncs to all arr apps)
- **Radarr**: Movie collection manager
- **Sonarr**: TV show collection manager
- **Lidarr**: Music collection manager
- **FlareSolverr**: Cloudflare bypass for indexers (optional helper)

---

## Prerequisites

### 1. Ensure Networks Exist

```bash
ssh athires@192.168.1.11

# Verify networks (should already exist from media-download stack)
docker network ls | grep -E 'caddy_net|media_net'
```

If `media_net` doesn't exist:
```bash
docker network create media_net
```

### 2. Create Storage Directories

```bash
ssh athires@192.168.1.11

# Create config directories
sudo mkdir -p /mnt/nvme/services/media/config/{prowlarr,radarr,sonarr,lidarr}

# Create media library directories
sudo mkdir -p /mnt/nvme/services/media/media/{movies,tv,music}

# Set ownership (replace 1000:1000 with your PUID:PGID from 'id' command)
sudo chown -R 1000:1000 /mnt/nvme/services/media
```

### 3. Ensure media-download Stack is Running

The arr apps need qBittorrent to be accessible:

```bash
ssh athires@192.168.1.11
docker ps | grep qbittorrent
# Should show qbittorrent container running
```

---

## Deployment via Portainer

### Step 1: Deploy Stack

1. Open Portainer: `https://192.168.1.11:9443`
2. Navigate to: **Stacks → Add Stack**
3. Choose: **Repository**
4. Configure:
   - **Name**: `media-arr`
   - **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `stacks/media-arr/docker-compose.yml`

### Step 2: Add Environment Variables

Click **+ Add environment variable** for each:

| Variable | Value | Example |
|----------|-------|---------|
| `PUID` | Your user ID (run `id`) | `1000` |
| `PGID` | Your group ID (run `id`) | `1000` |
| `TZ` | Your timezone | `Europe/Warsaw` |
| `LOG_LEVEL` | FlareSolverr log level | `info` |
| `LOG_HTML` | Log HTML responses | `false` |
| `CAPTCHA_SOLVER` | Captcha solver | `none` |

### Step 3: Deploy

1. Click **Deploy the stack**
2. Wait for containers to start (~30-60 seconds)
3. Check logs for any errors

---

## Verification

### Check Container Status

```bash
ssh athires@192.168.1.11
docker ps | grep -E 'prowlarr|radarr|sonarr|lidarr|flaresolverr'
```

Expected output:
```
CONTAINER ID   IMAGE                           STATUS         PORTS
abc123...      lscr.io/.../prowlarr:latest    Up 2 minutes   9696/tcp
def456...      lscr.io/.../radarr:latest      Up 2 minutes   7878/tcp
ghi789...      lscr.io/.../sonarr:latest      Up 2 minutes   8989/tcp
jkl012...      lscr.io/.../lidarr:latest      Up 2 minutes   8686/tcp
mno345...      ghcr.io/.../flaresolverr       Up 2 minutes   8191/tcp
```

### Access Web UIs (Local Testing)

Before setting up Caddy reverse proxy, test locally:

- **Prowlarr**: `http://192.168.1.11:9696`
- **Radarr**: `http://192.168.1.11:7878`
- **Sonarr**: `http://192.168.1.11:8989`
- **Lidarr**: `http://192.168.1.11:8686`
- **FlareSolverr**: `http://192.168.1.11:8191` (test endpoint)

---

## Initial Configuration

### 1. Prowlarr Setup (Do This First!)

Prowlarr is the central hub - configure it before other arr apps.

#### Add Indexers

1. Open Prowlarr: `http://192.168.1.11:9696`
2. Navigate to: **Indexers → Add Indexer**
3. Search for public trackers (examples):
   - **The Pirate Bay** (public, no registration)
   - **1337x** (public, no registration)
   - **RARBG** (if still available)
   - **YTS** (movies only)

4. For each indexer:
   - Click **Add**
   - Configure categories (Movies, TV, Music, etc.)
   - If FlareSolverr needed, set FlareSolverr URL: `http://flaresolverr:8191`
   - Click **Test** then **Save**

**Note**: For private trackers (like TorrentLeech, IPTorrents), you'll need accounts and API keys.

#### Connect arr Apps to Prowlarr

1. In Prowlarr: **Settings → Apps → Add Application**
2. Add each arr app:

**Radarr**:
- Prowlarr Server: `http://prowlarr:9696`
- Radarr Server: `http://radarr:7878`
- API Key: Get from Radarr → Settings → General → API Key
- Click **Test** then **Save**

**Sonarr**:
- Prowlarr Server: `http://prowlarr:9696`
- Sonarr Server: `http://sonarr:8989`
- API Key: Get from Sonarr → Settings → General → API Key
- Click **Test** then **Save**

**Lidarr**:
- Prowlarr Server: `http://prowlarr:9696`
- Lidarr Server: `http://lidarr:8686`
- API Key: Get from Lidarr → Settings → General → API Key
- Click **Test** then **Save**

3. Click **Sync App Indexers** in Prowlarr
4. All indexers will now appear in Radarr, Sonarr, and Lidarr automatically!

---

### 2. Radarr Setup (Movies)

#### Add Download Client (qBittorrent)

1. Open Radarr: `http://192.168.1.11:7878`
2. Navigate to: **Settings → Download Clients → Add → qBittorrent**
3. Configure:
   - **Name**: `qBittorrent`
   - **Host**: `192.168.1.11` (or `gluetun` if on same network)
   - **Port**: `8080`
   - **Username**: `admin`
   - **Password**: (from qBittorrent setup)
   - **Category**: `radarr`
   - Click **Test** then **Save**

#### Configure Media Management

1. **Settings → Media Management**
2. Enable:
   - ✅ **Rename Movies**
   - ✅ **Replace Illegal Characters**
3. **Standard Movie Format**:
   ```
   {Movie Title} ({Release Year}) {Quality Full}
   ```
4. **Movie Folder Format**:
   ```
   {Movie Title} ({Release Year})
   ```
5. **Root Folders**: Add `/movies`
6. Click **Save**

#### Add Your First Movie

1. **Movies → Add New Movie**
2. Search for a movie (e.g., "The Matrix")
3. Select:
   - **Root Folder**: `/movies`
   - **Quality Profile**: `HD-1080p` (or create custom)
   - **Monitored**: ✅
   - **Search on Add**: ✅ (to download immediately)
4. Click **Add Movie**

---

### 3. Sonarr Setup (TV Shows)

#### Add Download Client (qBittorrent)

1. Open Sonarr: `http://192.168.1.11:8989`
2. Navigate to: **Settings → Download Clients → Add → qBittorrent**
3. Configure:
   - **Name**: `qBittorrent`
   - **Host**: `192.168.1.11`
   - **Port**: `8080`
   - **Username**: `admin`
   - **Password**: (from qBittorrent setup)
   - **Category**: `sonarr`
   - Click **Test** then **Save**

#### Configure Media Management

1. **Settings → Media Management**
2. **Episode Naming**:
   - **Standard Episode Format**:
     ```
     {Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}
     ```
   - **Daily Episode Format**:
     ```
     {Series Title} - {Air-Date} - {Episode Title} {Quality Full}
     ```
3. **Root Folders**: Add `/tv`
4. Click **Save**

#### Add Your First TV Show

1. **Series → Add New Series**
2. Search for a show (e.g., "Breaking Bad")
3. Select:
   - **Root Folder**: `/tv`
   - **Quality Profile**: `HD-1080p`
   - **Series Type**: `Standard`
   - **Seasons**: Choose which to monitor
   - **Search on Add**: ✅
4. Click **Add Series**

---

### 4. Lidarr Setup (Music)

#### Add Download Client (qBittorrent)

1. Open Lidarr: `http://192.168.1.11:8686`
2. Navigate to: **Settings → Download Clients → Add → qBittorrent**
3. Configure:
   - **Name**: `qBittorrent`
   - **Host**: `192.168.1.11`
   - **Port**: `8080`
   - **Username**: `admin`
   - **Password**: (from qBittorrent setup)
   - **Category**: `lidarr`
   - Click **Test** then **Save**

#### Configure Media Management

1. **Settings → Media Management**
2. **File Naming**:
   - **Standard Track Format**:
     ```
     {Artist Name} - {Album Title} - {track:00} - {Track Title}
     ```
3. **Root Folders**: Add `/music`
4. Click **Save**

#### Add Your First Artist

1. **Library → Add New Artist**
2. Search for an artist (e.g., "Pink Floyd")
3. Select:
   - **Root Folder**: `/music`
   - **Quality Profile**: `Lossless` or `High Quality`
   - **Metadata Profile**: `Standard`
   - **Monitored**: ✅
   - **Search on Add**: ✅
4. Click **Add Artist**

---

## Integration with Caddy (Reverse Proxy)

Add these blocks to Caddyfile on clockworkcity (or commit to Git):

```caddyfile
# ===========================
# Prowlarr
# ===========================
prowlarr.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://192.168.1.11:9696
}

# ===========================
# Radarr
# ===========================
radarr.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://192.168.1.11:7878
}

# ===========================
# Sonarr
# ===========================
sonarr.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://192.168.1.11:8989
}

# ===========================
# Lidarr
# ===========================
lidarr.rabalski.eu {
  import gate
  encode zstd gzip
  reverse_proxy http://192.168.1.11:8686
}
```

**Reload Caddy**:
```bash
ssh athires@192.168.1.11
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**Add DNS rewrites** in AdGuard Home:
- `prowlarr.rabalski.eu` → `192.168.1.11`
- `radarr.rabalski.eu` → `192.168.1.11`
- `sonarr.rabalski.eu` → `192.168.1.11`
- `lidarr.rabalski.eu` → `192.168.1.11`

**Access via HTTPS**:
- `https://prowlarr.rabalski.eu`
- `https://radarr.rabalski.eu`
- `https://sonarr.rabalski.eu`
- `https://lidarr.rabalski.eu`

---

## Workflow Overview

Once configured, the workflow is:

1. **Add media** in Radarr/Sonarr/Lidarr (search by title)
2. **Arr app searches** indexers (via Prowlarr)
3. **Download triggered** via qBittorrent (through VPN)
4. **Download completes** → moved to `/downloads/complete/{movies,tv,music}`
5. **Arr app imports** → renames and moves to `/media/{movies,tv,music}`
6. **Jellyfin scans** and adds to library
7. **Stream and enjoy!**

---

## Troubleshooting

### Prowlarr can't connect to arr apps

**Error**: "Unable to connect to Radarr/Sonarr/Lidarr"

**Check**:
1. Containers on same network: `docker network inspect media_net`
2. API keys are correct (copy from arr app → Settings → General)
3. Use container names (`http://radarr:7878` NOT `http://192.168.1.11:7878`)

### Arr apps can't connect to qBittorrent

**Error**: "Unable to connect to qBittorrent"

**Check**:
1. qBittorrent is running: `docker ps | grep qbittorrent`
2. Use host IP: `192.168.1.11:8080` (qBittorrent uses Gluetun's network)
3. Username/password correct in qBittorrent settings
4. Test from arr app container:
   ```bash
   docker exec radarr curl -I http://192.168.1.11:8080
   ```

### Downloads not importing

**Check**:
1. **Permissions**: `/downloads` and `/media` owned by same PUID:PGID
   ```bash
   ssh athires@192.168.1.11
   ls -la /mnt/nvme/services/media/downloads/complete
   ls -la /mnt/nvme/services/media/media
   ```
2. **Category in qBittorrent**: Ensure torrent has correct category (`radarr`, `sonarr`, `lidarr`)
3. **Completed Download Handling**: Enabled in arr app → Settings → Download Clients

### Indexers failing in Prowlarr

**Common issues**:
- **Cloudflare protection**: Add FlareSolverr URL to indexer settings
- **Rate limiting**: Some indexers limit requests, wait and retry
- **Indexer down**: Check indexer status on status pages

---

## Advanced: Quality Profiles (TRaSH Guides)

For optimal quality management, consider using [TRaSH Guides](https://trash-guides.info/):

- **Radarr**: Custom formats for proper releases (remux, webdl, etc.)
- **Sonarr**: Season pack preferences, proper/repack handling
- **Lidarr**: Lossless vs lossy preferences

You can sync these automatically using **Recyclarr** (to be deployed separately).

---

## Next Steps

1. ✅ Configure all arr apps with qBittorrent
2. ✅ Add indexers to Prowlarr and sync to arr apps
3. ⏳ Deploy **media-streaming** stack (Jellyfin, Navidrome)
4. ⏳ Add media and start downloading!

---

**Stack Status**: ⏳ Pending Deployment
**Last Updated**: 2025-12-07
