#!/bin/bash

# Navigate to the Eww release directory
cd ~/eww/target/release

# Start the Eww daemon
./eww daemon &

# Wait for the daemon to start (adjust if needed)
sleep 1

# Open the bars
./eww open bar_1
./eww open bar_2
