# Deploying Dashboards via Portainer Git Sync

## Understanding Portainer Git Sync

When Portainer manages your stack via Git:
1. It clones/pulls your repo to a specific location on the host
2. It only uses files **within the stack's compose directory**
3. External file references (like volume mounts) may not work as expected

## The Problem

Your `docker-compose.yml` references files using `${CONFIG_ROOT}`:

```yaml
volumes:
  - "${CONFIG_ROOT:-/srv/configs/net_monitor}/grafana/dashboards:/var/lib/grafana/dashboards:ro"
  - "${CONFIG_ROOT:-/srv/configs/net_monitor}/prometheus:/etc/prometheus:ro"
```

**Issue:** When Portainer pulls your repo, these files aren't at `/srv/configs/net_monitor` - they're in Portainer's git clone location (usually `/opt/portainer/...` or similar).

## Solution Options

### Option 1: Use Relative Paths (Recommended for Portainer)

Modify your `docker-compose.yml` to use relative paths that work with Portainer's Git sync:

```yaml
volumes:
  - "./grafana/dashboards:/var/lib/grafana/dashboards:ro"
  - "./grafana/provisioning:/etc/grafana/provisioning:ro"
  - "./prometheus:/etc/prometheus:ro"
```

This way, Portainer will mount files relative to the stack directory.

### Option 2: Check Portainer's Stack Environment Variables

In Portainer:
1. Go to your stack
2. Click "Edit stack"
3. Check "Environment variables" section
4. Look for `CONFIG_ROOT` - is it set correctly?

If not set, Portainer is using the default `/srv/configs/net_monitor`, but the files might not be there.

### Option 3: Manual File Sync to Server

Keep using `CONFIG_ROOT` but manually sync files:

```bash
# SSH to your server
ssh your-server

# Copy files from Portainer's git location to CONFIG_ROOT
PORTAINER_STACK_PATH="/opt/stacks/net_monitor"  # Adjust this
CONFIG_ROOT="/srv/configs/net_monitor"

# Sync the files
rsync -av "$PORTAINER_STACK_PATH/grafana/" "$CONFIG_ROOT/grafana/"
rsync -av "$PORTAINER_STACK_PATH/prometheus/" "$CONFIG_ROOT/prometheus/"

# Restart stack
cd "$PORTAINER_STACK_PATH"
docker-compose restart grafana prometheus
```

## Recommended Approach for Portainer

### Step 1: Restructure for Portainer Git Sync

Update your `docker-compose.yml`:

```yaml
services:
  grafana:
    # ... other config ...
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - ./grafana/dashboards:/var/lib/grafana/dashboards:ro
    # ... rest of config ...

  prometheus:
    # ... other config ...
    volumes:
      - ./prometheus:/etc/prometheus:ro
      - prometheus_data:/prometheus
    # ... rest of config ...
```

This ensures all config files are loaded from the Git repo directly.

### Step 2: Verify File Structure

Your Git repo should have this structure:
```
stacks/net_monitor/
├── docker-compose.yml
├── grafana/
│   ├── dashboards/
│   │   ├── network-health-overview.json
│   │   ├── service-availability-sla.json
│   │   ├── network-performance-troubleshooting.json
│   │   ├── http-service-monitoring.json
│   │   └── network-latency-overview.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboard.yml
│       └── datasources/
│           └── datasource.yml
├── prometheus/
│   ├── prometheus.yml
│   ├── rules/
│   │   └── network.rules.yml
│   └── file_sd/
│       ├── icmp_targets.yml
│       ├── http_targets.yml
│       └── tcp_targets.yml
└── blackbox/
    └── blackbox.yml
```

### Step 3: Update Portainer Stack

1. **In Portainer UI:**
   - Stacks → your net_monitor stack
   - Click "Edit stack"
   - Click "Pull and redeploy"
   - Check "Re-pull image and redeploy"
   - Click "Update"

2. **Wait for Portainer to:**
   - Pull latest Git changes
   - Rebuild/restart containers

3. **Check logs:**
   - In Portainer, click your stack
   - Click on "grafana" container → Logs
   - Look for provisioning messages
   - Click on "prometheus" container → Logs
   - Look for rules loading messages

## Debugging in Portainer

