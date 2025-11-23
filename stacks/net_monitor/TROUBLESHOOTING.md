# Troubleshooting Guide - Network Monitor Dashboards & Alerts

## Issue: New Dashboards Not Appearing in Grafana

### Step 1: Verify Files Exist on Server

SSH to your server and run:

```bash
cd /srv/configs/net_monitor  # or your CONFIG_ROOT path
ls -la grafana/dashboards/
```

Expected files:
- `network-health-overview.json`
- `service-availability-sla.json`
- `network-performance-troubleshooting.json`
- `http-service-monitoring.json`
- `network-latency-overview.json` (original)

**If files are missing:**
```bash
git pull  # Make sure you pulled the latest changes
```

### Step 2: Check Grafana Dashboard Provisioning

```bash
cat grafana/provisioning/dashboards/dashboard.yml
```

Should contain:
```yaml
providers:
  - name: Network Dashboards
    folder: Network Monitoring
    type: file
    options:
      path: /var/lib/grafana/dashboards
```

**Key point**: The `path` should match where dashboards are mounted in the container.

### Step 3: Verify Docker Volume Mount

Check your docker-compose.yml on the server:

```bash
grep -A 2 "dashboards" docker-compose.yml
```

Should show:
```yaml
- "${CONFIG_ROOT:-/srv/configs/net_monitor}/grafana/dashboards:/var/lib/grafana/dashboards:ro"
```

**If the mount path doesn't match the provisioning config path, that's your issue!**

### Step 4: Check Container Logs

```bash
docker-compose logs grafana | grep -i dashboard
docker-compose logs grafana | grep -i provision
```

Look for errors like:
- "Failed to load dashboard"
- "Permission denied"
- "No such file or directory"

### Step 5: Restart Grafana

```bash
docker-compose restart grafana
```

Wait 30 seconds (provisioning interval is 30s), then check Grafana UI.

### Step 6: Manual Check in Container

```bash
# Enter the Grafana container
docker-compose exec grafana sh

# Check if files exist inside container
ls -la /var/lib/grafana/dashboards/

# Check provisioning config
cat /etc/grafana/provisioning/dashboards/dashboard.yml

# Exit container
exit
```

### Step 7: Check Grafana UI

1. Go to Grafana → Dashboards → Browse
2. Look for folder "Network Monitoring"
3. Check if dashboards appear there

**If folder doesn't exist:**
- Check provisioning config `folder:` value
- Restart Grafana and wait 30s

### Step 8: Check File Permissions

On the server:
```bash
ls -la grafana/dashboards/
```

Files should be readable (at least 644 permissions).

**If permission denied:**
```bash
chmod 644 grafana/dashboards/*.json
```

---

## Issue: Prometheus Alerts Not Loading

### Step 1: Verify Alert Rules File

```bash
cd /srv/configs/net_monitor  # or your CONFIG_ROOT path
cat prometheus/rules/network.rules.yml
```

Should contain 15 alerts (check with `grep -c "alert:" prometheus/rules/network.rules.yml`).

### Step 2: Validate YAML Syntax

If you have `promtool` installed:
```bash
promtool check rules prometheus/rules/network.rules.yml
```

**Online alternative:** Copy the file content and validate at https://www.yamllint.com/

### Step 3: Check Prometheus Configuration

```bash
cat prometheus/prometheus.yml | grep -A 3 rule_files
```

Should show:
```yaml
rule_files:
  - /etc/prometheus/rules/*.yml
```

### Step 4: Verify Docker Volume Mount

```bash
grep "prometheus/rules" docker-compose.yml
```

Should be part of the Prometheus volumes mount:
```yaml
- "${CONFIG_ROOT:-/srv/configs/net_monitor}/prometheus:/etc/prometheus:ro"
```

This mounts the entire `prometheus/` directory, including the `rules/` subdirectory.

### Step 5: Check Container Path

```bash
# Enter Prometheus container
docker-compose exec prometheus sh

# Check if rules file exists
ls -la /etc/prometheus/rules/

# Verify content
cat /etc/prometheus/rules/network.rules.yml

# Exit
exit
```

### Step 6: Reload Prometheus Configuration

```bash
# Option 1: API reload (if --web.enable-lifecycle is set)
curl -X POST http://localhost:9090/-/reload

# Option 2: Restart container
docker-compose restart prometheus
```

### Step 7: Check Prometheus UI

1. Go to `http://<prometheus-ip>:9090/rules`
2. Look for "blackbox-alerts" group
3. Should show all 15 alert rules

**If rules don't appear:**
- Check Prometheus logs: `docker-compose logs prometheus | grep -i rule`
- Look for YAML syntax errors
- Verify file path in container

