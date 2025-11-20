# Home Assistant - Smart Home Automation

Open source home automation platform with Zigbee support.

## Service Information

- **Image:** `ghcr.io/home-assistant/home-assistant:stable`
- **Domain:** `dom.rabalski.eu`
- **Data:** Docker volume `homeassistant_ha_config`
- **USB Device:** Sonoff Zigbee 3.0 USB Dongle Plus V2
- **Network:** `caddy_net`

## Hardware Requirements

**Zigbee USB Dongle:**
- Device: `/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_V2_184bf3194b53ef11b8be2ce0174bec31-if00-port0`
- Mapped to: `/dev/ttyUSB0` in container

**Note:** The device path is persistent by USB serial ID, so it won't change even if USB ports change.

## Deployment

### Prerequisites

```bash
# Verify USB dongle is connected
ls -la /dev/serial/by-id/usb-Itead*

# Verify existing volume (preserves data)
docker volume inspect homeassistant_ha_config
```

### Via Portainer

1. **Stacks → Add Stack → Repository**
2. **Repository URL:** `https://github.com/JakuRab/homelab-infrastructure`
3. **Reference:** `refs/heads/main`
4. **Compose path:** `stacks/homeassistant/docker-compose.yml`
5. **Environment variables:**
   - `TZ=Europe/Warsaw` (only variable needed)
6. **Deploy**

### First Access

After deployment:
- Access: `https://dom.rabalski.eu`
- Login with existing account
- All automations, devices, and configuration preserved

## Backup

### Full Config Backup

```bash
# Backup the named volume
docker run --rm \
  -v homeassistant_ha_config:/source:ro \
  -v ~/backups:/backup \
  alpine tar czf /backup/homeassistant-$(date +%Y%m%d).tar.gz -C /source .
```

### Important Files

Located in the volume at `/var/lib/docker/volumes/homeassistant_ha_config/_data`:
- `configuration.yaml` - Main configuration
- `automations.yaml` - Automation definitions
- `.storage/` - UI configuration, dashboards, users
- `home-assistant.log` - Logs
- `home-assistant_v2.db` - SQLite database

### Restore

```bash
docker stop homeassistant
docker volume rm homeassistant_ha_config
docker volume create homeassistant_ha_config

docker run --rm \
  -v homeassistant_ha_config:/target \
  -v ~/backups:/backup \
  alpine sh -c "tar -xzf /backup/homeassistant-YYYYMMDD.tar.gz -C /target"

docker start homeassistant
```

## Zigbee Device Management

### Verify Dongle Access

```bash
# Check device is accessible in container
docker exec homeassistant ls -la /dev/ttyUSB0

# Should show: crw-rw---- 1 root dialout
```

### If Dongle Not Detected

1. Check physical connection
2. Verify device path: `ls -la /dev/serial/by-id/`
3. Update docker-compose.yml with correct path
4. Redeploy stack

### Re-pairing Devices

If Zigbee devices need re-pairing after migration:
1. Home Assistant → Settings → Devices & Services → Zigbee Home Automation
2. Add Device → Follow pairing instructions
3. Devices should maintain their entity IDs

## Troubleshooting

### Cannot access web UI

```bash
# Check container is running
docker ps | grep homeassistant

# Check logs
docker logs homeassistant --tail 100

# Verify on caddy_net
docker inspect homeassistant | grep caddy_net
```

### Zigbee devices offline

```bash
# Check USB dongle
docker exec homeassistant ls -la /dev/ttyUSB0

# Restart container
docker restart homeassistant

# Check ZHA integration logs in HA UI
```

### Automations not working

- Check Settings → System → Logs for errors
- Verify automations are enabled
- Check entity IDs haven't changed

### Database corruption

```bash
# Restore from backup
docker stop homeassistant
# Restore volume (see backup section)
docker start homeassistant
```

## Updates

Home Assistant updates automatically when using `:stable` tag.

**To update:**
1. Portainer will auto-sync from Git (5 min)
2. Or manually: Stack → Pull and redeploy
3. Check Home Assistant → Settings → System → Updates

**Before major updates:**
- Backup configuration
- Read release notes
- Check breaking changes

## Resources

- **Official Docs:** https://www.home-assistant.io/docs/
- **Community:** https://community.home-assistant.io/
- **Integrations:** https://www.home-assistant.io/integrations/
- **ZHA Guide:** https://www.home-assistant.io/integrations/zha/
