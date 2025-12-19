#!/bin/bash

sleep_long () {
  while :; do sleep 3600; done
}

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting cleanup script"
# Remove yaml files to prefetch from scratch
rm -f /tmp/*-mapping.yaml
rm -f /tmp/*Agent-main.yaml
# Remove any PID files left from reboot/stop.
rm -f /tmp/siterm*-update.pid
# Remove remaining git fetch lock files
rm -f /tmp/siterm-git-fetch-lockfile
# Precreate log dirs, in case removed, non existing
mkdir -p /var/log/siterm-agent/{Agent,Debugger,Ruler}/

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Cleanup script finished, sleeping indefinitely."

sleep_long
