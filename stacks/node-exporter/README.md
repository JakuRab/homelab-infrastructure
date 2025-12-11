# Node Exporter

**Purpose**: Prometheus exporter for hardware and OS metrics (CPU temps, disk I/O, fan speeds, network stats, filesystem usage).

## What It Monitors

- **CPU**: Usage, temperature, frequency
- **Memory**: RAM usage, swap, cache
- **Disk**: I/O stats, usage, read/write metrics
- **Network**: Interface stats (filtered to exclude Docker/Tailscale virtual interfaces)
- **Filesystem**: Mount point usage
- **Sensors**: Hardware temperatures and fan speeds (via hwmon)

## Architecture

- **Image**: `prom/node-exporter:v1.8.2`
- **Port**: `9100`
- **Network**: `caddy_net` (for Prometheus scraping)
- **Volumes**: Read-only access to `/proc`, `/sys`, and `/` (rootfs)

## Deployment

### Via Portainer (Recommended)

1. **Stacks → Add Stack → Repository**
2. **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
3. **Compose Path**: `stacks/node-exporter/docker-compose.yml`
4. **Deploy** (no environment variables needed)

### Verify

```bash
# Check metrics endpoint
curl http://192.168.1.11:9100/metrics | grep node_hwmon_temp

# Should show temperature sensors like:
# node_hwmon_temp_celsius{chip="platform_coretemp_0",sensor="temp1"} 45.0
```

## Prometheus Integration

Add to `stacks/net_monitor/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['192.168.1.11:9100']
        labels:
          instance: 'narsis'
```

Or use file-based service discovery (see main deployment guide).

## Key Metrics

- `node_hwmon_temp_celsius` - Hardware temperatures (CPU, motherboard)
- `node_hwmon_fan_rpm` - Fan speeds
- `node_disk_io_time_seconds_total` - Disk I/O activity
- `node_filesystem_avail_bytes` - Available disk space
- `node_cpu_seconds_total` - CPU usage per core
- `node_memory_MemAvailable_bytes` - Available RAM

## Grafana Dashboards

Pre-built community dashboards:
- **Node Exporter Full** (ID: 1860) - Comprehensive system overview
- **Node Exporter Server Metrics** (ID: 11074) - Detailed server stats

## Troubleshooting

**No temperature metrics?**
- Ensure `lm-sensors` is installed: `sudo apt install lm-sensors`
- Detect sensors: `sudo sensors-detect` (answer yes to all)
- Verify: `sensors` should show temperature readings

**High disk I/O noise?**
- Node Exporter reads from sysfs, minimal overhead
- If concerned, increase Prometheus scrape interval

## Resources

- Official Docs: https://github.com/prometheus/node_exporter
- Default port: 9100
