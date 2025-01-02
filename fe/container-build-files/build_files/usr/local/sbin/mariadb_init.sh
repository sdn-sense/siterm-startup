#!/bin/sh

sleep_long () {
    /usr/libexec/platform-python -c '__import__("select").select([], [], [])'
} &> /dev/null

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

# Wait for Maria db to start
sleep 20s

if [ ! -f /opt/siterm/config/mysql/site-rm-db-initialization ]; then
  # Replace variables in /root/mariadb.sql with vars from ENV (docker file)
  sed -i "s/##ENV_MARIA_DB_PASSWORD##/$MARIA_DB_PASSWORD/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_USER##/$MARIA_DB_USER/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_HOST##/$MARIA_DB_HOST/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_DATABASE##/$MARIA_DB_DATABASE/" /root/mariadb.sql

  # Execute /root/mariadb.sql
  mysql -v < /root/mariadb.sql

  # Create/Update all databases needed for SiteRM
  python3 /usr/local/sbin/dbstart.py

  # create file under /var/lib/mysql which is only unique for Site-RM.
  # This ensures that we are not repeating same steps during docker restart
  echo $(date) >> /opt/siterm/config/mysql/site-rm-db-initialization
else
  echo "Seems this is not the first time start."
  # Create/Update all databases needed for SiteRM
  python3 /usr/local/sbin/dbstart.py

fi

# Process is over, sleep long
sleep_long
