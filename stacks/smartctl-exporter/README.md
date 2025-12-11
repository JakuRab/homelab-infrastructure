# Smartctl Exporter

**Purpose**: Prometheus exporter for disk SMART health metrics (temperature, reallocated sectors, power-on hours, wear leveling, predictive failure warnings).

## What It Monitors

### For All Drives (HDD/SSD/NVMe):
- **Temperature**: Current disk temperature
- **Power-on Hours**: Total operating time
- **Power Cycles**: Number of start/stop cycles
- **SMART Status**: Overall health (PASSED/FAILED)
- **Critical Warnings**: Predictive failure indicators

### HDD-Specific:
- **Reallocated Sectors**: Bad sectors remapped (early failure sign)
- **Pending Sectors**: Sectors waiting for reallocation
- **Uncorrectable Errors**: Read errors that couldn't be fixed
- **Seek Error Rate**: Head positioning errors
- **Spin Retry Count**: Failed spin-up attempts

### SSD/NVMe-Specific:
- **Wear Leveling**: Flash cell wear percentage
- **Available Spare**: Reserved blocks remaining
- **Percentage Used**: Drive lifespan consumed
- **Data Units Written/Read**: Total I/O volume
- **Media Errors**: Flash read/write failures

## Why Smartctl Exporter?

- **Predictive failure detection**: Catch failing drives before data loss
- **Capacity planning**: Track wear on SSDs, know when to replace
- **Temperature monitoring**: Prevent thermal damage
- **Historical trends**: See degradation over time (reallocated sectors increasing = failing drive)

## Architecture

- **Image**: `prometheuscommunity/smartctl-exporter:v0.12.0`
- **Port**: `9633`
- **Privileges**: Requires `SYS_RAWIO` and `SYS_ADMIN` capabilities to access `/dev/` devices
- **Device Access**: Read-only bind mount of `/dev` to scan all drives
- **Network**: `caddy_net` (for Prometheus scraping)

## Monitored Drives on narsis

