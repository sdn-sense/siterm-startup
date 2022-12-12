#!/bin/bash

function stopServices()
{
  echo "Received Stop Signal. Stopping Services"
  set -x
  kill -SIGTERM `cat /opt/siterm/config/mysql/mariadb.pid`
  rm -f /opt/siterm/config/mysql/mariadb.pid
  /usr/sbin/httpd -k stop
  LookUpService-update --action stop
  ProvisioningService-update --action stop
  SNMPMonitoring-update --action stop
  Config-Fetcher --action stop
  exit 0
}

trap stopServices INT TERM SIGTERM SIGINT

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
chown apache:apache /var/log/dtnrm-site-fe/*
chmod g+s /var/log/dtnrm-site-fe/*

# Make sure all ansible hosts are defined in ~/.ssh/known_hosts
python3 /root/ssh-keygen.py

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
if [ $status -ne 0 ]; then
  echo "Failed to start httpd: $status"
fi

# Start the second process
LookUpService-update --action restart --foreground &> /var/log/dtnrm-site-fe/LookUpService/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart LookUpService-update: $status"
fi
sleep 5
# Start the third process
ProvisioningService-update --action restart --foreground &> /var/log/dtnrm-site-fe/ProvisioningService/daemon.log
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart ProvisioningService-update: $status"
fi
Config-Fetcher --action restart --foreground --noreporting
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart Config-Fetcher: $status"
fi

SNMPMonitoring-update --action restart --foreground
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to restart SNMPMonitoring: $status"
fi

while true; do sleep 1; done
