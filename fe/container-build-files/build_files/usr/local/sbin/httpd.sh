#!/bin/bash

set -a
source /etc/environment
set +a

LISTEN_HTTPS=${LISTEN_HTTPS:-443}
sed "s/{{LISTEN_HTTPS}}/${LISTEN_HTTPS}/g" /etc/httpd/sitefe-httpd.template > /tmp/new-httpd.conf
LISTEN_HTTP=${LISTEN_HTTP:-80}
sed "s/{{LISTEN_HTTP}}/${LISTEN_HTTP}/g" /tmp/new-httpd.conf > /tmp/new-httpd.conf_1
mv /tmp/new-httpd.conf_1 /etc/httpd/conf.d/sitefe-httpd.conf

# Start Apache
/usr/sbin/httpd -k start -DFOREGROUND
