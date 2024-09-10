#!/bin/sh

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

if [ ! -f /opt/siterm/config/mysql/site-rm-db-initialization ]; then
  # First time start of mysql, ensure dirs are present
  mkdir -p /opt/siterm/config/mysql/
  mkdir -p /var/log/mariadb
  chown -R mysql:mysql /opt/siterm/config/mysql/
  chown mysql:mysql /var/log/mariadb

  # Initialize the mysql data directory and create system tables
  mysql_install_db --user mysql > /dev/null

  # Start mysqld in safe mode and sleep 5 sec
  mysqld_safe --user mysql &> /var/log/mariadb/startup &
  echo $! > /opt/siterm/config/mysql/mariadb.pid
  sleep 5s

  # Replace variables in /root/mariadb.sql with vars from ENV (docker file)
  sed -i "s/##ENV_MARIA_DB_PASSWORD##/$MARIA_DB_PASSWORD/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_USER##/$MARIA_DB_USER/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_HOST##/$MARIA_DB_HOST/" /root/mariadb.sql
  sed -i "s/##ENV_MARIA_DB_DATABASE##/$MARIA_DB_DATABASE/" /root/mariadb.sql

  # Execute /root/mariadb.sql
  mysql -v < /root/mariadb.sql

  # Create all databases needed for SiteRM
  python3 -c 'from SiteRMLibs.DBBackend import DBBackend; db = DBBackend(); db._createdb()'

  # create file under /var/lib/mysql which is only unique for Site-RM.
  # This ensures that we are not repeating same steps during docker restart
  echo $(date) >> /opt/siterm/config/mysql/site-rm-db-initialization
else
  echo "Seems this is not the first time start. Will not create DB again"
  chown -R mysql:mysql /opt/siterm/config/mysql/
  mysqld_safe --user mysql &> /var/log/mariadb/startup &
  echo $! > /opt/siterm/config/mysql/mariadb.pid
  sleep 5s
  # Create all databases if not exists needed for SiteRM
  python3 -c 'from SiteRMLibs.DBBackend import DBBackend; db = DBBackend(); db._createdb()'
fi

# Start DB Cleaner in background
# 2024-04-09 Disabled due to continuos restarts on prp dev container
# python3 /usr/local/sbin/DBCleaner.py &> /var/log/mariadb/DBCleaner.log &

# Wait for Maria db to exit (if so, supervisord will restart it)
wait $(cat /opt/siterm/config/mysql/mariadb.pid)
