#!/bin/bash

sleep_long () {
    /usr/libexec/platform-python -c '__import__("select").select([], [], [])'
} &> /dev/null


# Read all env variables for the process.
if [ -f "/etc/siterm-mariadb" ]; then
  set -a
  source /etc/siterm-mariadb
  set +a
  env
fi

# Set default Ansible repo (or use one defined in the environment)
ANSIBLE_REPO="${ANSIBLE_REPO:-origin/master}"

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
mkdir -p /var/log/siterm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api,HostData}/
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

  # Pull another branch if defined via environment variable
  if [[ "$ANSIBLE_REPO" != "origin/master" ]]; then
    echo "Switching to branch: $ANSIBLE_REPO"
    cd /opt/siterm/config/ansible/sense || exit 1
    git fetch --all
    git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"
    git pull "$ANSIBLE_REPO" "${ANSIBLE_REPO#origin/}"
  fi
else
  cd /opt/siterm/config/ansible/sense
  git fetch --all
  git branch backup-master-`date +%s`

  git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"
  git reset --hard "$ANSIBLE_REPO"
  git pull "$ANSIBLE_REPO" "${ANSIBLE_REPO#origin/}"

fi
# Run ansible prepare and prepare all ansible configuration files.
python3 /root/ansible-prepare.py

# Make sure all ansible hosts are defined in ~/.ssh/known_hosts
python3 /root/ssh-keygen.py

# Check if upgrade is in progress and loop until it is completed
if [ -f /tmp/siterm-mariadb-init ]; then
  while [ -f /tmp/siterm-mariadb-init ]; do
    echo "Upgrade in progress. Waiting for it to complete."
    sleep 1
  done
fi
if [ ! -f /tmp/config-fetcher-ready ]; then
  while [ ! -f /tmp/config-fetcher-ready ]; do
    echo "Config fetch not started yet. Waiting for it to start."
    sleep 1
  done
fi

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
