# Media Streaming Stack

**Purpose**: Stream your media library (movies, TV shows, music)

**Components**:
- **Jellyfin**: Media server for movies and TV shows (open-source alternative to Plex)
- **Navidrome**: Music streaming server (Subsonic-compatible, works with mobile apps)

---

## Prerequisites

### 1. Ensure Networks Exist

```bash
ssh athires@192.168.1.11

# Verify networks (should already exist from previous stacks)
docker network ls | grep -E 'caddy_net|media_net'
```

### 2. Create Storage Directories

```bash
ssh athires@192.168.1.11

# Create config directories
sudo mkdir -p /mnt/nvme/services/media/config/jellyfin/{cache,transcodes}
sudo mkdir -p /mnt/nvme/services/media/config/navidrome

# Media directories should already exist from media-arr stack
# But verify they're present:
ls -la /mnt/nvme/services/media/media/

# Set ownership (replace 1000:1000 with your PUID:PGID from 'id' command)
sudo chown -R 1000:1000 /mnt/nvme/services/media
```

### 3. Ensure Media Library Has Content

Before deploying, you should have:
- Media added via Radarr/Sonarr/Lidarr, OR
- Existing media files manually copied to `/mnt/nvme/services/media/media/{movies,tv,music}`

Empty libraries are fine for initial setup - you can add media later.

---

## Deployment via Portainer

### Step 1: Deploy Stack

1. Open Portainer: `https://192.168.1.11:9443`
2. Navigate to: **Stacks → Add Stack**
3. Choose: **Repository**
4. Configure:
   - **Name**: `media-streaming`
   - **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
   - **Repository reference**: `refs/heads/main`
   - **Compose path**: `stacks/media-streaming/docker-compose.yml`

### Step 2: Add Environment Variables

Click **+ Add environment variable** for each:

| Variable | Value | Example |
|----------|-------|---------|
| `PUID` | Your user ID (run `id`) | `1000` |
| `PGID` | Your group ID (run `id`) | `1000` |
| `TZ` | Your timezone | `Europe/Warsaw` |
| `JELLYFIN_URL` | Public Jellyfin URL | `https://media.rabalski.eu` |
| `NAVIDROME_SCAN_SCHEDULE` | Music scan frequency | `@every 1h` |
| `NAVIDROME_LOG_LEVEL` | Log verbosity | `info` |
| `NAVIDROME_SESSION_TIMEOUT` | Session duration | `24h` |
| `NAVIDROME_BASE_URL` | Base URL (usually empty) | `` |

### Step 3: Deploy

1. Click **Deploy the stack**
2. Wait for containers to start (~30-60 seconds)
3. Check logs for any errors

---

## Verification

### Check Container Status

```bash
ssh athires@192.168.1.11
docker ps | grep -E 'jellyfin|navidrome'
```

Expected output:
```
CONTAINER ID   IMAGE                        STATUS         PORTS
abc123...      jellyfin/jellyfin:latest     Up 2 minutes   8096/tcp, 8920/tcp
def456...      deluan/navidrome:latest      Up 2 minutes   4533/tcp
```

### Access Web UIs (Local Testing)

Before setting up Caddy reverse proxy, test locally:

- **Jellyfin**: `http://192.168.1.11:8096`
- **Navidrome**: `http://192.168.1.11:4533`

---

## Initial Configuration

### 1. Jellyfin Setup

#### First-Time Wizard

1. Open Jellyfin: `http://192.168.1.11:8096`
2. Select language and click **Next**
3. **Create User Account**:
   - Username: (your choice, e.g., `kuba`)
   - Password: (strong password)
   - Click **Next**

#### Add Media Libraries

1. **Add Media Library** for each type:

**Movies**:
- Content type: **Movies**
- Display name: `Movies`
- Folders: Click **+** and add `/media/movies`
- Preferred language: `Polish` or `English`
- Country: `Poland`
- Click **OK**

**TV Shows**:
- Content type: **Shows**
- Display name: `TV Shows`
- Folders: Click **+** and add `/media/tv`
- Preferred language: `Polish` or `English`
- Country: `Poland`
- Click **OK**

**Music** (optional, if not using Navidrome exclusively):
- Content type: **Music**
- Display name: `Music`
- Folders: Click **+** and add `/media/music`
- Click **OK**

2. Click **Next** → **Next** → **Finish**

#### Configure Transcoding

1. Navigate to: **Dashboard → Playback**
2. **Transcoding** section:
   - Hardware acceleration: `None` (for now, change to NVENC when GPU installed)
   - Threading: Leave at auto-detected value
