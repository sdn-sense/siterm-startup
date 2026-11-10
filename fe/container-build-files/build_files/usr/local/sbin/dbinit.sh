#!/bin/bash
# One-shot database init/upgrade for split deployments (SITERM_COMPONENT=dbinit).
# Records running/done/failed in the database; every other component waits for "done".
set -e
set -a
source /etc/environment || true
set +a

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Validating database settings."
python3 -c "from SiteRMLibs.DBBackend import buildDatabaseURL, loadEnvFile; loadEnvFile(); buildDatabaseURL()"

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Creating/upgrading database schema."
exec python3 -u /usr/local/sbin/dbstart.py
