#!/bin/bash

# Check if upgrade is in progress and loop until it is completed
if [ -f /tmp/siterm-mariadb-init ]; then
  while [ -f /tmp/siterm-mariadb-init ]; do
    echo "Upgrade in progress. Waiting for it to complete."
    sleep 5
  done
fi
if [ ! -f /tmp/config-fetcher-ready ]; then
  while [ ! -f /tmp/config-fetcher-ready ]; do
    echo "Config fetch not finished yet. Waiting for it to start."
    sleep 1
  done
fi

set -a
source /etc/environment
set +a

# Set defaults for HTTPS_API and HTTPS_WEB
LISTEN_HTTPS_API=${LISTEN_HTTPS_API:-443}
LISTEN_HTTPS_WEB=${LISTEN_HTTPS_WEB:-1443}

# Identify any missing variables.
REQUIRED_VARS=(
  LISTEN_HTTPS_API_SERVER
  LISTEN_HTTPS_WEB_SERVER
  OIDCPROVIDER
  OIDCCLIENTID
  OIDCCLIENTSECRET
  OIDCREDIRECTURI
  OIDCCRYPTOPASS
)

MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
  if [[ -z "${!var:-}" ]]; then
    MISSING_VARS+=("$var")
  fi
done

if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
  echo "Error: Missing required environment variables:"
  for var in "${MISSING_VARS[@]}"; do
    echo "  - $var"
  done
  exit 1
fi
# Generate apache config from template
envsubst < /etc/httpd/sitefe-httpd.template > /etc/httpd/conf.d/sitefe-httpd.conf
# Lets run it!
exec /usr/sbin/httpd -k start -DFOREGROUND
