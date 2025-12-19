#!/bin/sh

sleep_long () {
  while :; do sleep 3600; done
}

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting MariaDB initialization script."

# Create temp file for initialization (hold off other processes)
touch /tmp/siterm-mariadb-init
echo `date` > /tmp/siterm-mariadb-init

set -a
source /etc/environment || true
set +a

# Check if all env variables are available and set
if [[ -z $MARIA_DB_HOST || -z $MARIA_DB_USER || -z $MARIA_DB_DATABASE || -z $MARIA_DB_PASSWORD || -z $MARIA_DB_PORT ]]; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` DB Configuration file not available. exiting."
    exit 1
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

# Execute /root/mariadb.sql
while true; do
    mysql -v < /root/mariadb.sql
    if [ $? -eq 0 ]; then
        break
    fi
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Retrying mysql sql in 5 seconds..."
    sleep 5
done

echo "`date -u +"%Y-%m-%d %H:%M:%S"` MariaDB initialization script executed successfully."
# Create/Update all databases needed for SiteRM
python3 /usr/local/sbin/dbstart.py

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Site-RM database setup completed."
# create file under /var/lib/mysql which is only unique for Site-RM.
# This ensures that we are not repeating same steps during docker restart
echo $(date) >> /opt/siterm/config/mysql/site-rm-db-initialization

# Remove temp file for initialization
rm -f /tmp/siterm-mariadb-init

# Process is over, sleep long
sleep_long