# Net Monitor Stack — Troubleshooting Log

This document records the end-to-end process of diagnosing and fixing a persistent `BlackboxProbeFailure` issue, which was compounded by a Portainer deployment bug and a host-level Docker DNS failure.

## Final Status (2025-11-10)

- **All systems operational.** The monitoring stack and Caddy are now fully functional.
- **Primary Root Cause (Probes):** An `Invalid HTTP version` error in Blackbox Exporter, where Caddy's `HTTP/2.0` response was not considered valid.
- **Secondary Root Cause (Deployment):** Portainer was failing to deploy updated configuration files, which prevented the primary fix from being applied. This was resolved by bypassing Portainer and deploying manually with `docker compose`.
- **Tertiary Root Cause (DNS):** Tailscale was aggressively redirecting all host-level DNS traffic (including Docker's) to its own resolver (`100.100.100.100`), which was failing for public domains. This was resolved by manually overwriting `/etc/resolv.conf` on the host.

---

## Diagnostic Timeline

1.  **Initial State:** The stack was deployed via Portainer. All probes (ICMP, TCP, HTTP) were failing. Prometheus showed `BlackboxProbeFailure` alerts for all targets, and the Grafana dashboard was empty or showed errors.

2.  **Hypothesis 1: DNS Failure in Blackbox Container.**
    - **Theory:** The `blackbox` container couldn't resolve internal `*.rabalski.eu` domains.
    - **Actions:**
        - Added `dns: 192.168.1.10` to the `blackbox` service in `docker-compose.yml`.
        - Added `extra_hosts` to the `blackbox` service to statically define all internal domains.
    - **Result:** **No change.** Probes continued to fail. This hypothesis was incorrect.

3.  **Hypothesis 2: Caddy Firewall (`gate`) Blocking Probes.**
    - **Theory:** Caddy's security gate was blocking requests from the Docker internal network.
    - **Action:** Added the Docker subnet (`172.16.0.0/12`) to the `@blocked` matcher's allowlist in the `Caddyfile`.
    - **Result:** **No change.** Caddy logs later confirmed that requests were receiving `200 OK` responses, proving the firewall was not the issue. This hypothesis was incorrect.

4.  **Hypothesis 3: TLS Certificate Validation Failure.**
    - **Theory:** The minimal Blackbox container was missing root CAs and couldn't validate the Let's Encrypt certificates.
    - **Action:** Set `insecure_skip_verify: true` in `blackbox.yml`.
    - **Result:** **No change.** This hypothesis was incorrect.

5.  **Breakthrough #1: Using the Debug Endpoint.**
    - **Action:** A manual probe was triggered using `curl` with the `&debug=true` parameter.
    - **Discovery:** The debug logs provided the true root cause of the probe failure:
      ```
      level=error msg="Invalid HTTP version number" version=HTTP/2.0
      ```
    - This revealed that Blackbox was failing because Caddy responded with `HTTP/2.0`, which was not in the `valid_http_versions` list (`["HTTP/1.1", "HTTP/2"]`).

6.  **Hypothesis 4: Fixing the HTTP Version.**
    - **Action:** Added `"HTTP/2.0"` to the `valid_http_versions` list in `blackbox.yml`.
    - **Result:** **No change.** This was the most confusing result, as it should have been the definitive fix.

7.  **Breakthrough #2: Discovering the Deployment Issue.**
    - **Action:** Re-ran the debug probe and closely inspected the `Module configuration` section of the output.
    - **Discovery:** The debug output proved that **Blackbox was still using the old configuration**. The change to `valid_http_versions` was not being applied, despite the file being correct on the host.
    - **Conclusion:** The ultimate culprit was **Portainer failing to deploy the updated config map**. It was likely using a cached or stale version of the `blackbox.yml` file.

8.  **Resolution: Bypassing Portainer.**
    - **Action:** The `net_monitor` stack was stopped completely in the Portainer UI.
    - **Action:** The stack was started manually on the server's command line:
      ```bash
      cd /srv/configs/net_monitor
      docker compose up -d
      ```
    - **Result:** **Partial Success.** All probes immediately started working, except for one: `dom.rabalski.eu`.

9.  **Final Fixes (Pre-DNS Issue):**
    - **`dom.rabalski.eu` Failure:** Corrected the `Caddyfile` to use `{remote_ip}` instead of `{remote_host}` for the `X-Forwarded-For` header on the `dom.rabalski.eu` service, making it consistent with other working services.
    - **Grafana Environment:** Realized the manual deployment would not use Portainer's environment variables. Created a `.env` file in `/srv/configs/net_monitor` to provide the necessary `GF_ADMIN_PASSWORD` and other variables for Grafana.
    - **Final Deployment:** The stack was brought down and up one last time with `docker compose down && docker compose up -d` to apply all final changes.

10. **New Problem: Docker DNS Resolution Failure (2025-11-10).**
    - **Issue:** Docker image pulls and Caddy builds started failing with `dial tcp: lookup registry-1.docker.io on 100.100.100.100:53: server misbehaving`. This indicated Docker was trying to use Tailscale's DNS, which was failing for public lookups.
    - **Diagnosis:** `resolvectl status` showed the host was using public DNS, but Docker was not.
    - **Attempted Fix 1:** Removed `dns` entry from `/etc/docker/daemon.json` to force Docker to inherit host DNS.
    - **Result 1:** Docker still attempted to use `100.100.100.100`.
    - **Attempted Fix 2:** Re-added `dns: ["1.1.1.1"]` to `/etc/docker/daemon.json` to explicitly force a public DNS.
    - **Result 2:** Docker daemon failed to start (`exit-code 1/FAILURE`).
    - **Recovery:** Removed `/etc/docker/daemon.json` entirely to allow Docker to start with default settings.

11. **Final DNS Resolution (2025-11-10).**
    - **Diagnosis:** It was determined that Tailscale was aggressively redirecting all host DNS traffic, likely via `iptables`.
    - **Attempted Fix:** `sudo tailscale set --accept-dns=false` was attempted, but Docker still failed to resolve public domains.
    - **Final Solution:** The host's DNS resolver was manually forced by overwriting `/etc/resolv.conf`:
      ```bash
      echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf
      ```
    - **Result:** This finally resolved the Docker DNS issue, allowing image pulls and builds to succeed. The stacks were then successfully brought online.

---

## Session 2: Comprehensive Monitoring Stack Revival (2025-11-16)

### Initial Problem Statement

Two critical issues were identified:
1. **Persistent `BlackboxProbeFailure` alert** for `dom.rabalski.eu`
2. **Grafana dashboard error**: `Expression plugin failed - Error loading https://grafana.rabalski.eu/.js?_cache=...`

### Investigation Phase

#### Issue #1: Home Assistant Container Not Running

**Discovery Method:**
- Used Blackbox debug endpoint: `curl 'http://localhost:9115/probe?target=https://dom.rabalski.eu&module=http_success&debug=true'`
- Probe returned `probe_http_status_code 502` (Bad Gateway)
- Docker container list showed no `homeassistant` container running

**Root Cause:** Home Assistant was completely offline, causing Caddy to return 502 when probing `dom.rabalski.eu`.

**Resolution Steps:**
1. Created correct `docker-compose.yml` for Home Assistant with proper YAML indentation
2. Deployed via Portainer UI
3. **Secondary Issue Discovered:** HA returned 400 errors due to reverse proxy misconfiguration

**Home Assistant 400 Error Fix:**
- **Symptom:** `A request from a reverse proxy was received from 172.18.0.3, but your HTTP integration is not set-up for reverse proxies`
- **Initial Attempt:** Added HA configuration for trusted proxies in `configuration.yaml`:
  ```yaml
  http:
    use_x_forwarded_for: true
    trusted_proxies:
      - 172.16.0.0/12
      - 127.0.0.1
      - ::1
  ```
- **Error Persisted:** HA logs showed `Invalid IP address in X-Forwarded-For: {remote_ip}`
- **Root Cause:** Caddy was sending the literal string `{remote_ip}` instead of the actual IP address
- **Final Fix:** Simplified Caddy configuration to use default reverse proxy behavior:
  ```caddyfile
  dom.rabalski.eu {
    import gate
    encode gzip
    reverse_proxy http://homeassistant:8123
    # Removed all manual header_up directives - Caddy handles them automatically
  }
  ```
- **Lesson Learned:** Caddy reload doesn't always pick up changes; use `docker restart caddy` for config changes

#### Issue #2: Grafana Expression Plugin Error

**Discovery:**
- Environment variable inspection: `docker exec net_monitor-grafana-1 env | grep PLUGIN`
- Found: `GF_PLUGINS_DISABLED=expressions`

**Root Cause:** The `expressions` plugin was explicitly disabled in `docker-compose.yml`, but it's a **core plugin** required for dashboard transformations and queries.

**Fix:** Removed `- GF_PLUGINS_DISABLED=expressions` from Grafana service environment variables in `docker-compose.yml`

**Deployment Challenge:** Stack needed full restart to apply changes:
```bash
cd /srv/configs/net_monitor
docker compose down && docker compose up -d
```

#### Issue #3: Grafana Datasource Not Provisioned

**Discovery:**
- Browser console error: `Datasource: -100 was not found`
- API check confirmed: `curl http://localhost:3000/api/datasources` returned empty

**Root Cause:** Datasource provisioning file had UID `"-100"` (string with negative number), which Grafana silently rejected during provisioning.

**Attempted Fixes:**
1. Verified provisioning file was mounted correctly: ✅
2. Checked file permissions inside container: ✅
3. Restarted Grafana multiple times: ❌ (datasource never appeared)

**Final Resolution:**
1. Changed datasource UID from `"-100"` to `"prometheus-1"` in `datasource.yml`
2. Updated all dashboard references to match new UID
3. Set `editable: true` to allow manual fixes if needed
4. **Manual Configuration Required:** Despite provisioning file being correct, had to manually add the datasource URL in Grafana UI:
   - Go to Connections → Data sources → Prometheus
   - Set URL: `http://prometheus:9090`
   - Save & Test: ✓ Success

**Provisioning Gotcha:** Grafana provisioned the datasource entry but left the URL field empty, requiring manual intervention.

#### Issue #4: Dashboard Queries Using Wrong Labels

**Discovery:**
- Datasource working ✓
- Explore view showed data ✓
- Dashboard showed no data ❌
- Browser console: No errors

**Investigation:**
- Tested in Explore: `probe_success` → **Data visible!**
- Dashboard query: `probe_success{module=~"icmp|http_success|tcp_connect"}` → **No data**
- Inspected actual metric labels: Only had `job` and `instance`, no `module` label

**Root Cause:** Dashboard was filtering on a `module` label that doesn't exist in the collected metrics. The Prometheus relabeling configuration uses `job` to distinguish probe types instead.

**Fix:** Replace all dashboard queries:
- `module=~"icmp|http_success|tcp_connect"` → `job=~"icmp|http|tcp"`
- `module="icmp"` → `job="icmp"`
- `module="http_success"` → `job="http"`
- `{{module}}` legend format → `{{job}}`

**Manual Update Required:** Due to Grafana dashboard provisioning behavior, the JSON updates required manual application in the UI.

### Key Learnings

1. **Caddy Configuration:**
   - Default reverse proxy behavior is often better than manual header manipulation
   - `caddy reload` is unreliable; always use `docker restart caddy` when troubleshooting
   - Caddy automatically adds proper `X-Forwarded-*` headers

2. **Grafana Provisioning:**
   - Negative number UIDs can cause silent failures
   - Use alphanumeric UIDs like `prometheus-1` instead of numeric `-100`
   - Provisioned datasources may load with empty fields requiring manual fix
   - Dashboard JSON changes require Grafana restart or manual re-import to take effect
   - The expressions plugin is **core** and cannot be safely disabled

3. **Debugging Workflow:**
   - Blackbox `&debug=true` endpoint is invaluable for diagnosing probe failures
   - Grafana Explore view is essential for validating queries before adding to dashboards
   - Check actual metric labels before writing PromQL queries
   - Browser console errors often reveal the true issue when UI shows generic errors

4. **Prometheus Metrics:**
   - File-based service discovery updates automatically (no restart needed)
   - Label schema must match between Blackbox config and dashboard queries
   - `job` vs `module` label depends on relabeling configuration

### Final Configuration Files Changed

- `configs/net_monitor/docker-compose.yml` - Removed `GF_PLUGINS_DISABLED=expressions`
- `configs/net_monitor/grafana/provisioning/datasources/datasource.yml` - Changed UID to `prometheus-1`, set `editable: true`
- `configs/net_monitor/grafana/dashboards/network-latency-overview.json` - Updated all queries from `module` to `job` labels
- `configs/net_monitor/prometheus/file_sd/http_targets.yml` - Re-enabled `dom.rabalski.eu`, added `grafana.rabalski.eu` and `prometheus.rabalski.eu`
- `configs/caddy/Caddyfile` - Simplified `dom.rabalski.eu` block to use Caddy defaults
- Created: `configs/homeassistant/docker-compose.yml` - New Home Assistant deployment

### System State After Session

- ✅ Home Assistant online and accessible at `https://dom.rabalski.eu`
- ✅ Grafana accessible, no plugin errors
- ✅ Prometheus datasource configured and tested
- ✅ All probe targets showing "UP" status
- ✅ Zero Prometheus alerts firing
- ⚠️ Dashboard queries fixed in repository, awaiting manual UI update

### Outstanding Tasks

- Manual update of dashboard queries in Grafana UI (changing `module` to `job` filters)
- Remove temporary SSH user `claude-ro` from clockworkcity
- Consider adding the monitoring stack to new server hardware when deployed

This log now serves as a complete record of the troubleshooting process.