### Step 8: Check Alert Status

Go to `http://<prometheus-ip>:9090/alerts`

You should see alerts in these states:
- **Green (Inactive)**: Rule is loaded and evaluating, but condition not met
- **Yellow (Pending)**: Condition met, waiting for `for:` duration
- **Red (Firing)**: Alert is active

**If no alerts appear at all:**
- Rules file not loaded (check logs)
- YAML syntax error
- File permissions issue

### Step 9: Test an Alert Manually

Create a test alert by stopping a monitored service, then check:

```bash
# Wait 1-2 minutes
curl http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | select(.state=="firing")'
```

---

## Common Issues & Solutions

### Issue: "Dashboard JSON is invalid"

**Cause:** JSON syntax error or incompatible Grafana version

**Solution:**
1. Validate JSON: `cat dashboard.json | jq .`
2. Check Grafana version compatibility (dashboards built for v11.2.0)
3. Try importing manually via Grafana UI to see specific error

### Issue: "Datasource not found"

**Cause:** Dashboard references datasource UID that doesn't exist

**Solution:**
1. Check datasource UID in dashboard JSON: `"uid": "prometheus-1"`
2. Check actual datasource UID in Grafana UI → Connections → Data sources
3. Update dashboard JSON if UIDs don't match, or update datasource provisioning

### Issue: "No data" in dashboard panels

**Cause:** Prometheus metrics not available or query error

**Solution:**
1. Verify Prometheus is scraping targets: `http://prometheus:9090/targets`
2. Check if metrics exist: `http://prometheus:9090/graph` and query `probe_success`
3. Verify blackbox exporter is running and accessible
4. Check time range in dashboard (default: last 6 hours)

### Issue: Alerts always "Pending" or "Inactive"

**Cause:** Query returns no data or threshold never met

**Solution:**
1. Check query in Prometheus UI: `http://prometheus:9090/graph`
2. Copy alert expression and run it
3. Verify metrics exist and match expected values
4. Adjust thresholds if needed

### Issue: File permission errors in logs

**Cause:** Container user can't read mounted files

**Solution:**
```bash
# Fix permissions
chmod -R 644 grafana/dashboards/*.json
chmod -R 644 prometheus/rules/*.yml

# Restart containers
docker-compose restart
```

### Issue: Changes not reflecting after git pull

**Cause:** Docker volume cache or container not restarted

**Solution:**
```bash
# Hard restart
docker-compose down
docker-compose up -d

# Check file timestamps
ls -la grafana/dashboards/
docker-compose exec grafana ls -la /var/lib/grafana/dashboards/
```

---

## Quick Verification Checklist

Run this verification script from the repo:

```bash
cd /path/to/repo/stacks/net_monitor
./verify-deployment.sh
```

Manual checklist:

- [ ] Latest changes pulled: `git pull`
- [ ] Dashboard JSON files exist locally
- [ ] Alert rules file updated
- [ ] Files exist on server at CONFIG_ROOT path
- [ ] Docker volumes correctly mount files
- [ ] Grafana container restarted
- [ ] Prometheus container reloaded/restarted
- [ ] Grafana logs show no errors
- [ ] Prometheus logs show no errors
- [ ] Grafana UI shows "Network Monitoring" folder
- [ ] Prometheus UI shows 15 rules in "blackbox-alerts" group
- [ ] Dashboards display data (not "No data")
- [ ] Alerts are evaluating (check /alerts page)

---

## Getting Help

If issues persist, gather this information:

```bash
# System info
docker --version
docker-compose --version

# Container status
docker-compose ps

# Recent logs
docker-compose logs --tail=100 grafana > grafana.log
docker-compose logs --tail=100 prometheus > prometheus.log

# File listing
find grafana/dashboards -type f
find prometheus/rules -type f

# Config check
cat docker-compose.yml | grep -A 10 "grafana:"
cat docker-compose.yml | grep -A 10 "prometheus:"
```

Then review the logs for specific error messages.

---

## Direct Import (Workaround)

If provisioning isn't working, you can manually import dashboards:

1. Go to Grafana UI → Dashboards → New → Import
2. Copy JSON content from dashboard file
3. Paste into "Import via panel json"
4. Click "Load"
5. Select "prometheus-1" as datasource
6. Click "Import"

Repeat for each dashboard. This is a temporary workaround - investigate why provisioning failed.

---

## Prometheus Alert Rules - Manual Add (Workaround)

If rules aren't loading via file:

1. Copy content of `network.rules.yml`
2. In Prometheus UI → Alerts → New alert rule
3. Manually create each alert

This is NOT recommended - fix the provisioning instead. Rules should load from files for GitOps.
