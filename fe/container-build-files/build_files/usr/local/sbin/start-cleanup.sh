#!/bin/bash

sleep_long () {
    /usr/libexec/platform-python -c '__import__("select").select([], [], [])'
} &> /dev/null

# Remove yaml files to prefetch from scratch;
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
  python3 /root/ansible-prepare.py
else
  cd /opt/siterm/config/ansible/sense && git pull
  python3 /root/ansible-prepare.py
fi

# Make sure all ansible hosts are defined in ~/.ssh/known_hosts
python3 /root/ssh-keygen.py

sleep_long
