#!/bin/bash

set -x
set -m

ARCH=`python3 -c 'import platform; print(platform.processor())'`
if [[ $ARCH == 'ppc64le' ]]; then
  # ppc64le keeps very old openssl. There is only one machine of this
  # So not rebuilding whole ssl just for this. This is not needed
  # for x86_64
  export CRYPTOGRAPHY_ALLOW_OPENSSL_102=1
fi

# Remove yaml files to prefetch from scratch;
rm -f /tmp/*-mapping.yaml
rm -f /tmp/*-FE-main.yaml
rm -f /tmp/*-FE-auth.yaml
# Remove any PID files left afer reboot/stop.
rm -f /tmp/dtnrm*.pid
rm -f /etc/httpd/run/httpd.pid
# Remove remaining git fetch lock files
rm -f /tmp/siterm-git-fetch-lockfile
# Precreate log dirs, in case removed, non existing
mkdir -p /var/log/dtnrm-site-fe/
chown apache:apache /var/log/dtnrm-site-fe/
chmod g+s /var/log/dtnrm-site-fe/
mkdir -p /var/log/dtnrm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api}/

# As first run, Run Custom CA prefetch and add them to CAs dir.
sh /etc/cron-scripts/siterm-ca-cron.sh

# Check if all env variables are available and set
if [[ -z $MARIA_DB_HOST || -z $MARIA_DB_USER || -z $MARIA_DB_DATABASE || -z $MARIA_DB_PASSWORD || -z MARIA_DB_PORT ]]; then
  if [ -f "/etc/siterm-mariadb" ]; then
    set -a
    source /etc/siterm-mariadb
    set +a
    env
  else
    echo 'DB Configuration file not available. exiting.'
    exit 1
  fi
fi

Config-Fetcher --action start --onetimerun --noreporting --logtostdout
status=$?
if [ $status -ne 0 ]; then
  echo "Failed Config Fetch from Github. Fatal Error. Exiting"
  exit $status
fi

# Start MariaDB
sh /root/mariadb.sh

# Run crond
touch /var/log/cron.log
/usr/sbin/crond
crontab /etc/cron.d/siterm-crons

# Start the first process
mkdir -p /run/httpd
/usr/sbin/httpd -k restart
status=$?
exit_code=0
if [ $status -ne 0 ]; then
  echo "Failed to start httpd: $status"
  exit_code=1
fi

# Start the second process
LookUpService-update --action restart --foreground &> /var/log/dtnrm-site-fe/LookUpService/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart LookUpService-update: $status"
  exit_code=2
fi
sleep 5
# Start the third process
PolicyService-update --action restart --foreground &> /var/log/dtnrm-site-fe/PolicyService/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart PolicyService-update: $status"
  exit_code=3
fi
sleep 5
# Start the fourth process
ProvisioningService-update --action restart --foreground &> /var/log/dtnrm-site-fe/ProvisioningService/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart ProvisioningService-update: $status"
  exit_code=4
fi
Config-Fetcher --action restart --foreground --noreporting
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart Config-Fetcher: $status"
  exit_code=5
fi
# Naive check runs checks once a minute to see if either of the processes exited.
# This illustrates part of the heavy lifting you need to do if you want to run
# more than one service in a container. The container exits with an error
# if it detects that either of the processes has exited.
# Otherwise it loops forever, waking up every 60 seconds

while sleep 30; do
  ps aux |grep httpd |grep -q -v grep &> /dev/null
  PROCESS_1_STATUS=$?
  ps aux |grep LookUpService-update |grep -q -v grep &> /dev/null
  PROCESS_2_STATUS=$?
  ps aux |grep PolicyService-update |grep -q -v grep &> /dev/null
  PROCESS_3_STATUS=$?
  ps aux |grep ProvisioningService-update |grep -q -v grep &> /dev/null
  PROCESS_4_STATUS=$?
  ps aux |grep Config-Fetcher |grep -q -v grep &> /dev/null
  PROCESS_5_STATUS=$?
  # If the greps above find anything, they exit with 0 status
  # If they are not both 0, then something is wrong
  if [ $PROCESS_1_STATUS -ne 0 -o $PROCESS_2_STATUS -ne 0 -o $PROCESS_3_STATUS -ne 0 -o $PROCESS_4_STATUS -ne 0 -o $PROCESS_5_STATUS -ne 0 ]; then
    echo "One of the processes has already exited."
    echo "httpd: " $PROCESS_1_STATUS
    echo "LookUpService-update:" $PROCESS_2_STATUS
    echo "PolicyService-update:" $PROCESS_3_STATUS
    echo "ProvisioningService-update:" $PROCESS_4_STATUS
    echo "Config-Fetcher:" $PROCESS_5_STATUS
    exit_code=6
    break;
  fi
done
echo "We just got break. Endlessly sleep for debugging purpose."
while true; do sleep 120; done
