# Hardware Monitoring Deployment Guide

**Purpose**: Deploy comprehensive hardware monitoring for your homelab servers (temperatures, disk health, fan speeds, power consumption, SMART data).

---

## Overview

This guide deploys **three new monitoring exporters** to track hardware health:

1. **Node Exporter** - CPU temps, RAM, disk I/O, fan speeds (via hwmon)
2. **IPMI Exporter** - Server BMC sensors (temps, voltages, fans, power)
3. **Smartctl Exporter** - Disk SMART health (reallocated sectors, wear, failures)

All exporters integrate with your existing **Prometheus + Grafana** stack for visualization and alerting.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       narsis (192.168.1.11)                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌────────────────┐  ┌────────────────┐  ┌──────────────┐  │
│  │ Node Exporter  │  │ IPMI Exporter  │  │   Smartctl   │  │
│  │   :9100        │  │   :9290        │  │   Exporter   │  │
│  │                │  │                │  │   :9633      │  │
│  │ • CPU temps    │  │ • BMC sensors  │  │ • SMART data │  │
│  │ • RAM usage    │  │ • Fan RPMs     │  │ • Disk temp  │  │
│  │ • Disk I/O     │  │ • Power (W)    │  │ • Bad sectors│  │
│  │ • Fan speeds   │  │ • Voltages     │  │ • SSD wear   │  │
│  └───────┬────────┘  └───────┬────────┘  └──────┬───────┘  │
│          │                   │                   │          │
│          └───────────────────┼───────────────────┘          │
│                              │                              │
│                      ┌───────▼────────┐                     │
│                      │  Prometheus    │                     │
│                      │    :9090       │                     │
│                      │                │                     │
│                      │ • Scrapes all  │                     │
│                      │   exporters    │                     │
│                      │ • Stores time  │                     │
│                      │   series data  │                     │
│                      │ • Evaluates    │                     │
│                      │   alert rules  │                     │
│                      └───────┬────────┘                     │
│                              │                              │
│                      ┌───────▼────────┐                     │
│                      │   Grafana      │                     │
│                      │    :3300       │                     │
│                      │                │                     │
│                      │ • Dashboards   │                     │
│                      │ • Graphs       │                     │
│                      │ • Alerts       │                     │
│                      └────────────────┘                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### 1. Repository Sync

Ensure your local repository is up to date:

```bash
# On Almalexia
~/homelab-docs/scripts/sync-bidirectional.sh -s
```

If remote is ahead, pull changes:

```bash
~/homelab-docs/scripts/sync-bidirectional.sh
```

### 2. Commit and Push New Stacks

The monitoring stacks are now in your repository. Commit and push:

```bash
cd ~/aiTools

# Check what's new
git status

# Add all new stacks
git add stacks/node-exporter/
git add stacks/ipmi-exporter/
git add stacks/smartctl-exporter/
git add stacks/net_monitor/prometheus/
git add stacks/net_monitor/grafana/dashboards/hardware-overview.json
git add HARDWARE_MONITORING_DEPLOYMENT.md

# Commit
git commit -m "feat(monitoring): add hardware monitoring stack (Node/IPMI/Smartctl exporters)"

# Push to GitHub
git push
```

### 3. Find IPMI IP Address (Required for IPMI Exporter)

IPMI has a separate management network interface. Find its IP:

**Option A: Check Router DHCP Leases**
- Login to TP-Link Archer (192.168.1.1)
- DHCP → DHCP Clients List
- Look for hostname "SUPERMICRO" or check MAC address (labeled on motherboard near IPMI port)

**Option B: Query from narsis**
```bash
ssh narsis
sudo ipmitool lan print 1 | grep "IP Address"

# Example output:
# IP Address              : 192.168.1.100
```

**Option C: Scan the network**
```bash
# From Almalexia
nmap -sn 192.168.1.0/24 | grep -i supermicro -B 2
```

