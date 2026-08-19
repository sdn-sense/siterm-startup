#!/bin/bash
# Container entrypoint. Validates /etc/ansible-conf.yaml before starting supervisord
set -e

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Validating /etc/ansible-conf.yaml before starting services."
if ! python3 /root/ansible-prepare.py --check; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` FATAL: /etc/ansible-conf.yaml failed validation (see errors above)."
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` SiteRM will not start any services until this is fixed."
  exit 1
fi

exec /usr/local/bin/supervisord -c /etc/supervisord.conf
