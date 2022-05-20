#!/bin/bash

set -x
set -m

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


# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 30; do
  ps aux |grep dtnrmagent-update |grep -q -v grep &> /dev/null
  PROCESS_1_STATUS=$?
  ps aux |grep dtnrm-ruler |grep -q -v grep &> /dev/null
  PROCESS_2_STATUS=$?
  ps aux |grep dtnrm-debugger |grep -q -v grep &> /dev/null
  PROCESS_3_STATUS=$?
  ps aux |grep Config-Fetcher |grep -q -v grep &> /dev/null
  PROCESS_4_STATUS=$?

  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 -o $PROCESS_4_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    echo "dtnrmagent-update: " $PROCESS_1_STATUS
    echo "dtnrm-ruler:" $PROCESS_2_STATUS
    echo "dtnrm-debugger:" $PROCESS_3_STATUS
    echo "Config-Fetcher:" $PROCESS_4_STATUS
    exit_code=5
    break;
  fi
done
echo "We just got break. Endlessly sleep for debugging purpose."
while true; do sleep 120; done
