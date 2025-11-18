#!/usr/bin/env bash
set -euo pipefail

# Sync configs/caddy to server and rebuild/restart Caddy (plugin or fallback)

usage() {
  echo "Usage: $0 <user@host> [server_caddy_dir]" 1>&2
  echo "Defaults: server_caddy_dir=~/caddy" 1>&2
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

SERVER="$1"
REMOTE_USER="${SERVER%@*}"
DEFAULT_DIR="/home/${REMOTE_USER}/caddy"
SERVER_DIR="${2:-$DEFAULT_DIR}"

echo "==> Ensuring remote dir exists: ${SERVER}:${SERVER_DIR}"
ssh -t "${SERVER}" "mkdir -p '${SERVER_DIR}'"

echo "==> Syncing configs/caddy to ${SERVER}:${SERVER_DIR}"
rsync -av --delete --exclude='.env' "$(dirname "$0")/" "${SERVER}:${SERVER_DIR}/"

echo "==> Building and restarting Caddy on ${SERVER}"
ssh -t "${SERVER}" bash -s -- "${SERVER_DIR}" <<'REMOTE'
set -euo pipefail
SRV_DIR="$1"
cd "$SRV_DIR"
if [ ! -f .env ]; then
  echo 'WARN: .env not found; create it with CF_API_TOKEN=...' 1>&2
fi
# Prefer docker, fall back to sudo docker
if command -v docker >/dev/null 2>&1; then DOCKER=docker; else DOCKER='sudo docker'; fi

echo "--> Building Caddy image (pulling latest base layers)..."
# Prefer new compose subcommand, fall back to docker-compose
if $DOCKER compose version >/dev/null 2>&1; then
  if ! ($DOCKER compose build --pull --no-cache --progress=plain || $DOCKER compose build --pull --no-cache); then
    echo "ERROR: Caddy image build failed. Aborting." >&2
    exit 1
  fi
  echo "--> Starting Caddy container..."
  $DOCKER compose up -d
else
  if command -v docker-compose >/dev/null 2>&1; then DC=docker-compose; else DC='sudo docker-compose'; fi
  if ! $DC build --pull --no-cache; then
    echo "ERROR: Caddy image build failed. Aborting." >&2
    exit 1
  fi
  echo "--> Starting Caddy container..."
  $DC up -d
fi

echo "--> Verifying Caddy container..."
CID=$($DOCKER ps -q -f name=^/caddy$ || true)
if [ -n "$CID" ]; then
  $DOCKER exec caddy caddy validate --config /etc/caddy/Caddyfile || true
  $DOCKER exec caddy caddy reload --config /etc/caddy/Caddyfile || true
  echo "--> Checking for Cloudflare DNS module..."
  $DOCKER exec caddy caddy list-modules | grep -i dns.providers.cloudflare || echo "WARN: Cloudflare module not found in caddy list-modules"
else
  echo 'WARN: caddy container not running. Try fallback:' 1>&2
  echo "    $DOCKER compose -f docker-compose.no-plugin.yml up -d" 1>&2
fi
echo 'Caddy redeployed.'
REMOTE
