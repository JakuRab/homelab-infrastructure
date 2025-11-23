# Grafana Dashboard Guide

This guide explains the purpose of each dashboard and the key insights they provide for network monitoring.

## Overview

Your monitoring stack now includes 4 specialized dashboards and comprehensive alerting rules designed to help you:
- **Identify issues quickly** with at-a-glance health metrics
- **Track SLA compliance** and uptime guarantees
- **Troubleshoot performance problems** with detailed metrics
- **Monitor web services** including SSL certificates and response times
- **Get proactive alerts** before users notice problems

---

## Dashboard 1: Network Health Overview

**Purpose**: Primary dashboard for daily monitoring and quick health checks

**File**: `network-health-overview.json`

**Key Metrics**:

### At-a-Glance Stats
- **Overall Network Health**: Single percentage score showing network-wide health
- **Services Down**: Count of currently failing services (red = problem)
- **Total Monitored**: Number of endpoints being tracked
- **Avg Network Latency**: Current average latency across all ICMP probes
- **Packet Loss Detected**: Number of services with intermittent failures
- **Slowest Response**: Maximum latency across all services
- **Flapping Services**: Count of services that changed state recently (indicates instability)

### Detailed Views
- **Service Status Matrix**: Table showing each service's current status, latency, and 24h uptime
- **ICMP Latency Trends**: Graph showing ping response times over time
- **HTTP Response Time Trends**: Graph showing web service response times
- **Availability Timeline**: Visual timeline showing when services were up/down

**Best For**:
- Daily health checks
- Identifying which services are currently down
- Spotting latency trends
- Understanding service stability

**What to Look For**:
- 🔴 Red indicators in Service Status Matrix = service down
- 🟡 Yellow/orange latency values = slow responses
- 📊 Uptime % below 99% = reliability issues
- 🔄 Flapping count > 0 = unstable services

---

## Dashboard 2: Service Availability & SLA

**Purpose**: Track uptime, reliability, and service level objectives

**File**: `service-availability-sla.json`

**Key Metrics**:

### SLA Tracking
- **Service Level Objectives (SLO)**: Table showing 24h, 7d, and 30d uptime percentages
  - Green (>99.9%) = Excellent
  - Yellow (99-99.9%) = Acceptable
  - Orange (<99%) = Below target
  - Red (<95%) = Critical

### Reliability Metrics
- **Downtime Summary**: Total seconds of downtime per service in last 24h
- **Outage Incidents**: Count of state changes (flaps) per service
- **MTBF (Mean Time Between Failures)**: How long services stay up between failures
- **Reliability Score**: Composite score combining uptime + stability

### Trends
- **Uptime Trend**: Hourly uptime percentage over time
  - Helps identify patterns (e.g., "service always fails at 3 AM")

**Best For**:
- Monthly/quarterly reporting
- Identifying unreliable services
- SLA compliance verification
- Capacity planning discussions

**What to Look For**:
- Services with < 99% uptime (investigate root cause)
- High outage incident counts (unstable services)
- Low MTBF values (frequent failures)
- Downtrends in uptime graph (degrading service)

---

## Dashboard 3: Network Performance & Troubleshooting

**Purpose**: Deep dive into performance issues and network problems

**File**: `network-performance-troubleshooting.json`

**Key Metrics**:

### Latency Analysis
- **Current Latency by Target**: Bar chart showing which services are slowest RIGHT NOW
- **Latency Percentiles**: p50, p95, p99 statistics
  - p50 = median (half of requests are faster)
  - p95 = 95% of requests are faster (good for SLAs)
  - p99 = 99% of requests are faster (catches outliers)
- **Latency Spike Detection**: Highlights anomalies using 2σ statistical detection
- **Latency Trend (Rate of Change)**: Shows if latency is getting worse over time

### Network Quality
- **Network Jitter**: Latency variation (high jitter = unstable network)
- **Packet Loss Rate**: % of lost packets per target
- **Latency Statistics Table**: Min/Avg/Max/StdDev for each service
- **Latency Distribution Heatmap**: Visual pattern analysis

**Best For**:
- Diagnosing "slow network" complaints
- Finding packet loss issues
- Identifying latency spikes
- Comparing relative performance between services