3. Click **Save**

**Note**: When you install the Quadro T400/T600 GPU:
1. Uncomment the `devices` section in `docker-compose.yml`
2. Redeploy stack
3. Change hardware acceleration to: **NVIDIA NVENC**

#### Additional Settings

1. **Dashboard → Networking**:
   - Enable automatic port mapping: ❌ (not needed behind reverse proxy)
   - Known proxies: Add `192.168.1.10` (clockworkcity Caddy)
   - Click **Save**

2. **Dashboard → Libraries**:
   - Enable automatic library scan: ✅
   - Scan library every: `12 hours`
   - Click **Save**

---

### 2. Navidrome Setup

#### First Login

1. Open Navidrome: `http://192.168.1.11:4533`
2. **Create Admin Account** (first user is admin):
   - Username: (your choice, e.g., `kuba`)
   - Password: (strong password)
   - Click **Create Admin**

#### Initial Scan

Navidrome will automatically scan `/music` directory on startup and periodically based on `NAVIDROME_SCAN_SCHEDULE`.

To trigger manual scan:
1. Click **Settings** (gear icon) → **Users**
2. Click your username → **Rescan**

#### Configure Settings

1. **Settings → General**:
   - Server name: `Rabalski Music`
   - Enable public registration: ❌ (keep private)
   - Enable sharing: ✅ (if you want to share playlists)

2. **Settings → Advanced**:
   - Scan interval: Matches `NAVIDROME_SCAN_SCHEDULE`
   - Ignore articles when sorting: ✅ (ignores "The", "A", etc.)

---

## Mobile Apps

### Jellyfin Clients

