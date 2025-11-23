#!/bin/bash
# Diagnostic script to check where files actually are vs where docker expects them

echo "=== Portainer/CONFIG_ROOT Diagnostic ==="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check CONFIG_ROOT location
echo -e "${BLUE}1. Checking CONFIG_ROOT location (/srv/configs/net_monitor):${NC}"
if [ -d "/srv/configs/net_monitor" ]; then
    echo -e "${GREEN}✓ /srv/configs/net_monitor exists${NC}"

    # Check for required subdirectories and files
    echo ""
    echo "  Checking subdirectories:"
    for dir in grafana/dashboards grafana/provisioning prometheus/rules blackbox; do
        if [ -d "/srv/configs/net_monitor/$dir" ]; then
            FILE_COUNT=$(find "/srv/configs/net_monitor/$dir" -type f | wc -l)
            echo -e "    ${GREEN}✓${NC} $dir/ ($FILE_COUNT files)"
        else
            echo -e "    ${RED}✗${NC} $dir/ (missing)"
        fi
    done

    echo ""
    echo "  Checking for new dashboard files:"
    for dashboard in network-health-overview.json service-availability-sla.json network-performance-troubleshooting.json http-service-monitoring.json; do
        if [ -f "/srv/configs/net_monitor/grafana/dashboards/$dashboard" ]; then
            echo -e "    ${GREEN}✓${NC} $dashboard"
        else
            echo -e "    ${RED}✗${NC} $dashboard (MISSING - This is the problem!)"
        fi
    done

    echo ""
    echo "  Checking alerting rules:"
    if [ -f "/srv/configs/net_monitor/prometheus/rules/network.rules.yml" ]; then
        ALERT_COUNT=$(grep -c "alert:" /srv/configs/net_monitor/prometheus/rules/network.rules.yml)
        if [ "$ALERT_COUNT" -eq 15 ]; then
            echo -e "    ${GREEN}✓${NC} network.rules.yml has $ALERT_COUNT alerts (correct)"
        else
            echo -e "    ${YELLOW}⚠${NC} network.rules.yml has $ALERT_COUNT alerts (expected 15)"
        fi
    else
        echo -e "    ${RED}✗${NC} network.rules.yml (missing)"
    fi
else
    echo -e "${RED}✗ /srv/configs/net_monitor does NOT exist${NC}"
fi

echo ""
echo -e "${BLUE}2. Checking where Portainer stores Git repos:${NC}"

# Common Portainer locations
PORTAINER_PATHS=(
    "/opt/stacks/net_monitor"
    "/data/compose/net_monitor"
    "/var/lib/docker/volumes/portainer_data/_data/compose"
)

FOUND_PORTAINER_PATH=""
for path in "${PORTAINER_PATHS[@]}"; do
    if [ -d "$path" ]; then
        echo -e "${GREEN}✓ Found Portainer path: $path${NC}"
        FOUND_PORTAINER_PATH="$path"

        # Check for files in Portainer location
        echo "  Files in Portainer location:"
        for dashboard in network-health-overview.json service-availability-sla.json network-performance-troubleshooting.json http-service-monitoring.json; do
            if [ -f "$path/grafana/dashboards/$dashboard" 2>/dev/null ]; then
                echo -e "    ${GREEN}✓${NC} $dashboard"
            else
                echo -e "    ${RED}✗${NC} $dashboard (not in Portainer path)"
            fi
        done
        break
    fi
done

if [ -z "$FOUND_PORTAINER_PATH" ]; then
    echo -e "${YELLOW}⚠ Could not find Portainer stack path in common locations${NC}"
    echo "  Try: docker inspect net_monitor-grafana-1 | grep Source"
fi

echo ""
echo -e "${BLUE}3. Checking what Docker containers actually see:${NC}"

