# Hardware Monitoring Quick Reference

**Deployed**: 2025-12-12
**Status**: ✅ Production

---

## Overview

Complete hardware monitoring for narsis using Prometheus + Grafana + 3 exporters.

### What's Monitored

- **CPU**: Temps (14 cores), usage, frequency
- **Memory**: RAM usage, swap, cache
- **Disks**: SMART health, temperatures, I/O stats
- **Network**: Interface stats, bandwidth
- **System**: Uptime, load, processes

---

## Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| **Grafana** | `https://grafana.rabalski.eu` | Dashboards & visualization |
| **Prometheus** | `https://prometheus.rabalski.eu` | Metrics database & queries |
| Node Exporter | http://192.168.1.11:9100/metrics | System metrics endpoint |
| IPMI Exporter | http://192.168.1.11:9290 | BMC sensors endpoint |
| Smartctl Exporter | http://192.168.1.11:9633/metrics | Disk SMART endpoint |

---

## Grafana Dashboards

### **Node Exporter Full** (ID: 1860)
- CPU temps and usage (all 14 cores)
- Memory and swap usage
- Disk I/O and network traffic
- System load and uptime

### **Disk Health Dashboard** (Custom)
- SMART status indicators (green/red)
- Disk temperature graphs
- Disk info table (model, serial, firmware)

**Location**: `stacks/net_monitor/grafana/dashboards/disk-health.json`

---

## Monitored Disks

| Device | Model | Size | Type | Temp | Status |
|--------|-------|------|------|------|--------|
| **sda** | SanDisk SD8SB8U128G | 128GB | SATA SSD (Boot) | ~28°C | ✅ PASSED |
| **sdb** | Vi550 S3 SSD | 1TB | SATA SSD | ~32°C | ✅ PASSED |
| **nvme0** | ADATA SX8200PNP | 480GB | NVMe M.2 | ~40°C | ✅ PASSED |

---

## Deployed Stacks

### 1. **node-exporter**
- **Port**: 9100
- **Purpose**: System & hardware metrics
- **Privileged**: No
- **Status**: ✅ Working

### 2. **smartctl-exporter**
- **Port**: 9633
- **Purpose**: Disk SMART health
- **Privileged**: Yes (runs as root for device access)
- **Status**: ✅ Working

**Important**: Must run as `user: "0:0"` to access disk devices.

### 3. **ipmi-exporter**
- **Port**: 9290
- **Purpose**: Supermicro BMC sensors
- **IPMI IP**: 192.168.1.236
- **Status**: ⏳ Needs credentials configured

---

## Prometheus Configuration

### Scrape Jobs

```yaml
# Node Exporter - 30s interval
- job_name: node-exporter
  scrape_interval: 30s
  file_sd_configs:
    - files: ['/etc/prometheus/file_sd/hardware_targets.yml']

# IPMI - 60s interval (slower, hardware queries)
- job_name: ipmi
  scrape_interval: 60s
  scrape_timeout: 30s
  metrics_path: /ipmi
  file_sd_configs:
    - files: ['/etc/prometheus/file_sd/ipmi_targets.yml']

# Smartctl - 120s interval (SMART queries are slow)
- job_name: smartctl
  scrape_interval: 120s
  scrape_timeout: 60s
  file_sd_configs:
    - files: ['/etc/prometheus/file_sd/smartctl_targets.yml']
```

### Target Files

**Location**: `/mnt/nvme/services/net_monitor/prometheus/file_sd/` on narsis

- `hardware_targets.yml` - Node Exporter targets
- `ipmi_targets.yml` - IPMI/BMC targets (192.168.1.236)
- `smartctl_targets.yml` - Smartctl targets

---

## Alert Rules

**Location**: `stacks/net_monitor/prometheus/rules/hardware.rules.yml`

### Key Alerts

- **CPUTemperatureHigh**: CPU > 80°C for 5min
- **CPUTemperatureCritical**: CPU > 90°C for 2min
- **DiskSMARTFailed**: SMART status = FAILED
- **DiskTemperatureHigh**: Disk > 60°C for 10min
- **DiskReallocatedSectorsIncreasing**: Bad sectors growing
- **SSDWearLevelHigh**: SSD > 80% lifespan used
- **FilesystemNearlyFull**: < 10% space remaining

**View alerts**: `https://prometheus.rabalski.eu/alerts`

---

## Quick Health Checks

### Check Exporter Status

```bash
# Node Exporter
curl -s http://192.168.1.11:9100/metrics | grep node_hwmon_temp_celsius | head -5

# Smartctl - Disk temps
curl -s http://192.168.1.11:9633/metrics | grep smartctl_device_temperature

# Smartctl - SMART status (should all be 1)
curl -s http://192.168.1.11:9633/metrics | grep smartctl_device_smart_status
```

### Check Prometheus Scraping

```bash
# List all targets
curl -s http://192.168.1.11:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query disk temps from Prometheus
curl -s 'http://192.168.1.11:9090/api/v1/query?query=smartctl_device_temperature' | jq '.data.result[] | {device: .metric.device, temp: .value[1]}'
```

