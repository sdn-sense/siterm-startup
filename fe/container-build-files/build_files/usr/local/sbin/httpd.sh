#!/bin/bash
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting httpd initialization script."
TEMP_DIR=$(python3 -c "from SiteRMLibs.MainUtilities import getTempDir; print(getTempDir())")
# Check if upgrade is in progress and loop until it is completed
if [ -f $TEMP_DIR/siterm-mariadb-init ]; then
  while [ -f $TEMP_DIR/siterm-mariadb-init ]; do
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Upgrade in progress. Waiting for it to complete."
    sleep 5
  done
fi
if [ ! -f $TEMP_DIR/config-fetcher-ready ]; then
  while [ ! -f $TEMP_DIR/config-fetcher-ready ]; do
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Config fetch not finished yet. Waiting for it to start."
    sleep 1
  done
fi

set -a
source /etc/environment
set +a

# Set defaults for HTTPS
export LISTEN_HTTPS="${LISTEN_HTTPS:-443}"

TEMPLATE_FILE="/etc/httpd/sitefe-httpd.conf-template"
# if KUBERNETES_PORT env is set, then use /etc/httpd/sitefe-httpd-kube.conf-template
if [ -n "${KUBERNETES_PORT:-}" ]; then
  TEMPLATE_FILE="/etc/httpd/sitefe-httpd-kube.conf-template"
fi

envsubst < "$TEMPLATE_FILE" > /etc/httpd/conf.d/sitefe-httpd.conf

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting httpd server"
exec /usr/sbin/httpd -k start -DFOREGROUND
