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

# Set defaults for HTTPS
LISTEN_HTTPS=${LISTEN_HTTPS:-443}

# AUTH_SUPPORT should be one of: X509, OIDC, BOTH. Default X509
case "$AUTH_SUPPORT" in
  X509)
    TEMPLATE_FILE="/etc/httpd/sitefe-httpd-x509.conf-template"
    ;;
  OIDC)
    TEMPLATE_FILE="/etc/httpd/sitefe-httpd-oidc.conf-template"
    ;;
  BOTH)
    TEMPLATE_FILE="/etc/httpd/sitefe-httpd-x509-oidc.conf-template"
    ;;
  *)
    TEMPLATE_FILE="/etc/httpd/sitefe-httpd-x509.conf-template"
    ;;
esac

if [[ "$AUTH_SUPPORT" == "OIDC" || "$AUTH_SUPPORT" == "BOTH" ]]; then
  REQUIRED_VARS=(
    OIDC_PROVIDER
    OIDC_CLIENT_ID
    OIDC_CLIENT_SECRET
    OIDC_REDIRECT_URI
    OIDC_CRYPTO_PASS
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
fi


# Generate apache config from template
envsubst < "$TEMPLATE_FILE" > /etc/httpd/conf.d/sitefe-httpd.conf

# Lets run it!
exec /usr/sbin/httpd -k start -DFOREGROUND
