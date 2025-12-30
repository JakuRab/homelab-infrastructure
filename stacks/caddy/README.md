Server Caddy with Cloudflare DNS (DNS‑01)

What this is
- A server-ready Caddy setup that packages Caddy v2.8.4 plus the Cloudflare DNS plugin (github.com/caddy-dns/cloudflare) by downloading the official binary bundle.
- Used on narsis (192.168.1.11) for reverse proxy to all homelab services. Deployed via Portainer GitOps.

Contents
- `Caddyfile` — full site configuration (mounted read‑only by the container)
- `Dockerfile` — downloads the official Caddy binary with the Cloudflare DNS plugin already baked in (via caddyserver.com API).
- `docker-compose.yml` — builds a local image by layering that binary over the stock `caddy:${CADDY_VERSION}` base.
- `docker-compose.no-plugin.yml` — fallback (no plugin), n8n uses `tls internal`
- `Makefile` and `sync_to_server.sh` — helpers for syncing and deploying

Prerequisites
- Cloudflare API Token (Zone:Read + DNS:Edit) for `rabalski.eu` → store in `~/caddy/.env` (no quotes).
  - Set `CF_API_TOKEN=...` (the compose file mirrors this into `CLOUDFLARE_API_TOKEN` for the plugin).
- Docker + Compose on the server.

Deploy (server)
1) Prepare env in `~/caddy` on clockworkcity:
   - `echo 'CF_API_TOKEN=REDACTED' > .env && chmod 600 .env`
2) Sync from repo (from your workstation):
   - `rsync -av configs/caddy/ user@clockworkcity:~/caddy/`
   - or: `make -C configs/caddy sync SERVER=user@clockworkcity DIR=~/caddy`
3) Build + run Caddy with the plugin:
   - `mkdir -p .docker && DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache`
   - `docker compose up -d`
4) Validate + reload on config changes:
   - `docker exec caddy caddy validate --config /etc/caddy/Caddyfile`
   - `docker exec caddy caddy reload   --config /etc/caddy/Caddyfile`

ACME DNS‑01 (per docs)
- Only `n8n.rabalski.eu` uses DNS‑01 explicitly here: `tls { dns cloudflare {env.CF_API_TOKEN} }`.
- Add the same `tls { dns cloudflare {env.CF_API_TOKEN} }` block to new sites that need DNS‑01.

Troubleshooting
- Check the plugin is present:
  - `docker exec caddy caddy list-modules | grep -i dns.providers.cloudflare`
- Watch issuance logs:
  - `docker logs caddy --since 10m | sed -n '/acme/,+40p'`
- Quick fallback (no plugin):
  - `docker compose -f docker-compose.no-plugin.yml up -d` (n8n will use `tls internal`)
- If Docker complains about credential helpers or `$HOME/.docker` permissions, run builds with a local Docker config dir:
  - `mkdir -p .docker && DOCKER_CONFIG=$PWD/.docker docker compose build --pull --no-cache`

Dual‑paths note
- Repo (AI‑managed): `configs/caddy/*` (tracked, reviewed, versioned)
- Server (Docker‑used): `~/caddy/*` (mounted by the container)
- Typical flow: edit in repo → rsync → build/up → validate/reload