**Official Apps**:
- **Android**: [Jellyfin for Android](https://play.google.com/store/apps/details?id=org.jellyfin.mobile) (free)
- **iOS**: [Jellyfin Mobile](https://apps.apple.com/app/jellyfin-mobile/id1480192618) (free)
- **Android TV**: Available on Play Store

**Third-Party Apps** (often better UX):
- **Android**: Findroid (modern Material You design)
- **Android TV**: Findroid TV

**Setup**:
1. Install app
2. Enter server URL: `https://media.rabalski.eu` (once Caddy configured)
3. Login with your Jellyfin credentials

---

### Navidrome Clients (Subsonic-Compatible)

**Recommended Apps**:
- **Android**:
  - [Symfonium](https://play.google.com/store/apps/details?id=app.symfonik.music.player) (paid, best UX)
  - [DSub](https://play.google.com/store/apps/details?id=github.daneren2005.dsub) (free)
  - [Ultrasonic](https://f-droid.org/packages/org.moire.ultrasonic/) (free, open-source)

- **iOS**:
  - [play:Sub](https://apps.apple.com/app/playsub/id955329386) (paid)
  - [substreamer](https://apps.apple.com/app/substreamer/id1012991665) (free)

**Setup**:
1. Install app
2. Add server:
   - Server URL: `https://music.rabalski.eu`
   - Username: (your Navidrome username)
   - Password: (your Navidrome password)
   - Server type: `Subsonic` or `Navidrome`
3. Done! Music will sync and you can stream/download offline

---

## Integration with Caddy (Reverse Proxy)

Add these blocks to Caddyfile on clockworkcity (or commit to Git):

```caddyfile
# ===========================
# Jellyfin Media Server
# ===========================
media.rabalski.eu {
  import gate
  encode zstd gzip

  reverse_proxy http://192.168.1.11:8096 {
    header_up -X-Forwarded-For
    header_up X-Forwarded-For  {remote_ip}
    header_up X-Real-IP        {remote_ip}
    header_up X-Forwarded-Proto {scheme}
    header_up Host             {host}
  }

  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Content-Type-Options "nosniff"
    X-Frame-Options "SAMEORIGIN"
  }
}

# ===========================
# Navidrome Music Server
# ===========================
music.rabalski.eu {
  import gate
  encode zstd gzip

  reverse_proxy http://192.168.1.11:4533 {
    header_up -X-Forwarded-For
    header_up X-Forwarded-For  {remote_ip}
    header_up X-Real-IP        {remote_ip}
    header_up X-Forwarded-Proto {scheme}
    header_up Host             {host}
  }

  header {
    Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    X-Content-Type-Options "nosniff"
  }
}
```

**Reload Caddy**:
```bash
ssh sothasil@192.168.1.10
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

**Add DNS rewrites** in AdGuard Home:
- `media.rabalski.eu` → `192.168.1.10` (or `100.98.21.87` for Tailscale)
- `music.rabalski.eu` → `192.168.1.10`

**Access via HTTPS**:
- `https://media.rabalski.eu` (Jellyfin)
- `https://music.rabalski.eu` (Navidrome)

---

## Workflow: From Download to Streaming

1. **Add media** in Radarr/Sonarr/Lidarr
2. **Download via qBittorrent** (through VPN)
3. **Import to library** by arr app:
   - Movies → `/mnt/nvme/services/media/media/movies/`
   - TV → `/mnt/nvme/services/media/media/tv/`
   - Music → `/mnt/nvme/services/media/media/music/`
4. **Jellyfin/Navidrome auto-scan** (or trigger manual scan)
5. **Stream** via web browser or mobile app
6. **Enjoy!** 🎬🎵

---

## Troubleshooting

### Jellyfin not finding media

**Check permissions**:
```bash
ssh athires@192.168.1.11
ls -la /mnt/nvme/services/media/media/movies
ls -la /mnt/nvme/services/media/media/tv
```

Should show ownership matching your PUID:PGID (e.g., `1000:1000` or `athires:athires`).

**Fix permissions if needed**:
```bash
sudo chown -R 1000:1000 /mnt/nvme/services/media/media
sudo chmod -R 755 /mnt/nvme/services/media/media
```

**Trigger manual scan**:
1. Jellyfin → Dashboard → Libraries
2. Click **Scan All Libraries**

---

### Navidrome not showing music

**Check music directory**:
```bash
ssh athires@192.168.1.11
ls -la /mnt/nvme/services/media/media/music
```

**Trigger manual rescan**:
1. Navidrome → Settings → Users
2. Click your user → **Rescan**

**Check logs**:
```bash
docker logs navidrome --tail 50
```

Look for errors related to file permissions or unsupported formats.

---

### Transcoding fails in Jellyfin

**Check logs**:
```bash
docker logs jellyfin --tail 100 | grep -i transcode
```

**Common issues**:
- **CPU transcoding slow**: Normal on Xeon without GPU, upgrade to GPU for hardware acceleration
- **Codec not supported**: Install `jellyfin-ffmpeg` (included in container by default)

**When GPU installed**:
1. Verify GPU accessible:
   ```bash
   docker exec jellyfin nvidia-smi
   # or for Intel iGPU:
   docker exec jellyfin ls -la /dev/dri
   ```
2. Dashboard → Playback → Hardware acceleration → `NVIDIA NVENC`

---

### Can't connect via mobile app

**Check**:
1. **Server URL correct**: `https://media.rabalski.eu` (not `http://192.168.1.11:8096`)
2. **Caddy configured**: Test in browser first
3. **Firewall**: LAN + Tailscale allowed via Caddy `gate` matcher
4. **HTTPS certificate valid**: Browser should show green lock

**For local network only** (no Caddy):
- Use local IP: `http://192.168.1.11:8096`
- Won't work outside your network

---

## Storage Planning

Current setup uses NVMe for all media. For large libraries:

**Future expansion options**:
1. **Add 2.5" drives** to hot-swap bays:
   - Each 2.5" SSD/HDD can hold 1-4TB
   - 24 bays = up to ~96TB (with 4TB drives)

2. **Move media to bulk storage**:
   ```bash
   # Example: Mount new drive at /mnt/storage
   # Update docker-compose.yml volumes:
   - /mnt/storage/media/movies:/media/movies:ro
   - /mnt/storage/media/tv:/media/tv:ro
   ```

3. **Keep configs on NVMe** (fast access for databases):
   - Jellyfin config/cache
   - Navidrome database
   - Arr app configs

---

## Performance Optimization

### Jellyfin

**When GPU installed** (Quadro T400/T600):
1. Uncomment `devices` in docker-compose.yml
2. Redeploy stack
3. Enable NVENC in Jellyfin settings
4. **Result**: 20-30× faster transcoding, lower CPU usage

**For current CPU-only setup**:
- Limit simultaneous transcodes: Dashboard → Playback → Throttle transcodes
- Encourage direct play (no transcoding) by using compatible formats

### Navidrome

- Uses very little CPU/RAM
- Database on NVMe (fast)
- Music scans: Schedule during low-usage times (e.g., 3 AM)

---

## Next Steps

1. ✅ Add media via Radarr/Sonarr/Lidarr
2. ✅ Install mobile apps and test streaming
3. ⏳ When Quadro GPU arrives: Enable hardware transcoding
4. ⏳ Plan bulk storage strategy for large media library

---

**Stack Status**: ⏳ Pending Deployment
**Last Updated**: 2025-12-07
