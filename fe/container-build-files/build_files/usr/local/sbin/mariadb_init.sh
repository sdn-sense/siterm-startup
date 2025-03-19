#!/bin/sh

db_backup_sleep () {
  BACKUPDIR="/opt/siterm/config/backups/"
  while true; do
      TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
      BACKUPPATH="$BACKUPDIR/$TIMESTAMP"
      mkdir -p "$BACKUPPATH"
      mysqldump "sitefe" | xz -c > "$BACKUPPATH/sitefe.sql.xz"
      # Remove backups while keeping the last 72
      # To use backup file: xzcat sitefe.sql.xz | mysql -u root -p sitefe
      ls -dt "$BACKUPDIR"/* | tail -n +72 | xargs rm -rf --
      # Sleep for 1 hour
      sleep 3600
    done
} &> /dev/null

# Create temp file for initialization (hold off other processes)
touch /tmp/siterm-mariadb-init
echo `date` > /tmp/siterm-mariadb-init

# Check if all env variables are available and set
if [[ -z $MARIA_DB_HOST || -z $MARIA_DB_USER || -z $MARIA_DB_DATABASE || -z $MARIA_DB_PASSWORD || -z $MARIA_DB_PORT ]]; then
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

# Overwrite MariaDB port if it is not default 3306
if [[ "$MARIA_DB_PORT" != "3306" && -n "$MARIA_DB_PORT" ]]; then
    cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.bak
    if grep -q "^port=" /etc/my.cnf.d/server.cnf; then
        echo "MariaDB Port is already defined in /etc/my.cnf.d/server.cnf"
    else
        echo "port=${MARIA_DB_PORT}" >> /etc/my.cnf.d/server.cnf
        echo "Port ${MARIA_DB_PORT} added to /etc/my.cnf.d/server.cnf."
    fi
fi

# Replace variables in /root/mariadb.sql with vars from ENV (docker file)
sed -i "s/##ENV_MARIA_DB_PASSWORD##/$MARIA_DB_PASSWORD/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_USER##/$MARIA_DB_USER/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_HOST##/$MARIA_DB_HOST/" /root/mariadb.sql
sed -i "s/##ENV_MARIA_DB_DATABASE##/$MARIA_DB_DATABASE/" /root/mariadb.sql

# Execute /root/mariadb.sql
while true; do
    mysql -v < /root/mariadb.sql
    if [ $? -eq 0 ]; then
        break
    fi
    echo "Retrying mysql sql in 5 seconds..."
    sleep 5
done

# Create/Update all databases needed for SiteRM
python3 /usr/local/sbin/dbstart.py

# create file under /var/lib/mysql which is only unique for Site-RM.
# This ensures that we are not repeating same steps during docker restart
echo $(date) >> /opt/siterm/config/mysql/site-rm-db-initialization

# Remove temp file for initialization
rm -f /tmp/siterm-mariadb-init

# Process is over, sleep long
db_backup_sleep
