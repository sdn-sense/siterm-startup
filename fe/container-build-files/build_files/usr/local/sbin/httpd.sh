#!/bin/bash
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting httpd initialization script."
TEMP_DIR=$(python3 -c "from SiteRMLibs.MainUtilities import getTempDir; print(getTempDir())")
# All-in-one image only: wait for mariadb_init.sh in this same container
if [ -f $TEMP_DIR/siterm-mariadb-init ]; then
  while [ -f $TEMP_DIR/siterm-mariadb-init ]; do
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Upgrade in progress. Waiting for it to complete."
    sleep 5
  done
fi
# Wait until the database is initialized and the site configuration is available (state lives in the database)
until python3 -c "
import sys
from SiteRMLibs import __version__ as version
from SiteRMLibs.DBState import feStartupState
from SiteRMLibs.GitConfig import publishedConfigRequired
state, msg = feStartupState(version, publishedConfigRequired())
print(msg)
sys.exit(0 if state == 'ready' else 1)
"; do
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Startup not ready yet. Waiting."
  sleep 5
done

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