**Test IPMI access** (replace IP and credentials):
```bash
# Install ipmitool if needed
sudo zypper in ipmitool  # OpenSUSE

# Test connection
ipmitool -I lanplus -H 192.168.1.100 -U ADMIN -P 'YOUR_PASSWORD' sensor

# Should list all sensors:
# CPU Temp         | 45.000     | degrees C  | ok    | ...
# System Temp      | 32.000     | degrees C  | ok    | ...
# FAN1             | 1200.000   | RPM        | ok    | ...
```

---

## Deployment Steps

### Step 1: Deploy Node Exporter

**What**: Exports OS and hardware metrics (CPU temp, RAM, disk, fans)

1. **Portainer → Stacks → Add Stack → Repository**
2. **Configuration**:
   - Name: `node-exporter`
   - Repository URL: `https://github.com/JakuRab/homelab-infrastructure`
   - Repository reference: `refs/heads/main`
   - Compose path: `stacks/node-exporter/docker-compose.yml`
3. **Environment variables**: None needed
4. **Deploy stack**

**Verify**:
```bash
# Check container
ssh narsis
docker ps | grep node-exporter

# Test metrics endpoint
curl http://192.168.1.11:9100/metrics | grep node_hwmon_temp

# Should show temperature sensors:
# node_hwmon_temp_celsius{chip="platform_coretemp_0",sensor="temp1"} 45.0
```

---

### Step 2: Deploy IPMI Exporter

**What**: Exports IPMI/BMC sensor data (temps, fans, power, voltages)

1. **Portainer → Stacks → Add Stack → Repository**
2. **Configuration**:
   - Name: `ipmi-exporter`
   - Repository URL: `https://github.com/JakuRab/homelab-infrastructure`
   - Repository reference: `refs/heads/main`
   - Compose path: `stacks/ipmi-exporter/docker-compose.yml`
3. **Environment variables**: None needed (credentials configured in Prometheus)
4. **Deploy stack**

**Verify**:
```bash
# Check container
ssh narsis
docker ps | grep ipmi-exporter

# Test exporter (should show help page)
curl http://192.168.1.11:9290/
```

**Update IPMI target file** (adjust IP from Prerequisites step):
```bash
# On Almalexia, edit the IPMI target file
vim ~/aiTools/stacks/net_monitor/prometheus/file_sd/ipmi_targets.yml

# Change the IP to your actual IPMI address:
- targets:
    - '192.168.1.100'  # <-- ADJUST THIS to your IPMI IP
  labels:
    job: 'ipmi'
    instance: 'narsis'
    module: 'default'
    server_type: 'media'

# Save and commit
git add stacks/net_monitor/prometheus/file_sd/ipmi_targets.yml
git commit -m "fix(monitoring): set correct IPMI IP for narsis"
git push
```

---

### Step 3: Deploy Smartctl Exporter

**What**: Exports disk SMART health metrics (reallocated sectors, temp, wear)

1. **Portainer → Stacks → Add Stack → Repository**
2. **Configuration**:
   - Name: `smartctl-exporter`
   - Repository URL: `https://github.com/JakuRab/homelab-infrastructure`
   - Repository reference: `refs/heads/main`
   - Compose path: `stacks/smartctl-exporter/docker-compose.yml`
3. **Environment variables**: None needed
4. **Deploy stack**

**Verify**:
```bash
# Check container logs for device discovery
ssh narsis
docker logs smartctl-exporter

# Should see:
# level=info msg="Device scan started"
# level=info msg="Found device: /dev/sda" type="scsi"
# level=info msg="Found device: /dev/nvme0n1" type="nvme"

# Test metrics endpoint
curl http://192.168.1.11:9633/metrics | grep smartctl_device

# Should show discovered devices:
# smartctl_device{device="/dev/sda",model_name="...",serial_number="..."} 1
```

---

### Step 4: Update Prometheus Configuration

The new scrape jobs are already added to `prometheus.yml`, but you need to reload Prometheus to apply them.

**Option A: Redeploy net_monitor stack in Portainer**
1. Go to **Portainer → Stacks → net_monitor**
2. Click **Pull and redeploy**
3. Wait for stack to restart

