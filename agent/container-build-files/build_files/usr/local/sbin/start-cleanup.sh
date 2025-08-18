#!/bin/bash

sleep_long () {
    python3 -c '__import__("select").select([], [], [])'
} &> /dev/null


# Remove yaml files to prefetch from scratch
rm -f /tmp/*-mapping.yaml
rm -f /tmp/*Agent-main.yaml
# Remove any PID files left from reboot/stop.
rm -f /tmp/siterm*-update.pid
# Remove remaining git fetch lock files
rm -f /tmp/siterm-git-fetch-lockfile
# Precreate log dirs, in case removed, non existing
mkdir -p /var/log/siterm-agent/{Agent,Debugger,Ruler}/

sleep_long