### Check What Portainer Actually Pulled

1. In Portainer, go to your stack
2. Look at "Build method" - should show "Git repository"
3. Check "Repository URL" and "Repository reference" (branch)
4. Note the last "Last update" timestamp

### Inspect Container Mounts

1. In Portainer: Containers → grafana → Details
2. Scroll to "Mounts" section
3. Verify you see:
   - Source: `/opt/stacks/net_monitor/grafana/dashboards` (or similar Portainer path)
   - Destination: `/var/lib/grafana/dashboards`

### Check Files Inside Container

1. In Portainer: Containers → grafana → Console
2. Click "Connect"
3. Run:
   ```sh
   ls -la /var/lib/grafana/dashboards/
   cat /etc/grafana/provisioning/dashboards/dashboard.yml
   ```

If files aren't there, Portainer didn't mount them correctly.

## Current Issue Diagnosis

Based on your situation, the most likely issues are:

### 1. CONFIG_ROOT Points to Non-Existent Path
**Check:** In Portainer stack environment variables, is `CONFIG_ROOT` set?

**Fix:** Either:
- Set `CONFIG_ROOT` to where Portainer clones the repo
- OR switch to relative paths in docker-compose.yml

### 2. Portainer Didn't Actually Pull Latest Changes
**Check:** In Portainer, look at stack's "Last update" timestamp

**Fix:**
- Manually click "Pull and redeploy"
- Or check Portainer's Git credentials/access

### 3. Files Are Mounted But Containers Not Restarted
**Check:** Container uptime vs. last git pull time

**Fix:**
- In Portainer, restart the stack
- Or enable "Automatic updates" with a webhook

## Immediate Actions

Run these steps in Portainer UI:

1. **Verify Git Sync Worked:**
   - Stacks → net_monitor
   - Check "Last update" time - should be recent
   - Check "Repository reference" - should be `main` (or your branch)

2. **Force Pull:**
   - Click "Editor" tab
   - Scroll down and click "Pull and redeploy"
   - Enable "Re-pull image and redeploy" if needed

3. **Check Container Paths:**
   - Containers → grafana → Console → Connect
   - Run: `ls /var/lib/grafana/dashboards/`
   - Should list 5 JSON files

4. **Check Prometheus Rules:**
   - Containers → prometheus → Console → Connect
   - Run: `cat /etc/prometheus/rules/network.rules.yml | grep -c alert:`
   - Should output: 15

5. **Restart Services:**
   - Containers → grafana → Restart
   - Containers → prometheus → Restart
   - Wait 1 minute

6. **Verify in UI:**
   - Open Grafana
   - Check Dashboards → Browse → "Network Monitoring" folder
   - Open Prometheus
   - Go to Status → Rules
   - Should see "blackbox-alerts" group with 15 rules

## Alternative: Use Portainer's Built-in Git Webhook

Set up automatic deployment:

1. In Portainer: Stacks → net_monitor → Webhook
2. Copy webhook URL
3. In GitHub: Repository → Settings → Webhooks → Add webhook
4. Paste Portainer webhook URL
5. Set to trigger on "push" events
6. Now every git push auto-deploys to Portainer!

## Quick Fix Script for Server

If using CONFIG_ROOT approach, run this on your server:

```bash
#!/bin/bash
# Sync Portainer Git repo to CONFIG_ROOT

PORTAINER_PATH="/opt/stacks/net_monitor"  # Adjust based on your Portainer config
CONFIG_ROOT="/srv/configs/net_monitor"

# Find Portainer's actual stack path
# Usually under /opt/stacks or /data/stacks or similar
# Check: docker inspect <container> | grep Source

echo "Syncing files from Portainer Git to CONFIG_ROOT..."
rsync -av --delete "$PORTAINER_PATH/" "$CONFIG_ROOT/"

echo "Restarting containers..."
docker restart net_monitor-grafana-1 net_monitor-prometheus-1

echo "Done! Check Grafana in 30 seconds."
```

## Need Help?

Provide these details:
1. Portainer version
2. Stack "Last update" timestamp
3. Environment variables set in Portainer for this stack
4. Output of: `docker inspect net_monitor-grafana-1 | grep -A 10 Mounts`