**Option B: Reload Prometheus config without restart**
```bash
ssh narsis
docker exec prometheus kill -HUP 1

# Or use the web API
curl -X POST http://192.168.1.11:9090/-/reload
```

**Verify Prometheus is scraping**:
1. Open Prometheus web UI: `https://prometheus.rabalski.eu`
2. **Status → Targets**
3. You should see three new job groups:
   - `node-exporter` - Should be **UP** (green)
   - `ipmi` - Should be **UP** if IPMI credentials are correct
   - `smartctl` - Should be **UP** (green)

**If IPMI target is DOWN**:
- Check IPMI IP is correct in `ipmi_targets.yml`
- Verify IPMI credentials work (see Prerequisites)
- For now, IPMI exporter doesn't have auth configured - we'll add that next

---

### Step 5: Configure IPMI Authentication

IPMI Exporter needs credentials to query the BMC. There are two approaches:

**Option A: Environment Variables in Prometheus** (Recommended)

1. **Edit net_monitor stack in Portainer**:
   - Stacks → net_monitor → Editor
   - Add environment variables to Prometheus service:

```yaml
services:
  prometheus:
    # ... existing config ...
    environment:
      - TZ=${TZ:-Etc/UTC}
      - IPMI_USER=ADMIN          # <-- Add this
      - IPMI_PASSWORD=YOUR_PASSWORD_HERE  # <-- Add this (use strong password from setup)
```

2. **Redeploy stack**

**Option B: Basic Auth in Prometheus Scrape Config** (Less secure, quick test)

Edit `stacks/net_monitor/prometheus/prometheus.yml`:

```yaml
  - job_name: ipmi
    # ... existing config ...
    basic_auth:
      username: 'ADMIN'
      password: 'YOUR_IPMI_PASSWORD'
```

Then reload Prometheus (Step 4).

**Verify IPMI scraping**:
```bash
# Check Prometheus logs
ssh narsis
docker logs prometheus --since 2m | grep ipmi

# Query IPMI metrics in Prometheus UI
# Status → Targets → ipmi should be UP
# Graph tab, query: ipmi_temperature_celsius
```

---

### Step 6: Import Grafana Dashboard

1. **Login to Grafana**: `https://grafana.rabalski.eu`
2. **Dashboards → Import**
3. **Option A - Import from file**:
   - Click "Upload JSON file"
   - Select: `stacks/net_monitor/grafana/dashboards/hardware-overview.json`
   - Select datasource: `Prometheus`
   - Click "Import"

4. **Option B - Import community dashboards** (optional, for more detail):
   - Dashboard ID **1860** - Node Exporter Full
   - Dashboard ID **10530** - SMART Disk Monitoring
   - Dashboard ID **15067** - IPMI Exporter Dashboard

**What you should see**:
- **Hardware Overview** dashboard with:
  - CPU Temperature gauge
  - SMART Status indicator
  - Memory and CPU usage gauges
  - Temperature graphs (CPU cores, disks)
  - Disk health summary table

---

## Post-Deployment Verification

### Check All Exporters Are Running

```bash
ssh narsis

# List all monitoring containers
docker ps | grep -E "(node-exporter|ipmi-exporter|smartctl-exporter|prometheus|grafana)"

# Should show 5 containers running
```

### Test Metrics Collection

```bash
# Node Exporter - CPU temps
curl -s http://192.168.1.11:9100/metrics | grep node_hwmon_temp_celsius

# IPMI Exporter - All sensors (requires IPMI setup)
curl -s "http://192.168.1.11:9290/ipmi?target=192.168.1.100&module=default" | grep ipmi_temperature

# Smartctl Exporter - Disk health
curl -s http://192.168.1.11:9633/metrics | grep smartctl_device_smart_status
```

### Check Prometheus Targets

1. Open `https://prometheus.rabalski.eu`
2. **Status → Targets**
3. All targets should be **UP** (green):
   - `node-exporter (1/1 up)`
   - `ipmi (1/1 up)` - if credentials configured
   - `smartctl (1/1 up)`