### Check Portainer Stacks

```bash
ssh narsis
docker ps | grep -E "(node-exporter|smartctl|ipmi)"
```

---

## Troubleshooting

### Node Exporter: No temperature data?

**Solution**: Install lm-sensors on host
```bash
ssh narsis
sudo apt install lm-sensors
sudo sensors-detect  # Answer yes to all
sensors  # Verify output
docker restart node-exporter
```

### Smartctl Exporter: Permission denied errors?

**Check**: Container must run as root
```bash
docker exec smartctl-exporter whoami  # Should say "root"
docker inspect smartctl-exporter | grep '"User"'  # Should be "0:0"
```

**Fix**: Ensure `user: "0:0"` in docker-compose.yml

### IPMI Exporter: Target down?

**Check IPMI connectivity**:
```bash
# Find IPMI IP
ssh narsis
sudo ipmitool lan print 1 | grep "IP Address"

# Test IPMI access (update IP and credentials)
ipmitool -I lanplus -H 192.168.1.236 -U ADMIN -P 'PASSWORD' sensor
```

**Fix**: Configure credentials in Prometheus (not yet implemented)

### Grafana: Dashboard shows "No data"?

**Check**:
1. Datasource configured: Connections → Data sources → Prometheus
2. Test in Explore: Query `node_hwmon_temp_celsius`
3. Dashboard datasource: Edit panel → Check datasource dropdown

**Fix for custom dashboards**: Remove `"uid"` from datasource config:
```json
"datasource": {
  "type": "prometheus"
  // Remove uid line
}
```

---

## Maintenance

### Adding More Servers

1. Deploy exporters on new server
2. Update target files:
   ```bash
   ssh narsis
   sudo nano /mnt/nvme/services/net_monitor/prometheus/file_sd/hardware_targets.yml
   ```
3. Add new target:
   ```yaml
   - targets: ['192.168.1.XX:9100']
     labels:
       instance: 'server-name'
       server_type: 'role'
   ```
4. Reload Prometheus:
   ```bash
   curl -X POST http://192.168.1.11:9090/-/reload
   ```

### Updating Exporters

1. Edit docker-compose.yml with new image version
2. Commit to Git
3. Portainer → Stack → Pull and redeploy

### Backup Important Data

**Prometheus data**: `/mnt/nvme/services/net_monitor/data/prometheus` (30-day retention)
**Grafana dashboards**: Export as JSON from UI
**Alert rules**: `stacks/net_monitor/prometheus/rules/` (in Git)

---

## Useful Queries

### Prometheus (use in Grafana or Explore)

```promql
# CPU temperature (max across all cores)
max(node_hwmon_temp_celsius{chip=~".*coretemp.*"})

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk temperatures
smartctl_device_temperature{temperature_type="current"}

# Disk SMART status (1 = healthy)
smartctl_device_smart_status

# All disk info
smartctl_device

# Filesystem usage percentage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Network bandwidth (bytes/sec)
rate(node_network_receive_bytes_total[5m])
```

---

## Key Files & Locations

### On narsis Server

| Path | Purpose |
|------|---------|
| `/mnt/nvme/services/net_monitor/prometheus/prometheus.yml` | Prometheus config |
| `/mnt/nvme/services/net_monitor/prometheus/file_sd/` | Target files |
| `/mnt/nvme/services/net_monitor/prometheus/rules/` | Alert rules |
| `/mnt/nvme/services/net_monitor/data/prometheus/` | Metrics storage (30d) |
| `/mnt/nvme/services/net_monitor/data/grafana/` | Grafana database |

### In Git Repository

| Path | Purpose |
|------|---------|
| `stacks/node-exporter/` | Node Exporter stack |
| `stacks/ipmi-exporter/` | IPMI Exporter stack |
| `stacks/smartctl-exporter/` | Smartctl Exporter stack |
| `stacks/net_monitor/` | Prometheus + Grafana stack |
| `stacks/net_monitor/grafana/dashboards/` | Dashboard JSON files |
| `stacks/net_monitor/prometheus/rules/` | Alert rules (reference) |
| `MONITORING_QUICKSTART.md` | This file |
| `HARDWARE_MONITORING_DEPLOYMENT.md` | Full deployment guide |

---

## Next Steps (Optional)

### 1. Configure IPMI Exporter Credentials
- Add IPMI authentication to Prometheus
- Start monitoring BMC sensors (fans, voltages, power)

### 2. Set Up Alertmanager
- Get email/Slack notifications for alerts
- Configure alert routing and grouping

### 3. Add More Dashboards
- Import community dashboards from grafana.com
- Create custom panels for specific metrics

### 4. Monitor clockworkcity
- Deploy exporters on edge server
- Track migration to OPNsense

---

**Last Updated**: 2025-12-12
**Deployed By**: Claude Code + Kuba
**Status**: ✅ Production Ready
