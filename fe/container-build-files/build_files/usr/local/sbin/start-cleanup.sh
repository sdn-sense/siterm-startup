#!/bin/bash

sleep_long () {
  while :; do sleep 3600; done
}
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting cleanup script"

# Read all env variables for the process.
set -a
source /etc/environment || true
set +a

# Set default Ansible repo (or use one defined in the environment)
ANSIBLE_REPO="${ANSIBLE_REPO:-origin/master}"
REMOTE="${ANSIBLE_REPO%%/*}"

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Removing temporary files."
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
mkdir -p /var/log/siterm-site-fe/{LookUpService,ProvisioningService,PolicyService,SwitchBackends,contentdb,http-api,HostData,ServiceData}/
chown apache:apache /var/log/siterm-site-fe/*
chmod g+s /var/log/siterm-site-fe/*

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Cleanup script finished."
# Create dynamic directories for apache write/read
python3 /root/dircreate.py

# Make sure ansible dir exists (Kubernetes has it empty once PVC is created)
if [[ ! -d "/opt/siterm/config/ansible" ]]; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Directory /opt/siterm/config/ansible DOES NOT exists."
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Cloning git repo and add default ansible config."
  mkdir -p /opt/siterm/config/ansible/sense
  git clone https://github.com/sdn-sense/ansible-templates /opt/siterm/config/ansible/sense

  # Pull another branch if defined via environment variable
  if [[ "$ANSIBLE_REPO" != "origin/master" ]]; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Switching to branch: $ANSIBLE_REPO"
    cd /opt/siterm/config/ansible/sense || exit 1
    git fetch --all
    git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"
    git pull "$REMOTE" "${ANSIBLE_REPO#origin/}"
  fi
else
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Directory /opt/siterm/config/ansible exists."
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Updating git repo to the latest version."
  cd /opt/siterm/config/ansible/sense
  git fetch --all
  git branch backup-master-`date +%s`

  git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"
  git reset --hard "$ANSIBLE_REPO"
  git pull "$REMOTE" "${ANSIBLE_REPO#origin/}"

fi

# Generate JWT keys if they do not exist
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Generating JWT keys."
python3 /root/generate_jwt.py

# Run ansible prepare and prepare all ansible configuration files.
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Preparing Ansible configuration files."
python3 /root/ansible-prepare.py

# Make sure all ansible hosts are defined in ~/.ssh/known_hosts
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Generating SSH keys and populating known_hosts."
python3 /root/ssh-keygen.py

TEMP_DIR=$(python3 -c "from SiteRMLibs.MainUtilities import getTempDir; print(getTempDir())")
# Check if upgrade is in progress and loop until it is completed
if [ -f $TEMP_DIR/siterm-mariadb-init ]; then
  while [ -f $TEMP_DIR/siterm-mariadb-init ]; do
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Upgrade in progress. Waiting for it to complete."
    sleep 1
  done
fi
if [ ! -f $TEMP_DIR/config-fetcher-ready ]; then
  while [ ! -f $TEMP_DIR/config-fetcher-ready ]; do
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Config fetch not started yet. Waiting for it to start."
    sleep 1
  done
fi

# Run in a loop directory creation and chown for apache
while true; do
    sleep_time=$(( 3600 + RANDOM % 1800 ))
    python3 /root/dircreate.py
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Sleeping for $sleep_time seconds"
    sleep $sleep_time
    # Run the Python script
done

# Sleep forever in case exit loop (which should not happen)
sleep_long
