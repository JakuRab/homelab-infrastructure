#!/bin/bash
# Find the Waybar process for DP-4 and send SIGUSR1 to toggle visibility
pkill -SIGUSR1 -f 'waybar.*config-dp4.json'

