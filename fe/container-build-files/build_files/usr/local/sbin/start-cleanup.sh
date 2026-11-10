#!/bin/bash

sleep_long () {
  while :; do sleep 3600; done
}
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Starting cleanup script"

# Read all env variables for the process.
set -a
source /etc/environment || true
set +a

# Set default Ansible repo (or use one defined in the environment).
# ANSIBLE_REPO accepts either a bare ref ("1.6.4", "master") or an
# "origin/<ref>" form (the historical default) -- either way, REMOTE is
# always "origin", since this script only ever clones from the one remote
# set up by the `git clone` below.
#
ANSIBLE_REPO="${ANSIBLE_REPO:-origin/master}"
REMOTE="origin"

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

# Clone the ansible-templates repo fresh into /opt/siterm/config/ansible/sense
# and switch to $ANSIBLE_REPO if it isn't the default branch. Used both for
# the first-ever clone and as the recovery path when an existing checkout
# turns out to be corrupted (see below) -- a corrupted git repo on a PVC
# survives pod restarts and even image redeploys, so falling back to a full
# re-clone is the only way to self-heal rather than failing forever.
cloneAnsibleRepo () {
  mkdir -p /opt/siterm/config/ansible/sense
  git clone https://github.com/sdn-sense/ansible-templates /opt/siterm/config/ansible/sense
  cd /opt/siterm/config/ansible/sense || exit 1
  if [[ "$ANSIBLE_REPO" != "origin/master" ]]; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Switching to branch: $ANSIBLE_REPO"
    git fetch --all
    git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"
    git pull "$REMOTE" "${ANSIBLE_REPO#origin/}"
  fi
}

# Make sure ansible dir exists (Kubernetes has it empty once PVC is created)
if [[ ! -d "/opt/siterm/config/ansible" ]]; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Directory /opt/siterm/config/ansible DOES NOT exists."
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Cloning git repo and add default ansible config."
  cloneAnsibleRepo
else
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Directory /opt/siterm/config/ansible exists."
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` Updating git repo to the latest version."
  cd /opt/siterm/config/ansible/sense
  # A previous run may have been killed mid-git-operation (OOM, pod
  # eviction, etc.), leaving a stale index.lock that would make every git
  # command below fail immediately with "Unable to create ... index.lock".
  rm -f .git/index.lock

  if ! { git fetch --all \
         && { git checkout "${ANSIBLE_REPO#origin/}" || git checkout -b "${ANSIBLE_REPO#origin/}" "$ANSIBLE_REPO"; } \
         && git reset --hard "$ANSIBLE_REPO" \
         && git pull "$REMOTE" "${ANSIBLE_REPO#origin/}"; }; then
    echo "`date -u +"%Y-%m-%d %H:%M:%S"` Git repo update failed -- local checkout is likely corrupted. Re-cloning from scratch."
    cd /
    rm -rf /opt/siterm/config/ansible/sense
    cloneAnsibleRepo
  fi
fi

# Generate JWT keys if they do not exist
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Generating JWT keys."
python3 /root/generate_jwt.py

# Run ansible prepare and prepare all ansible configuration files.
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Preparing Ansible configuration files."
if ! python3 /root/ansible-prepare.py; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` FATAL: Ansible configuration invalid. See errors above."
  exit 1
fi

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
