#!/bin/bash

# Check if upgrade is in progress and loop until it is completed
if [ -f /tmp/siterm-mariadb-init ]; then
  while [ -f /tmp/siterm-mariadb-init ]; do
    echo "Upgrade in progress. Waiting for it to complete."
    sleep 5
  done
fi
if [ ! -f /tmp/config-fetcher-ready ]; then
  while [ ! -f /tmp/config-fetcher-ready ]; do
    echo "Config fetch not finished yet. Waiting for it to start."
    sleep 1
  done
fi

set -a
source /etc/environment
set +a

LISTEN_HTTPS=${LISTEN_HTTPS:-443}
sed "s/{{LISTEN_HTTPS}}/${LISTEN_HTTPS}/g" /etc/httpd/sitefe-httpd.template > /tmp/new-httpd.conf
LISTEN_HTTP=${LISTEN_HTTP:-80}
sed "s/{{LISTEN_HTTP}}/${LISTEN_HTTP}/g" /tmp/new-httpd.conf > /tmp/new-httpd.conf_1
mv /tmp/new-httpd.conf_1 /etc/httpd/conf.d/sitefe-httpd.conf

# Start Apache
exec /usr/sbin/httpd -k start -DFOREGROUND