# Check grafana container mounts
if docker ps | grep -q "grafana"; then
    GRAFANA_CONTAINER=$(docker ps --filter "name=grafana" --filter "name=net_monitor" --format "{{.Names}}" | head -1)
    echo "Grafana container: $GRAFANA_CONTAINER"

    # Get actual mount source
    MOUNT_SOURCE=$(docker inspect "$GRAFANA_CONTAINER" | grep -A 1 '/var/lib/grafana/dashboards' | grep Source | cut -d'"' -f4)

    if [ -n "$MOUNT_SOURCE" ]; then
        echo -e "${GREEN}✓ Dashboards mounted from: $MOUNT_SOURCE${NC}"

        # Check files in that location
        if [ -d "$MOUNT_SOURCE" ]; then
            DASHBOARD_COUNT=$(find "$MOUNT_SOURCE" -name "*.json" 2>/dev/null | wc -l)
            echo "  Found $DASHBOARD_COUNT dashboard files in mounted location"

            # List them
            if [ "$DASHBOARD_COUNT" -gt 0 ]; then
                find "$MOUNT_SOURCE" -name "*.json" -exec basename {} \; | sed 's/^/    - /'
            fi
        fi
    else
        echo -e "${RED}✗ Could not determine mount source${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Grafana container not running${NC}"
fi

echo ""
echo -e "${BLUE}4. Diagnosis Summary:${NC}"

# Determine the issue
if [ ! -d "/srv/configs/net_monitor/grafana/dashboards" ]; then
    echo -e "${RED}ISSUE: /srv/configs/net_monitor doesn't have the config files${NC}"
    echo ""
    echo "Your docker-compose.yml expects files at /srv/configs/net_monitor,"
    echo "but they're not there. Portainer likely pulled them elsewhere."
    echo ""
    if [ -n "$FOUND_PORTAINER_PATH" ]; then
        echo -e "${GREEN}SOLUTION: Sync files from Portainer to CONFIG_ROOT${NC}"
        echo ""
        echo "Run this command:"
        echo -e "${YELLOW}rsync -av --delete $FOUND_PORTAINER_PATH/ /srv/configs/net_monitor/${NC}"
        echo ""
        echo "Then restart: docker-compose restart grafana prometheus"
    else
        echo -e "${YELLOW}SOLUTION: Find where Portainer stored files, then sync${NC}"
        echo ""
        echo "Run: docker inspect net_monitor-grafana-1 | grep Source"
        echo "Then sync that path to /srv/configs/net_monitor/"
    fi
elif [ ! -f "/srv/configs/net_monitor/grafana/dashboards/network-health-overview.json" ]; then
    echo -e "${RED}ISSUE: Old files at /srv/configs/net_monitor, new files elsewhere${NC}"
    echo ""
    echo "You have old config files at /srv/configs/net_monitor, but Portainer"
    echo "pulled the new files (with dashboards) to a different location."
    echo ""
    if [ -n "$FOUND_PORTAINER_PATH" ]; then
        echo -e "${GREEN}SOLUTION: Sync new files from Portainer to CONFIG_ROOT${NC}"
        echo ""
        echo "Run this command:"
        echo -e "${YELLOW}rsync -av $FOUND_PORTAINER_PATH/ /srv/configs/net_monitor/${NC}"
        echo ""
        echo "Then restart: docker-compose restart grafana prometheus"
    else
        echo -e "${YELLOW}SOLUTION: Update /srv/configs/net_monitor with new files${NC}"
        echo ""
        echo "Option 1: Find Portainer location and sync"
        echo "Option 2: Clone your repo directly to /srv/configs/net_monitor"
        echo "Option 3: Change docker-compose.yml to use Portainer's location"
    fi
else
    echo -e "${GREEN}✓ Files look correct at /srv/configs/net_monitor${NC}"
    echo ""
    echo "If dashboards still don't appear, the issue is likely:"
    echo "1. Grafana needs restart: docker-compose restart grafana"
    echo "2. Permissions issue: Check file ownership"
    echo "3. Portainer environment variable: Check CONFIG_ROOT is set correctly"
fi

echo ""
echo "=== End of Diagnostic ==="
