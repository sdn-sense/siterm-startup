#!/bin/sh

sleep_long () {
  while :; do sleep 3600; done
}

# Record why initialization failed. docker-healthcheck.sh and siterm-readiness report it.
mark_failed () {
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` FAILED: $1"
  echo "$1" > $TEMP_DIR/siterm-mariadb-init-failed
}

# Mark failed and idle instead of exiting, so supervisord does not rerun the script and clear the failure.
# The init file is kept so other services keep waiting (and log the reason) instead of using a broken DB.
fail_init () {
  mark_failed "$1"
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` FAILED: $1" >> $TEMP_DIR/siterm-mariadb-init
  sleep_long
}

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting MariaDB initialization script."
# Create temp file for initialization (hold off other processes)
TEMP_DIR=$(python3 -c "from SiteRMLibs.MainUtilities import getTempDir; print(getTempDir())")
rm -f $TEMP_DIR/siterm-mariadb-init-failed
touch $TEMP_DIR/siterm-mariadb-init
echo `date` > $TEMP_DIR/siterm-mariadb-init

# Validate DB settings as the SiteRM services read them (before the shell parses /etc/environment below)
if ! DBCHECK=$(python3 -c "from SiteRMLibs.DBBackend import buildDatabaseURL, loadEnvFile; loadEnvFile(); buildDatabaseURL()" 2>&1); then
    echo "$DBCHECK"
    fail_init "Invalid database configuration: `echo "$DBCHECK" | tail -n 1`"
fi

# Source environment variables
set -a
source /etc/environment || true
set +a

# Check if all env variables are available and set
if [[ -z $MARIA_DB_HOST || -z $MARIA_DB_USER || -z $MARIA_DB_DATABASE || -z $MARIA_DB_PASSWORD || -z $MARIA_DB_PORT ]]; then
    fail_init "MARIA_DB_HOST, MARIA_DB_USER, MARIA_DB_DATABASE, MARIA_DB_PASSWORD and MARIA_DB_PORT must all be set in the environment file."
fi

# Overwrite MariaDB port if it is not default 3306
if [[ "$MARIA_DB_PORT" != "3306" && -n "$MARIA_DB_PORT" ]]; then
    cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.bak
    if grep -q "^port=" /etc/my.cnf.d/server.cnf; then
        echo "`date -u +"%Y-%m-%d %H:%M:%S"` MariaDB Port is already defined in /etc/my.cnf.d/server.cnf"
    else
        echo "port=${MARIA_DB_PORT}" >> /etc/my.cnf.d/server.cnf
        echo "`date -u +"%Y-%m-%d %H:%M:%S"` Port ${MARIA_DB_PORT} added to /etc/my.cnf.d/server.cnf."
    fi
fi

# Replace variables in /root/mariadb.sql with vars from ENV (docker file)
sed -i "s/##ENV_MARIA_DB_PASSWORD##/$MARIA_DB_PASSWORD/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_USER##/$MARIA_DB_USER/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_HOST##/$MARIA_DB_HOST/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_DATABASE##/$MARIA_DB_DATABASE/" /root/mariadb.sql

# Execute /root/mariadb.sql. Keep retrying while MariaDB starts, but report a failure after ~5 minutes.
SQL_ATTEMPTS=0
until mysql -v < /root/mariadb.sql; do
    SQL_ATTEMPTS=$((SQL_ATTEMPTS + 1))
    if [ $SQL_ATTEMPTS -eq 60 ]; then
        mark_failed "Unable to apply /root/mariadb.sql after $SQL_ATTEMPTS attempts. Check that the mariadb process is running (siterm_mariadb.log). Still retrying."
    fi
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Retrying mysql sql in 5 seconds..."
    sleep 5
done
rm -f $TEMP_DIR/siterm-mariadb-init-failed

echo "`date -u +"%Y-%m-%d %H:%M:%S"` MariaDB initialization script executed successfully."
# Create/Update all databases needed for SiteRM
python3 -u /usr/local/sbin/dbstart.py 2>&1 | tee $TEMP_DIR/siterm-dbstart.log
DBSTART_RC=${PIPESTATUS[0]}
if [ $DBSTART_RC -ne 0 ]; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` dbstart.py failed (exit code $DBSTART_RC). Site-RM database setup did NOT complete -- see traceback above."
    DBSTART_ERR=$(tail -n 1 $TEMP_DIR/siterm-dbstart.log)
    fail_init "Database setup (dbstart.py) failed with exit code $DBSTART_RC: ${DBSTART_ERR//"$MARIA_DB_PASSWORD"/<redacted>}"
fi

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Site-RM database setup completed."
# create file under /var/lib/mysql which is only unique for Site-RM.
# This ensures that we are not repeating same steps during docker restart
echo $(date) >> /opt/siterm/config/mysql/site-rm-db-initialization

# Remove temp file for initialization
rm -f $TEMP_DIR/siterm-mariadb-init

# Process is over, sleep long
sleep_long
