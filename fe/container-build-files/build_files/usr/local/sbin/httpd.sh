#!/bin/bash

set -a
source /etc/environment
set +a

LISTEN_HTTPS=${LISTEN_HTTPS:-443}
sed "s/{{LISTEN_HTTPS}}/${LISTEN_HTTPS}/g" /etc/httpd/sitefe-httpd.template > /etc/httpd/conf.d/sitefe-httpd.conf

# Start Apache
/usr/sbin/httpd -k start -DFOREGROUND
