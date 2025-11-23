# Portainer Quick Fix Guide - Get Dashboards Working NOW

## 🚨 Quick Diagnosis (30 seconds)

In Portainer, click on **Containers** → **grafana container** → **Console** → **Connect**

Run this command:
```sh
ls -la /var/lib/grafana/dashboards/
```

**What you should see:**
```
network-health-overview.json
service-availability-sla.json
network-performance-troubleshooting.json
http-service-monitoring.json
network-latency-overview.json
```

### ✅ If you see 5 files:
Files are mounted correctly. Just restart Grafana:
- Containers → grafana → Restart
- Wait 30 seconds
- Check Grafana UI → Dashboards → Browse

### ❌ If you see 0-1 files:
Volume mount is wrong. Continue below...

---

## 🔧 Quick Fix Option 1: Set CONFIG_ROOT in Portainer (Easiest)

1. **In Portainer:** Stacks → net_monitor → Editor tab
2. **Scroll to "Environment variables"** section
3. **Add this variable:**
   - Name: `CONFIG_ROOT`
   - Value: The path where Portainer cloned your repo (find it below)

**Finding Portainer's clone path:**

Option A - Check container mount:
```bash
docker inspect net_monitor-grafana-1 | grep -A 5 '"Source"' | head -20
```

Look for a path like:
- `/opt/stacks/net_monitor`
- `/data/compose/1/net_monitor`
- `/var/lib/docker/volumes/portainer_data/_data/compose/1`

Option B - Common Portainer paths:
- Portainer CE: `/opt/stacks/<stack-name>`
- Portainer Business: `/data/compose/<number>/<stack-name>`

4. **Set CONFIG_ROOT to that path** (without the trailing `/grafana` or `/prometheus`)
5. **Click "Update the stack"**
6. **Check "Pull and redeploy"**
7. **Click "Update"**

---

## 🔧 Quick Fix Option 2: Switch to Relative Paths (Recommended)

This makes your stack fully portable with Portainer Git sync.

### Step 1: Update Stack in Portainer

1. **Stacks → net_monitor → Editor tab**
2. **Find these lines** (around line 31, 54, 82-83):
   ```yaml
   - "${CONFIG_ROOT:-/srv/configs/net_monitor}/prometheus:/etc/prometheus:ro"
   - "${CONFIG_ROOT:-/srv/configs/net_monitor}/blackbox:/config:ro"
   - "${CONFIG_ROOT:-/srv/configs/net_monitor}/grafana/provisioning:/etc/grafana/provisioning:ro"
   - "${CONFIG_ROOT:-/srv/configs/net_monitor}/grafana/dashboards:/var/lib/grafana/dashboards:ro"
   ```

3. **Replace with:**
   ```yaml
   - ./prometheus:/etc/prometheus:ro
   - ./blackbox:/config:ro
   - ./grafana/provisioning:/etc/grafana/provisioning:ro
   - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
   ```

4. **Click "Update the stack"**
5. **Wait for redeploy** (Portainer will recreate containers)

### Step 2: Verify

Run in grafana console:
```sh
ls /var/lib/grafana/dashboards/
```

Should now show all 5 dashboard files!

---

## 🔧 Quick Fix Option 3: Use the Portainer-Optimized Compose File

I created a version specifically for Portainer that uses relative paths.

### In Portainer:

1. **Stacks → net_monitor → Editor**
2. **Copy ALL content from `docker-compose.portainer.yml`** (in your repo)
3. **Replace the entire editor content** with the new version
4. **Click "Update the stack"**
5. **Check "Pull and redeploy"**

This version is identical but uses `./` relative paths instead of `CONFIG_ROOT`.

---

## ✅ Verification Steps

After applying any fix:

### 1. Check Grafana Dashboards (30 sec wait)

1. Open Grafana UI
2. Go to **Dashboards → Browse**
3. Look for folder: **"Network Monitoring"**
4. Should contain 5 dashboards:
   - Network Health Overview ⭐ (NEW)
   - Service Availability & SLA ⭐ (NEW)
   - Network Performance & Troubleshooting ⭐ (NEW)
   - HTTP/HTTPS Service Monitoring ⭐ (NEW)
   - Network Latency Overview (original)

### 2. Check Prometheus Alerts

1. Open Prometheus UI: `http://your-server:9090`
2. Go to **Status → Rules**
3. Look for **"blackbox-alerts"** group
4. Should show **15 alert rules**:
   - BlackboxProbeFailure
   - ServiceFlapping
   - LowServiceAvailability
   - HighRoundTripTime
   - LatencySpike
   - HighNetworkJitter
   - PacketLoss
   - SlowHTTPResponse
   - HTTPStatusCodeChanged
   - UnexpectedHTTPStatusCode
   - SSLCertificateExpiringSoon
   - SSLCertificateCritical
   - TCPConnectionFailed
   - ResponseTimeDegrading
   - MultipleServicesDown

---

## 🐛 Still Not Working?

### Check Portainer Logs

**In Portainer UI:**
1. Stacks → net_monitor → Logs
2. Look for errors about:
   - "no such file or directory"
   - "failed to mount"
   - "permission denied"

**Check individual container logs:**
1. Containers → grafana → Logs
2. Search for: "provision" or "dashboard"
3. Errors will show in red

### Verify Git Sync

1. Stacks → net_monitor
2. Check **"Last update"** timestamp - should be recent (after you pushed)
3. If old, click **Editor → Pull and redeploy**

### Manual Force Refresh

In Portainer:
1. Stacks → net_monitor
2. Click **"Stop this stack"**
3. Wait for all containers to stop
4. Click **"Editor"** tab
5. Click **"Pull and redeploy"**
6. Click **"Update the stack"**
7. Wait for deployment to complete

---

## 🎯 Expected Result

After successful deployment, you should have:

**4 New Dashboards:**
- 📊 Network Health Overview - Your daily monitoring hub
- 📈 Service Availability & SLA - Uptime tracking and SLA metrics
- 🔍 Network Performance & Troubleshooting - Deep performance analysis
- 🌐 HTTP/HTTPS Service Monitoring - Web service and SSL monitoring

**15 New Alerts:**
- Organized in categories: availability, performance, HTTP, TCP, degradation
- Will fire when issues are detected
- Visible at Prometheus → /alerts

---

## 📞 Get Help

If still not working, gather this info:

```bash
# On your server via SSH
docker ps | grep -E 'grafana|prometheus'
docker inspect net_monitor-grafana-1 | grep -A 10 Mounts
docker logs net_monitor-grafana-1 --tail 50
```

Then check:
1. Is Portainer using the correct Git branch? (should be `main`)
2. Did Portainer pull after your latest push?
3. Are volume mounts showing the correct source path?