**What to Look For**:
- 🔴 Latency spikes (red markers on spike detection graph)
- 📈 Upward trend in rate of change = degrading performance
- 📊 High jitter (>50ms stddev) = unstable connection
- 💥 Packet loss > 1% = network problems

**Troubleshooting Guide**:
1. Check "Current Latency" to see which service is slow
2. Look at "Latency Spike Detection" to see if it's an anomaly
3. Check "Packet Loss Rate" - if >0%, network issue likely
4. Review "Jitter" - high jitter = quality of service problem
5. Compare "Min vs Max" in statistics table - large gap = inconsistent performance

---

## Dashboard 4: HTTP/HTTPS Service Monitoring

**Purpose**: Monitor web services, SSL certificates, and HTTP-specific metrics

**File**: `http-service-monitoring.json`

**Key Metrics**:

### Service Health
- **HTTP Services Status**: Visual bar showing which web services are up/down
- **HTTP Service Details Table**: Shows for each service:
  - Status Code (200 = OK, 4xx = client error, 5xx = server error)
  - Response Time
  - SSL Certificate days until expiry
  - HTTP Version (HTTP/1.1, HTTP/2)

### Performance
- **HTTP Request Phases Duration**: Breakdown of request timing:
  - DNS resolution time
  - TCP connect time
  - TLS handshake time
  - Server processing time
  - Content transfer time
- **Average HTTP Phase Duration Distribution**: Pie chart showing where time is spent
- **HTTP Response Time Percentiles**: p50, p95, p99 for all HTTP services

### SSL/TLS Monitoring
- **SSL Certificate Expiry**: Days remaining for each certificate
  - Green (>60 days) = OK
  - Yellow (30-60 days) = Plan renewal
  - Orange (7-30 days) = Renew soon
  - Red (<7 days) = URGENT

### Diagnostics
- **Response Time Ranking**: Slowest to fastest services
- **HTTP Status Code Timeline**: Track status code changes over time

**Best For**:
- Web service health monitoring
- SSL certificate management
- Identifying slow web endpoints
- Detecting HTTP errors

**What to Look For**:
- 🔐 SSL certificates expiring in <30 days (renew them!)
- ⚠️ Status codes 4xx/5xx (application errors)
- 🐌 Response times >2 seconds (slow service)
- 📊 Large TLS handshake times (SSL/TLS performance issue)
- 🔄 Changing status codes (intermittent errors)

**Phase Duration Insights**:
- High DNS time → DNS server slow or DNS issues
- High connect time → Network/firewall issues
- High TLS time → SSL/TLS configuration problems
- High processing time → Backend application slow
- High transfer time → Large response or bandwidth issue

---

## Alerting Rules

**File**: `prometheus/rules/network.rules.yml`

### Alert Severity Levels

- **Critical**: Immediate action required (service down, SSL expiring in <7 days)
- **Warning**: Needs attention soon (high latency, packet loss, SSL <30 days)
- **Info**: FYI only (status code changes, performance degradation)

### Alert Categories

#### 1. Service Availability Alerts
- **BlackboxProbeFailure**: Service completely down for 45s
- **ServiceFlapping**: Service up/down >3 times in 10 min
- **LowServiceAvailability**: Uptime <95% in last hour
- **MultipleServicesDown**: >2 services down (network-wide issue)

#### 2. Network Performance Alerts
- **HighRoundTripTime**: ICMP latency >250ms for 5 min
- **LatencySpike**: Latency spike >2σ above average
- **HighNetworkJitter**: Jitter >50ms for 5 min
- **PacketLoss**: >1% packet loss over 5 min

#### 3. HTTP/HTTPS Alerts
- **SlowHTTPResponse**: HTTP response >2s for 3 min
- **HTTPStatusCodeChanged**: Status code changed in last 10 min
- **UnexpectedHTTPStatusCode**: Status code ≥400 for 2 min
- **SSLCertificateExpiringSoon**: Certificate expires in <30 days
- **SSLCertificateCritical**: Certificate expires in <7 days

#### 4. TCP Alerts
- **TCPConnectionFailed**: TCP connection failed for 1 min

#### 5. Degradation Alerts
- **ResponseTimeDegrading**: Response time +100ms vs 1h ago

