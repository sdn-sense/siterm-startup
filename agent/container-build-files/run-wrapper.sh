#!/bin/bash

function stopServices()
{
  echo "Received Stop Signal. Stopping Services"
  set -x
  dtnrmagent-update --action stop
  dtnrm-ruler --action stop
  dtnrm-debugger --action stop
  Config-Fetcher --action stop
  exit 0
}

trap stopServices INT TERM SIGTERM SIGINT

# Remove yaml files to prefetch from scratch;
rm -f /tmp/*-mapping.yaml
rm -f /tmp/*Agent-main.yaml
# Remove any PID files left from reboot/stop.
rm -f /tmp/dtnrm*-update.pid
# Remove remaining git fetch lock files
rm -f /tmp/siterm-git-fetch-lockfile
# Precreate log dirs, in case removed, non existing
mkdir -p /var/log/dtnrm-agent/{Agent,Debugger,Ruler}/

# Start crond
touch /var/log/cron.log
/usr/sbin/crond
crontab /etc/cron.d/siterm-crons

Config-Fetcher --action start --onetimerun --noreporting --logtostdout
status=$?
if [ $status -ne 0 ]; then
  echo "Failed Config Fetch from Github. Fatal Error. Exiting"
  exit $status
fi

# Start agent mon process
dtnrmagent-update --action restart --foreground &> /var/log/dtnrm-agent/Agent/daemon.log
status=$?
exit_code=0
if [ $status -ne 0 ]; then
  echo "Failed to restart dtnrmagent-update: $status"
  exit_code=1
fi
sleep 2
# Start ruler process
dtnrm-ruler --action restart --foreground &> /var/log/dtnrm-agent/Ruler/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart dtnrm-ruler: $status"
  exit_code=2
fi
# Start debugger process
dtnrm-debugger --action restart --foreground &> /var/log/dtnrm-agent/Debugger/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart dtnrm-debugger: $status"
  exit_code=2
fi
# Start Config Fetcher Service
Config-Fetcher --action restart --foreground
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart Config-Fetcher: $status"
  exit_code=3
fi


while true; do sleep 1; done
