#!/bin/bash
# Container entrypoint.
# SITERM_COMPONENT selects what this container runs:
#   all (default)  - every service, MariaDB included (single container deployment)
#   dbinit         - create/upgrade the database schema once, then exit
#   frontend, configfetcher, lookup, policy, provisioning, switchmanager,
#   snmpmon, bgpmon, validator, dbworker, debugger - one component per container
# Components talk to each other only through the database (MARIA_DB_* in /etc/environment).
set -e

COMPONENT="${SITERM_COMPONENT:-all}"
log () {
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` $1"
}

if [[ "$COMPONENT" == "dbinit" ]]; then
  exec /usr/local/sbin/dbinit.sh
fi

log "Validating /etc/ansible-conf.yaml before starting services."
# Split components read the site configuration ConfigFetcher publishes to the database; on a first start
# it may not be there yet, so retry for up to 10 minutes before failing.
ATTEMPTS=1
if [[ "$COMPONENT" != "all" && "$COMPONENT" != "configfetcher" ]]; then
  ATTEMPTS=40
fi
for attempt in $(seq 1 $ATTEMPTS); do
  if python3 /root/ansible-prepare.py --check; then
    break
  fi
  if [[ $attempt -eq $ATTEMPTS ]]; then
    log "FATAL: /etc/ansible-conf.yaml failed validation (see errors above)."
    log "SiteRM will not start any services until this is fixed."
    exit 1
  fi
  log "Validation failed (attempt $attempt/$ATTEMPTS). Retrying in 15 seconds."
  sleep 15
done

# supervisord programs (conf file names without .conf) per component; cleanup and cert renew run everywhere.
case "$COMPONENT" in
  all)           KEEP="" ;;
  frontend)      KEEP="12-httpd 12-gunicorn-app 12-apache-exporter" ;;
  configfetcher) KEEP="11-config-fetcher" ;;
  lookup)        KEEP="13-lookup-service" ;;
  policy)        KEEP="14-policy-service" ;;
  provisioning)  KEEP="14-provisioning-service" ;;
  switchmanager) KEEP="13-switch-manager" ;;
  snmpmon)       KEEP="15-snmpmon-service" ;;
  bgpmon)        KEEP="18-bgpmon-service" ;;
  validator)     KEEP="17-validator-service" ;;
  dbworker)      KEEP="10-dbworker 16-dbcleaner" ;;
  debugger)      KEEP="12-siterm-debugger" ;;
  *)
    log "FATAL: unknown SITERM_COMPONENT=$COMPONENT"
    exit 1
    ;;
esac

if [[ "$COMPONENT" != "all" ]]; then
  KEEP="00-cleanup 01-certrenew $KEEP"
  mkdir -p /etc/supervisord.disabled
  for conf in /etc/supervisord.d/*.conf; do
    name=$(basename "$conf" .conf)
    if [[ " $KEEP " != *" $name "* ]]; then
      mv -f "$conf" /etc/supervisord.disabled/
    fi
  done
  log "Component $COMPONENT. Enabled programs: $KEEP"
fi

exec /usr/local/bin/supervisord -c /etc/supervisord.conf