### View Grafana Dashboard

1. Open `https://grafana.rabalski.eu`
2. **Dashboards → Hardware Overview**
3. Select instance: `narsis`
4. You should see:
   - Live CPU temperature
   - Disk SMART status (PASSED/FAILED)
   - Memory and CPU usage
   - Temperature trends over time

---

## Setting Up Alerts

Alert rules are already configured in `stacks/net_monitor/prometheus/rules/hardware.rules.yml`.

**To activate alerts**:

1. **Ensure rule file is loaded**:
   - Prometheus mounts `/etc/prometheus/rules/*.yml`
   - The new `hardware.rules.yml` should be auto-discovered

2. **Verify rules are loaded**:
   - Prometheus UI: `https://prometheus.rabalski.eu`
   - **Status → Rules**
   - Look for `hardware_health` group with rules like:
     - `CPUTemperatureHigh`
     - `DiskSMARTFailed`
     - `FilesystemNearlyFull`

3. **Configure Alertmanager** (future step):
   - For now, alerts fire but aren't sent anywhere
   - You can view firing alerts: **Alerts** tab in Prometheus
   - To get notifications (email, Slack, etc.), deploy Alertmanager

**Test an alert**:
```bash
# Check current CPU temp
curl -s http://192.168.1.11:9100/metrics | grep 'node_hwmon_temp_celsius{chip=~".*coretemp.*"}'

# If all temps are low, simulate high temp by querying Prometheus:
# Prometheus UI → Alerts → should show which rules are pending/firing
```

---

## Troubleshooting

### Node Exporter: No temperature metrics?

```bash
# On narsis, ensure lm-sensors is installed
ssh narsis
sudo apt update && sudo apt install lm-sensors

# Detect sensors
sudo sensors-detect
# Answer "yes" to all prompts

# Verify sensors work
sensors

# Should show:
# coretemp-isa-0000
# Adapter: ISA adapter
# Core 0:       +45.0°C  ...

# Restart node-exporter
docker restart node-exporter
```

### IPMI Exporter: Target always DOWN?

**Common issues**:

1. **Wrong IPMI IP**:
   - Double-check IP in `ipmi_targets.yml`
   - Ping the IPMI IP: `ping 192.168.1.100`

2. **Wrong credentials**:
   - Test with ipmitool: `ipmitool -I lanplus -H 192.168.1.100 -U ADMIN -P 'PASSWORD' sensor`
   - If fails, reset IPMI password via IPMI web UI or clear CMOS

3. **No credentials configured**:
   - IPMI exporter needs auth (see Step 5)
   - Check Prometheus scrape config has `basic_auth` or environment variables

4. **Network/firewall**:
   - IPMI uses port 623/UDP (IPMI over LAN)
   - Ensure no firewall blocking between narsis and IPMI network

**Check IPMI exporter logs**:
```bash
docker logs ipmi-exporter
# Look for auth errors or connection timeouts
```

### Smartctl Exporter: No disks detected?

**Check container can see devices**:
```bash
ssh narsis
docker exec smartctl-exporter ls -la /dev/sd* /dev/nvme*

# Should list your drives
```

**If empty**:
- Container needs `/dev:/dev:ro` mount (already in docker-compose.yml)
- Check capabilities: `docker inspect smartctl-exporter | grep -A5 CapAdd`
- Should have `SYS_RAWIO` and `SYS_ADMIN`

**HBA-connected drives**:
- Verify HBA is in IT mode (not RAID): `sudo lsscsi`
- Test SMART access: `sudo smartctl -a /dev/sda`
- Some SAS drives may not support SMART

### Prometheus: Scrapes timing out?

**For IPMI and Smartctl, queries can be slow**:

Edit `prometheus.yml` scrape configs:
```yaml
  - job_name: ipmi
    scrape_interval: 120s  # Increase to 2 minutes
    scrape_timeout: 60s    # Increase timeout

  - job_name: smartctl
    scrape_interval: 300s  # Increase to 5 minutes
    scrape_timeout: 120s   # Increase timeout (24 drives takes time)
```

