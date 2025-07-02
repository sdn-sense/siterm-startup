#!/bin/bash

sleep_long () {
    /usr/libexec/platform-python -c '__import__("select").select([], [], [])'
} &> /dev/null

# Check if socket file exists, if yes, then sleep indefinitely
if [ -S /run/lldpd/lldpd.socket ]; then
    echo "LLDP daemon is already running. Sleeping indefinitely."
    sleep_long
fi
# If socket file does not exist, start lldpd daemon
echo "Starting lldpd daemon..."
exec /usr/sbin/lldpd -d