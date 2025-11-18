#!/usr/bin/env bash
set -euo pipefail

# Syncs the net_monitor configuration to the server and pulls the latest Docker images.
# The final step of redeploying the stack must be done manually in Portainer.

usage() {
  echo "Usage: $0 <user@host>" 1>&2
  echo "Example: $0 sothasil@192.168.1.10" 1>&2
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

SERVER="$1"
SERVER_DIR="/srv/configs/net_monitor" # This is the fixed path from the user's request

echo "==> Ensuring remote dir exists: ${SERVER}:${SERVER_DIR}"
ssh -t "${SERVER}" "mkdir -p '${SERVER_DIR}'"

echo "==> Syncing configs/net_monitor to ${SERVER}:${SERVER_DIR}"
rsync -av --delete --exclude='stack.env' "$(dirname "$0")/" "${SERVER}:${SERVER_DIR}/"

echo "==> Pulling stack images on ${SERVER}"
ssh -t "${SERVER}" bash -s -- "${SERVER_DIR}" <<'REMOTE'
set -euo pipefail
SRV_DIR="$1"
cd "$SRV_DIR"

echo "--> Checking for docker command..."
# Prefer docker, fall back to sudo docker
if command -v docker >/dev/null 2>&1; then
  DOCKER=docker
else
  DOCKER='sudo docker'
  echo "--> 'docker' not in path, will try '$DOCKER'"
fi

echo "--> Pulling latest images for the net_monitor stack..."
# Prefer new compose subcommand, fall back to docker-compose
if $DOCKER compose version >/dev/null 2>&1; then
  $DOCKER compose -f docker-compose.yml pull
elif command -v docker-compose >/dev/null 2>&1; then
  DC=docker-compose
  $DC -f docker-compose.yml pull
else
  DC='sudo docker-compose'
  echo "--> 'docker compose' and 'docker-compose' not found, will try '$DC'"
  $DC -f docker-compose.yml pull
fi

echo ""
echo "========================================================================"
echo " ✅ Sync complete. Docker images have been pulled on the server."
echo ""
echo " ➡️ Next step: Go to your Portainer UI, select the 'net_monitor' stack,"
echo "    and click 'Redeploy' to apply the changes."
echo "========================================================================"
REMOTE