### Grafana: Dashboard shows "No data"?

1. **Check Prometheus datasource**:
   - Grafana → Configuration → Data Sources → Prometheus
   - URL should be: `http://prometheus:9090`
   - Click "Test" - should succeed

2. **Check metrics exist**:
   - Prometheus UI → Graph
   - Query: `node_hwmon_temp_celsius`
   - Should return data

3. **Check dashboard time range**:
   - If exporters just started, need time to collect data
   - Change time range to "Last 5 minutes"

---

## Maintenance

### Adding More Servers

To monitor clockworkcity (or other servers):

1. **Deploy exporters on the new server**:
   - Follow Steps 1-3 for each server
   - Adjust ports if running multiple on same host

2. **Add to Prometheus targets**:
   - Edit `hardware_targets.yml`:
     ```yaml
     - targets:
         - '192.168.1.10:9100'  # clockworkcity
       labels:
         instance: 'clockworkcity'
         server_type: 'edge'
     ```
   - Edit `ipmi_targets.yml` (if server has IPMI)
   - Edit `smartctl_targets.yml`

3. **Reload Prometheus**:
   ```bash
   docker exec prometheus kill -HUP 1
   ```

### Updating Exporters

Exporters update automatically when you change image tags and redeploy:

1. Edit `docker-compose.yml` with new version
2. Commit and push
3. Portainer → Pull and redeploy

### Backup Important Data

**What to backup**:
- Prometheus data: `/mnt/nvme/services/net_monitor/data/prometheus`
- Grafana dashboards: `/mnt/nvme/services/net_monitor/data/grafana`
- Grafana config: Exported as JSON from UI

**Quick backup**:
```bash
ssh narsis
sudo rsync -avH /mnt/nvme/services/net_monitor/data/ /path/to/backup/
```

---

## Next Steps

**Immediate**:
1. Deploy all three exporters
2. Verify metrics in Prometheus
3. Import Grafana dashboards
4. Check alerts are loading

**Future Enhancements**:
1. **Deploy Alertmanager**:
   - Get email/Slack notifications for critical alerts
   - Configure routing for different severity levels

2. **Add more dashboards**:
   - Import community dashboards for detailed views
   - Create custom panels for your specific hardware

3. **Expand monitoring**:
   - Monitor Docker containers with cAdvisor
   - Add custom exporters for specific services
   - Monitor network switches/routers (SNMP exporter)

4. **Monitor clockworkcity**:
   - Deploy same exporters on edge server
   - Track migration to OPNsense router

---

## Reference Links

**Stack Documentation**:
- Node Exporter: `stacks/node-exporter/README.md`
- IPMI Exporter: `stacks/ipmi-exporter/README.md`
- Smartctl Exporter: `stacks/smartctl-exporter/README.md`

**Upstream Documentation**:
- Node Exporter: https://github.com/prometheus/node_exporter
- IPMI Exporter: https://github.com/prometheus-community/ipmi_exporter
- Smartctl Exporter: https://github.com/prometheus-community/smartctl_exporter
- Prometheus: https://prometheus.io/docs/
- Grafana: https://grafana.com/docs/

**Grafana Dashboard IDs** (import via ID):
- 1860 - Node Exporter Full
- 10530 - SMART Disk Monitoring
- 15067 - IPMI Exporter Dashboard
- 11074 - Node Exporter Server Metrics

---

## Summary

You now have comprehensive hardware monitoring with:
- ✅ CPU, RAM, disk, network metrics (Node Exporter)
- ✅ Server temperatures, fans, power, voltages (IPMI Exporter)
- ✅ Disk SMART health and failure prediction (Smartctl Exporter)
- ✅ Historical data and trending (Prometheus)
- ✅ Visual dashboards (Grafana)
- ✅ Alerting rules for critical issues

All deployed via **Portainer GitOps** for easy management!

**Questions or issues?** Check the individual stack READMEs or the Troubleshooting section above.
