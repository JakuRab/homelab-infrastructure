#!/bin/bash
# Verification script for Grafana dashboards and Prometheus alerts deployment

echo "=== Network Monitor Deployment Verification ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Determine config root
if [ -n "$CONFIG_ROOT" ]; then
    CONFIG_PATH="$CONFIG_ROOT"
else
    CONFIG_PATH="/srv/configs/net_monitor"
fi

echo "📂 Checking configuration path: $CONFIG_PATH"
echo ""

# Check if config path exists
if [ ! -d "$CONFIG_PATH" ]; then
    echo -e "${RED}✗ Configuration path does not exist: $CONFIG_PATH${NC}"
    echo "  Please set CONFIG_ROOT environment variable or check path"
    exit 1
fi

# Check Grafana dashboards
echo "📊 Grafana Dashboards:"
DASHBOARD_PATH="$CONFIG_PATH/grafana/dashboards"
if [ -d "$DASHBOARD_PATH" ]; then
    DASHBOARD_COUNT=$(find "$DASHBOARD_PATH" -name "*.json" | wc -l)
    echo -e "${GREEN}✓ Dashboard directory exists${NC}"
    echo "  Found $DASHBOARD_COUNT dashboard files:"
    find "$DASHBOARD_PATH" -name "*.json" -exec basename {} \; | sed 's/^/    - /'

    # Check for new dashboards
    echo ""
    echo "  Checking for new dashboards:"
    for dashboard in "network-health-overview.json" "service-availability-sla.json" "network-performance-troubleshooting.json" "http-service-monitoring.json"; do
        if [ -f "$DASHBOARD_PATH/$dashboard" ]; then
            echo -e "    ${GREEN}✓${NC} $dashboard"
        else
            echo -e "    ${RED}✗${NC} $dashboard (MISSING)"
        fi
    done
else
    echo -e "${RED}✗ Dashboard directory not found: $DASHBOARD_PATH${NC}"
fi

echo ""

# Check Grafana provisioning
echo "⚙️  Grafana Provisioning:"
PROV_DASH_PATH="$CONFIG_PATH/grafana/provisioning/dashboards"
if [ -d "$PROV_DASH_PATH" ]; then
    echo -e "${GREEN}✓ Provisioning directory exists${NC}"
    if [ -f "$PROV_DASH_PATH/dashboard.yml" ]; then
        echo -e "${GREEN}✓ dashboard.yml exists${NC}"
        echo "  Dashboard provisioning config:"
        grep -A 5 "path:" "$PROV_DASH_PATH/dashboard.yml" | sed 's/^/    /'
    else
        echo -e "${RED}✗ dashboard.yml not found${NC}"
    fi
else
    echo -e "${RED}✗ Provisioning directory not found: $PROV_DASH_PATH${NC}"
fi

echo ""

# Check Prometheus rules
echo "🚨 Prometheus Alert Rules:"
RULES_PATH="$CONFIG_PATH/prometheus/rules"
if [ -d "$RULES_PATH" ]; then
    echo -e "${GREEN}✓ Rules directory exists${NC}"
    RULES_COUNT=$(find "$RULES_PATH" -name "*.yml" -o -name "*.yaml" | wc -l)
    echo "  Found $RULES_COUNT rule files:"
    find "$RULES_PATH" -name "*.yml" -o -name "*.yaml" | while read rule_file; do
        ALERT_COUNT=$(grep -c "alert:" "$rule_file" 2>/dev/null || echo "0")
        echo "    - $(basename "$rule_file"): $ALERT_COUNT alerts"
    done

    # Check network.rules.yml specifically
    if [ -f "$RULES_PATH/network.rules.yml" ]; then
        echo ""
        echo "  network.rules.yml alerts:"
        grep "alert:" "$RULES_PATH/network.rules.yml" | sed 's/.*alert: /    - /' | sed 's/"//g'
    fi
else
    echo -e "${RED}✗ Rules directory not found: $RULES_PATH${NC}"
fi

echo ""

# Check Prometheus config
echo "📋 Prometheus Configuration:"
PROM_CONFIG="$CONFIG_PATH/prometheus/prometheus.yml"
if [ -f "$PROM_CONFIG" ]; then
    echo -e "${GREEN}✓ prometheus.yml exists${NC}"

    # Check if rules are loaded
    if grep -q "rule_files:" "$PROM_CONFIG"; then
        echo -e "${GREEN}✓ rule_files section found${NC}"
        echo "  Rules configuration:"
        grep -A 3 "rule_files:" "$PROM_CONFIG" | sed 's/^/    /'
    else
        echo -e "${RED}✗ rule_files section not found in prometheus.yml${NC}"
    fi
else
    echo -e "${RED}✗ prometheus.yml not found${NC}"
fi

echo ""

# Check if containers are running
echo "🐳 Docker Containers:"
if command -v docker &> /dev/null; then
    if docker ps | grep -q "prometheus"; then
        PROM_CONTAINER=$(docker ps --filter "name=prometheus" --format "{{.Names}}" | head -1)
        echo -e "${GREEN}✓ Prometheus container running: $PROM_CONTAINER${NC}"
    else
        echo -e "${YELLOW}⚠ Prometheus container not found${NC}"
    fi

    if docker ps | grep -q "grafana"; then
        GRAFANA_CONTAINER=$(docker ps --filter "name=grafana" --format "{{.Names}}" | head -1)
        echo -e "${GREEN}✓ Grafana container running: $GRAFANA_CONTAINER${NC}"
    else
        echo -e "${YELLOW}⚠ Grafana container not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Docker command not available${NC}"
fi

echo ""
echo "=== Verification Complete ==="
echo ""
echo "Next steps if issues found:"
echo "1. Ensure you pulled the latest changes: git pull"
echo "2. Check CONFIG_ROOT matches your docker-compose.yml"
echo "3. Restart services: docker-compose restart"
echo "4. Check logs: docker-compose logs grafana prometheus"
