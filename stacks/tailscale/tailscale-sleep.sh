#!/usr/bin/env bash
# /etc/systemd/system-sleep/tailscale-restart.sh
#
# Restart tailscaled after the laptop wakes from suspend/hibernate.
# Tailscaled frequently gets stuck after resume because the network
# interface is gone during sleep and the WireGuard tunnel state is stale.

case "$1" in
  post)
    # Brief delay to let NetworkManager re-establish connectivity first
    sleep 2
    systemctl restart tailscaled
    ;;
esac
