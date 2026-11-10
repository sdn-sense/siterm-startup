#!/bin/bash
# One-shot database init/upgrade for split deployments (SITERM_COMPONENT=dbinit).
# Records running/done/failed in the database; every other component waits for "done".
set -e
set -a
source /etc/environment || true
set +a

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Validating database settings."
python3 -c "from SiteRMLibs.DBBackend import buildDatabaseURL, loadEnvFile; loadEnvFile(); buildDatabaseURL()"

# JWT signing keys: generated once into RSA_DIR when it is a volume shared with the frontend containers.
if [[ -n "$RSA_DIR" || -d /opt/siterm/jwt_secrets ]]; then
  python3 /root/generate_jwt.py
fi

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Creating/upgrading database schema."
exec python3 -u /usr/local/sbin/dbstart.py
