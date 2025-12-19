#!/bin/bash

sleep_long () {
    python3 -c '__import__("select").select([], [], [])'
} &> /dev/null

# Check if socket file exists, if yes, then sleep indefinitely
if [ -S /run/lldpd/lldpd.socket ]; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` LLDP daemon is already running. Sleeping indefinitely."
    sleep_long
fi
# If socket file does not exist, start lldpd daemon
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting lldpd daemon..."
exec /usr/sbin/lldpd -d