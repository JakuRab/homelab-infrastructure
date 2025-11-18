#!/bin/bash

# Output current icon based on whether Waybar for DP-4 is running
if pgrep -fa "waybar.*DP-4" > /dev/null; then
    echo ""  # on
else
    echo ""  # off
fi

