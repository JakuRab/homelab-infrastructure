#!/usr/bin/env bash
set -euo pipefail

# If tailscale CLI or tailscaled isn't present, do nothing
if ! command -v tailscale >/dev/null 2>&1; then
  exit 0
fi

# If status JSON fails, restart the daemon (likely not responding)
if ! tailscale status --json >/dev/null 2>&1; then
  systemctl restart tailscaled || true
  exit 0
fi

# Check backend state; restart if not Running
state=$(tailscale status --self 2>/dev/null | awk '/Backend state:/{print $3}')
if [[ "${state:-}" != "Running" ]]; then
  systemctl restart tailscaled || true
fi

