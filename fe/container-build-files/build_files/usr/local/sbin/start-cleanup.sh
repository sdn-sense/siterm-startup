#!/bin/bash

sleep_long () {
    /usr/libexec/platform-python -c '__import__("select").select([], [], [])'
} &> /dev/null

# Remove yaml files to prefetch from scratch
rm -f /tmp/*-mapping.yaml
rm -f /tmp/*-FE-main.yaml
rm -f /tmp/*-FE-auth.yaml
# Remove any PID files left afer reboot/stop.
rm -f /tmp/siterm*.pid
rm -f /etc/httpd/run/httpd.pid
# Remove remaining git fetch lock files
rm -f /tmp/siterm-git-fetch-lockfile
# Precreate log dirs, in case removed, non existing
mkdir -p /var/log/siterm-site-fe/
chown apache:apache /var/log/siterm-site-fe/
chmod g+s /var/log/siterm-site-fe/
mkdir -p /var/log/siterm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api}/
chown apache:apache /var/log/siterm-site-fe/*
chmod g+s /var/log/siterm-site-fe/*

# Create dynamic directories for apache write/read
python3 /root/dircreate.py

# Make sure ansible dir exists (Kubernetes has it empty once PVC is created)
if [[ ! -d "/opt/siterm/config/ansible" ]]; then
  echo "Directory /opt/siterm/config/ansible DOES NOT exists."
  echo "Cloning git repo and add default ansible config."
  mkdir -p /opt/siterm/config/ansible/sense
  git clone https://github.com/sdn-sense/ansible-templates /opt/siterm/config/ansible/sense
else
  cd /opt/siterm/config/ansible/sense
  git fetch --all
  git branch backup-master-`date +%s`
  git reset --hard origin/master
fi
# Run ansible prepare and prepare all ansible configuration files.
python3 /root/ansible-prepare.py

# Make sure all ansible hosts are defined in ~/.ssh/known_hosts
python3 /root/ssh-keygen.py

# Run in a loop directory creation and chown for apache
while true; do
    sleep_time=$(( 3600 + RANDOM % 1800 ))
    echo "Sleeping for $sleep_time seconds"
    sleep $sleep_time
    # Run the Python script
    python3 /root/dircreate.py
done

# Sleep forever in case exit loop (which should not happen)
sleep_long