---

## Usage Recommendations

### Daily Workflow
1. Start with **Network Health Overview** dashboard
2. Check "Services Down" and "Flapping Services" counts
3. Review Service Status Matrix for any red/yellow indicators
4. If issues found, drill down into specific dashboards

### Weekly Review
1. Open **Service Availability & SLA** dashboard
2. Review 7-day uptime percentages
3. Check MTBF and outage incidents
4. Identify services needing improvement

### When Investigating Issues
1. **"Site is slow"** → Network Performance & Troubleshooting
   - Check latency percentiles
   - Look for packet loss
   - Review jitter metrics

2. **"Website down"** → HTTP/HTTPS Service Monitoring
   - Check status codes
   - Review SSL certificate status
   - Analyze request phase durations

3. **"Intermittent failures"** → Network Health Overview
   - Look at availability timeline
   - Check flapping services count
   - Review packet loss detection

### Monthly Tasks
1. Review all SSL certificate expiry dates
2. Analyze 30-day uptime trends
3. Identify consistently slow services
4. Check for services with high incident counts
5. Review alert history and tune thresholds if needed

---

## Dashboard Access

All dashboards are located in:
```
/home/kuba/aiTools/stacks/net_monitor/grafana/dashboards/
```

Dashboard UIDs (for direct access):
- Network Health Overview: `network-health-overview`
- Service Availability & SLA: `service-availability-sla`
- Network Performance & Troubleshooting: `network-performance-troubleshooting`
- HTTP/HTTPS Service Monitoring: `http-service-monitoring`
- Original Latency Overview: `network-latency-overview`

---

## Tips for Maximum Benefit

1. **Set appropriate time ranges**:
   - Real-time monitoring: Last 1-6 hours
   - Daily review: Last 24 hours
   - Weekly review: Last 7 days
   - Trend analysis: Last 30 days

2. **Use annotations**: Service state changes are automatically annotated

3. **Leverage filters**: Click on legend items to focus on specific services

4. **Export data**: Use Grafana's export features for reports

5. **Customize thresholds**: Adjust alert thresholds based on your SLA requirements

6. **Add more targets**: Edit the file_sd YAML files to add more endpoints

---

## Common Issues and Solutions

### Issue: Dashboard shows "No Data"
**Solution**:
- Check Prometheus is scraping targets: `http://prometheus:9090/targets`
- Verify file_sd targets are correctly configured
- Ensure blackbox exporter is running

### Issue: Alerts not firing
**Solution**:
- Verify rules file syntax: `promtool check rules network.rules.yml`
- Check Prometheus rules status: `http://prometheus:9090/rules`
- Review alert thresholds (may be too high/low)

### Issue: Too many false alerts
**Solution**:
- Increase `for:` duration in alert rules
- Adjust threshold values in `expr:`
- Use longer time windows (e.g., 10m instead of 5m)

### Issue: SSL certificate alerts not working
**Solution**:
- Ensure HTTP probes are hitting HTTPS endpoints
- Verify `probe_ssl_earliest_cert_expiry` metric exists
- Check blackbox exporter has SSL module configured

---

## Next Steps

1. **Configure Alertmanager** (optional):
   - Set up email/Slack/PagerDuty notifications
   - Configure alert routing and grouping
   - Create on-call schedules

2. **Add more monitoring targets**:
   - Edit `file_sd/*.yml` files
   - Add DNS monitoring
   - Add database connection checks
   - Monitor internal services

3. **Create custom dashboards**:
   - Use these as templates
   - Combine metrics for your specific use case
   - Add business-specific KPIs

4. **Integrate with automation**:
   - Use Prometheus API to trigger remediation
   - Export metrics to logging platforms
   - Create automated reports

---

## Support and Documentation

- Prometheus Docs: https://prometheus.io/docs/
- Grafana Docs: https://grafana.com/docs/
- Blackbox Exporter: https://github.com/prometheus/blackbox_exporter
- PromQL Guide: https://prometheus.io/docs/prometheus/latest/querying/basics/

---

**Dashboard Version**: 1.0
**Created**: 2025-11-23
**Monitoring Stack**: Prometheus + Blackbox Exporter + Grafana
