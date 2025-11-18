#!/bin/bash
# Launch script for dual-monitor Waybar setup

# Kill any existing Waybar instances
killall waybar

# Wait a moment for processes to terminate
sleep 0.5

# Launch Waybar for DP-6 (always visible)
waybar -c ~/.config/waybar/config-dp6.json -s ~/.config/waybar/style.css &

# Launch Waybar for DP-4 (toggleable with SUPER+Z)
waybar -c ~/.config/waybar/config-dp4.json -s ~/.config/waybar/style.css &
