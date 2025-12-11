# IPMI Exporter

**Purpose**: Prometheus exporter for IPMI/BMC sensor data (temperatures, voltages, fan speeds, power consumption) from Supermicro servers.

## What It Monitors

- **Temperatures**: CPU, motherboard, inlet, exhaust, peripheral zones
- **Voltages**: 12V, 5V, 3.3V, CPU VCore
- **Fan Speeds**: All fan zones (RPM)
- **Power**: System power consumption (Watts) via DCMI
- **Chassis**: Power state (on/off)
- **BMC Info**: Firmware version, uptime
- **SEL**: System Event Log summary

## Why IPMI Exporter?

- **More comprehensive than lm-sensors**: Direct BMC access to all hardware sensors
- **Remote monitoring**: Query IPMI over network (no agent needed on OS)
- **Server-grade metrics**: Power consumption, redundant PSU status, etc.
- **Historical tracking**: See trends in power, temps over time

## Architecture

- **Image**: `prometheuscommunity/ipmi-exporter:v1.8.0`
- **Port**: `9290`
- **Network**: `caddy_net` (for Prometheus scraping)
- **Authentication**: Credentials passed from Prometheus scrape params

## Prerequisites

### 1. Find IPMI Network Address

IPMI has a dedicated management port (separate from OS networking).

```bash
# On router (TP-Link Archer), check DHCP leases for:
# - Hostname: "SUPERMICRO" or similar
# - MAC: Check label on motherboard near IPMI port

# Or query from narsis OS:
sudo ipmitool lan print 1 | grep "IP Address"

# Example output:
# IP Address              : 192.168.1.100
```

### 2. Verify IPMI Credentials

From narsis setup, you reset IPMI credentials (see CLAUDE.md §2 "Media Server Boot & Access Notes").

**Test access from Almalexia:**
```bash
# Install ipmitool if needed
sudo zypper in ipmitool  # OpenSUSE

# Test connection (replace IP and credentials)
ipmitool -I lanplus -H 192.168.1.100 -U ADMIN -P 'YOUR_PASSWORD' sensor

# Should list all sensors:
# CPU Temp         | 45.000     | degrees C  | ok    | na        | ...
# System Temp      | 32.000     | degrees C  | ok    | na        | ...
# FAN1             | 1200.000   | RPM        | ok    | na        | ...
```

## Deployment

### Via Portainer (Recommended)

1. **Stacks → Add Stack → Repository**
2. **Repository URL**: `https://github.com/JakuRab/homelab-infrastructure`
3. **Compose Path**: `stacks/ipmi-exporter/docker-compose.yml`
4. **Deploy** (no environment variables needed)

### Verify Exporter

```bash
# Check exporter is running
curl http://192.168.1.11:9290/

# Should return HTML help page with /metrics endpoint info
```

## Prometheus Integration

IPMI Exporter uses a **multi-target pattern** - one exporter queries multiple BMCs.

### Option 1: Static Config (Simple)

Add to `stacks/net_monitor/prometheus/prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'ipmi'
    scrape_interval: 60s  # IPMI queries are slow, don't poll too often
    scrape_timeout: 30s
    metrics_path: /ipmi
    params:
      module: [default]
    static_configs:
      - targets:
          - 192.168.1.100  # narsis IPMI IP (adjust based on your setup)
        labels:
          instance: 'narsis'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 192.168.1.11:9290  # ipmi-exporter address

  # IPMI Authentication (use Prometheus environment or secrets)
  # Pass credentials via HTTP params or use ipmi.yml config
```

### Option 2: File-Based Discovery (Better for Multiple Servers)

Create `/mnt/nvme/services/net_monitor/prometheus/file_sd/ipmi_targets.yml`:

```yaml
- targets:
    - 192.168.1.100  # narsis IPMI
  labels:
    instance: 'narsis'
    module: 'default'
```

Then in `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'ipmi'
    scrape_interval: 60s
    scrape_timeout: 30s
    metrics_path: /ipmi
    params:
      module: [default]
    file_sd_configs:
      - files:
          - /etc/prometheus/file_sd/ipmi_targets.yml
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: ipmi-exporter:9290
```

### Credentials Configuration

**Secure method** (recommended): Use Prometheus environment variables or secrets.

For now, you can embed credentials in the exporter config or use basic auth in scrape config.

**Quick test** (less secure): Add to Prometheus scrape config:
```yaml
params:
  module: [default]
basic_auth:
  username: 'ADMIN'
  password: 'YOUR_IPMI_PASSWORD'
```

## Key Metrics

- `ipmi_temperature_celsius` - All temperature sensors
- `ipmi_fan_speed_rpm` - Fan speeds
- `ipmi_voltage_volts` - Voltage rails
- `ipmi_power_watts` - System power consumption (via DCMI)
- `ipmi_chassis_power_state` - Chassis power on/off (1 = on, 0 = off)
- `ipmi_up` - Scrape success indicator (1 = success, 0 = failed)

## Grafana Dashboards

Pre-built community dashboards:
- **IPMI Exporter Dashboard** (ID: 15067) - Temps, fans, power
- **Server Hardware Monitoring** (ID: 14364) - Combined IPMI + Node Exporter

## Troubleshooting

**IPMI exporter shows `ipmi_up{job="ipmi"} 0`?**
- Check IPMI network connectivity: `ping 192.168.1.100`
- Verify credentials with `ipmitool` (see Prerequisites above)
- Check exporter logs: `docker logs ipmi-exporter`

**Slow scrapes or timeouts?**
- IPMI queries can take 10-30 seconds
- Increase `scrape_timeout` to 30s or 45s in Prometheus config
- Reduce scrape frequency to 60s or 120s (IPMI metrics don't change rapidly)

**Missing power metrics?**
- Some BMCs don't support DCMI (power monitoring)
- Check: `ipmitool -I lanplus -H 192.168.1.100 -U ADMIN -P 'PASSWORD' dcmi power reading`
- If unsupported, power metrics won't appear (temps/fans still work)

**Authentication errors?**
- IPMI password may contain special characters that need escaping
- Test with single quotes in ipmitool: `-P 'password'`
- Update Prometheus config accordingly

## Resources

- Official Docs: https://github.com/prometheus-community/ipmi_exporter
- Default port: 9290
- IPMI protocol: Uses FreeIPMI libraries (lanplus interface)