Based on your hardware (CLAUDE.md §2):
- **SATA SSD** (120GB boot drive, caddy bay #1 via HBA)
- **NVMe SSD** (480GB M.2, PCIe adapter)
- **Future**: 24× 2.5" hot-swap drives (when populated)

## Deployment

### Via Portainer (Recommended)

1. **Stacks → Add Stack → Repository**
2. **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
3. **Compose Path**: `stacks/smartctl-exporter/docker-compose.yml`
4. **Deploy** (no environment variables needed)

### Verify

```bash
# Check exporter is running
docker logs smartctl-exporter

# Should see device discovery:
# level=info msg="Device scan started"
# level=info msg="Found device: /dev/sda" type="scsi"
# level=info msg="Found device: /dev/nvme0n1" type="nvme"

# Check metrics endpoint
curl http://192.168.1.11:9633/metrics | grep smartctl_device

# Should show discovered devices:
# smartctl_device{device="/dev/sda",model_name="...",serial_number="..."} 1
# smartctl_device{device="/dev/nvme0n1",model_name="...",serial_number="..."} 1
```

## Prometheus Integration

Add to `stacks/net_monitor/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'smartctl'
    scrape_interval: 120s  # SMART queries can be slow, poll every 2 minutes
    scrape_timeout: 60s    # Allow time for multi-disk queries
    static_configs:
      - targets: ['192.168.1.11:9633']
        labels:
          instance: 'narsis'
```

Or use file-based service discovery (see main deployment guide).

## Key Metrics

### Health Overview
- `smartctl_device_smart_status` - Overall SMART health (1 = PASSED, 0 = FAILED)
- `smartctl_device_temperature` - Current disk temperature (°C)
- `smartctl_device_power_on_seconds` - Total power-on time (divide by 3600 for hours)

### Critical Failure Indicators (HDD)
- `smartctl_device_reallocated_sector_count` - Bad sectors remapped (>0 = concern, increasing = failing)
- `smartctl_device_current_pending_sector_count` - Sectors waiting for reallocation (>0 = active issues)
- `smartctl_device_offline_uncorrectable` - Unrecoverable read errors (>0 = data at risk)

### SSD/NVMe Wear
- `smartctl_device_percentage_used` - Drive lifespan consumed (0-100%, replace at ~90%)
- `smartctl_device_available_spare` - Reserved spare blocks (should stay >10%)
- `smartctl_device_media_errors` - Flash errors (increasing = failing SSD)

### Operational Stats
- `smartctl_device_power_cycle_count` - Number of power cycles
- `smartctl_device_data_units_written` - Total writes (NVMe) - helps estimate remaining life
- `smartctl_device_data_units_read` - Total reads (NVMe)

## Alerting Examples

Add to `stacks/net_monitor/prometheus/rules/disk_health.rules.yml`:

```yaml
groups:
  - name: disk_health
    interval: 60s
    rules:
      - alert: DiskSMARTFailed
        expr: smartctl_device_smart_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "SMART health check failed on {{ $labels.device }}"
          description: "Drive {{ $labels.device }} ({{ $labels.model_name }}) has failed SMART status. Replace immediately!"

      - alert: DiskReallocatedSectorsIncreasing
        expr: increase(smartctl_device_reallocated_sector_count[24h]) > 0
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "Reallocated sectors increasing on {{ $labels.device }}"
          description: "Drive {{ $labels.device }} has reallocated {{ $value }} sectors in the last 24h. Drive may be failing."

      - alert: DiskTemperatureHigh
        expr: smartctl_device_temperature > 60
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High disk temperature on {{ $labels.device }}"
          description: "Drive {{ $labels.device }} temperature is {{ $value }}°C (threshold: 60°C). Check cooling."

      - alert: SSDWearLevelHigh
        expr: smartctl_device_percentage_used > 80
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "SSD wear level high on {{ $labels.device }}"
          description: "SSD {{ $labels.device }} has consumed {{ $value }}% of its lifespan. Plan replacement."
```

## Grafana Dashboards

Pre-built community dashboards:
- **SMART Disk Monitoring** (ID: 10530) - Overview of all disks
- **Disk Health Dashboard** (ID: 14055) - Detailed SMART attributes

Or create custom dashboard with panels:
1. **SMART Status Gauge** - Green/red health indicator
2. **Temperature Graph** - All drives over time
3. **Reallocated Sectors Table** - Show any drives with bad sectors
4. **Power-on Hours Bar Chart** - Drive age comparison
5. **SSD Wear Level** - Percentage used for SSDs

## Troubleshooting

**No devices detected?**
- Check container logs: `docker logs smartctl-exporter`
- Verify devices visible: `docker exec smartctl-exporter ls -la /dev/sd* /dev/nvme*`
- Some drives behind HBA/RAID controllers may not expose SMART data (check HBA is in IT mode, not RAID mode)

**Drives behind LSI HBA not showing?**
- Your narsis uses LSI SAS3008 in IT mode (good - SMART should work)
- Verify: `sudo smartctl -a /dev/sda` shows SMART data
- If not, HBA firmware may need update or SAS drives may not support SMART (check drive specs)

**NVMe not detected?**
- NVMe on PCIe adapter should work
- Verify: `sudo smartctl -a /dev/nvme0n1` shows data
- Check kernel support: `lsmod | grep nvme`

**High scrape time or timeouts?**
- SMART queries can take 10-30 seconds per drive
- With 24 drives, could take several minutes
- Increase `scrape_timeout` to 120s or higher
- Reduce `scrape_interval` to 300s (5 minutes) or more

**Permission errors?**
- Container needs `SYS_RAWIO` capability (already in compose file)
- Verify capabilities: `docker inspect smartctl-exporter | grep -A5 CapAdd`

## Resources

- Official Docs: https://github.com/prometheus-community/smartctl_exporter
- Default port: 9633
- SMART attributes reference: https://en.wikipedia.org/wiki/S.M.A.R.T.
