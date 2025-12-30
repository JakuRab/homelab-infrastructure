# Net Monitor Stack

This folder holds everything needed to deploy a lightweight network-monitoring stack (Prometheus, Grafana, Blackbox Exporter) through Portainer. Deploying the stack gives you:

- Grafana web UI (`:3000`) for dashboards.
- Prometheus web UI (`:9090`) for ad-hoc queries and troubleshooting.
- Blackbox Exporter (`:9115`) to probe LAN, WAN, and Tailscale targets over ICMP/HTTP/TCP.

> 💡 Blackbox Exporter does not ship with a full dashboard; its `/` endpoint only exposes a basic status page. Plan URL rewrites for Grafana and (optionally) Prometheus.

## Repository Layout

```
docker-compose.yml        # Portainer stack definition
prometheus/
  prometheus.yml          # Core Prometheus configuration
  rules/                  # Alerting rules
  file_sd/                # Target definition files (grouped by protocol)
blackbox/
  blackbox.yml            # Probe modules (ICMP, HTTP, TCP)
grafana/
  provisioning/           # Auto-provision datasources & dashboards
  dashboards/             # Bundled dashboard JSON
```

## Deployment (Portainer stack)

1. Copy this folder to the host running Portainer. Typically maps to `/mnt/nvme/services/net_monitor` on narsis.
2. In Portainer: *Stacks → Add stack → Upload* the `docker-compose.yml` from this folder.
3. Set these environment variables in the stack editor before deploying (or load `stack.env.example`):
   - `GF_ADMIN_USER` – Grafana admin username (default `admin`).
   - `GF_ADMIN_PASSWORD` – strong Grafana admin password.
   - `TZ` – local timezone, e.g. `Europe/Warsaw`.
   - `GRAFANA_PORT` – host port to expose Grafana (defaults to `3300` if unset).
   - `CONFIG_ROOT` – absolute path on the host containing this folder (default `/srv/configs/net_monitor`). Ensure that path holds the `prometheus`, `blackbox`, and `grafana` subdirectories before deploying.
4. Make sure the external Docker network `caddy_net` already exists (Caddy and other fronted services use it). If needed: `docker network create caddy_net`.
5. Choose the target Docker environment (usually `narsis`) and click *Deploy the stack*.
5. Expose the web UIs via Caddy/AdGuard rewrites (see below).

> The stack creates Docker bind-mounts under this folder, so keep it on a persistent filesystem (not tmpfs).

## Post-deploy tasks

- Visit Grafana (`http(s)://<host>:${GRAFANA_PORT}`; default `3300`) and log in with the credentials from step 3. You should see the preloaded *Network Latency Overview* dashboard populated after the first scrape (1–2 minutes).
- Prometheus UI is available at `http(s)://<host>:9090` for raw metrics queries.
- Confirm Blackbox exporter is reachable at `http(s)://<host>:9115` to debug probes if needed.
- Configure AdGuard/Caddy rewrites, e.g.:
  - `grafana.rabalski.eu → 192.168.1.11`
  - `prometheus.rabalski.eu → 192.168.1.11` (optional)

## Managing probe targets

- ICMP targets: edit `prometheus/file_sd/icmp_targets.yml`.
- HTTP(S) targets: edit `prometheus/file_sd/http_targets.yml`.
- TCP port checks: edit `prometheus/file_sd/tcp_targets.yml`.

Each change is picked up automatically because Prometheus watches the file SD directory; no container restarts are needed. Samples ship with LAN and Tailscale placeholders—replace or extend them to fit your environment.

## Alerting

Sample recording/alerting rules live in `prometheus/rules/network.rules.yml`:

- `BlackboxProbeFailure` fires after 3 consecutive failures (45 seconds) for any probe.
- `HighRoundTripTime` warns when probe latency stays above 250 ms for 5 minutes.

To receive notifications, integrate Alertmanager later and update the `alerting` block in `prometheus.yml`. For now, alerts appear in the Prometheus UI or Grafana’s *Alerting → Alert rules* section if you import them.

## Backup considerations

- Grafana dashboards and preferences persist in `grafana/data`.
- Prometheus data persists in `prometheus/data`. Retention is 30d by default; adjust in `docker-compose.yml` if you need longer history but ensure enough disk space.
- The configuration files themselves are canonical; add them to your regular configuration backup routine.

## Upgrades

- Update container versions in `docker-compose.yml`, then redeploy the stack in Portainer.
- Grafana and Prometheus support hot-reload endpoints; minor configuration changes (targets, rules) apply automatically without restarts.
