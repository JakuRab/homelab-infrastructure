# Setting up Caddy with Cloudflare DNS-01 (2025-11-03)

## Context
- Goal: run Caddy with the Cloudflare DNS provider so `n8n.rabalski.eu` gets a public TLS cert without manual renewals.
- Constraints: work within existing `configs/caddy` tree, deploy via `sync_to_server.sh`, avoid hand-editing server files.

## What happened
1. **xcaddy build failures** – building from the repo Dockerfile pulled Caddy 2.8.4 but the upstream zap module lacked the new `zapslog.HandlerOptions`. Pinning various zap versions and using `go.uber.org/zap@master` still failed because the build sandbox could not reach Go’s proxy reliably.
2. **Prebuilt image detours** – switching to `ghcr.io/caddy-dns/cloudflare` required GHCR auth and the tagged manifest (`2.8.4`) was unavailable, so `docker compose pull` kept returning `manifest unknown`.
3. **Direct binary download** – the final approach downloads the official Caddy binary bundle (`caddyserver.com/api/download?...&p=github.com/caddy-dns/cloudflare`) inside the Docker build and layers it over `caddy:2.8.4`. This bypasses Go module builds entirely and ships with the DNS plugin ready to go.
4. **Compose workflow refresh** – `docker-compose.yml` now builds that binary-backed image (tagged `caddy-cloudflare:2.8.4`) and mirrors `CF_API_TOKEN` into `CLOUDFLARE_API_TOKEN`. `sync_to_server.sh` was updated to run `docker compose build --pull --no-cache` before `up` so the server always rebuilds with the bundled binary.
5. **Verification** – local build succeeded, deployment to `clockworkcity` showed `dns.providers.cloudflare` in `caddy list-modules`, and `https://n8n.rabalski.eu` started returning valid 200s over a public certificate.

## Lessons / follow-ups
- Prefer downloading the official Caddy bundle with required plugins when Go module builds behave unpredictably inside restricted environments.
- Keep GHCR login notes handy in case we later pivot to prebuilt images; otherwise the binary-download route avoids registry auth entirely.
- Future doc edits should note running compose from `~/homelabbing/configs/caddy` and using a local `.docker` directory when credential helpers are missing.
