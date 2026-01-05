#!/bin/bash

TEMP_DIR=$(python3 -c "from SiteRMLibs.MainUtilities import getTempDir; print(getTempDir())")
# If upgrade is in progress, exit 0
if [ -f $TEMP_DIR/siterm-mariadb-init ]; then
  exit 0
fi

if [ ! -f $TEMP_DIR/config-fetcher-ready ]; then
  exit 0
fi

echo "`date -u +"%Y-%m-%d %H:%M:%S"` Running siterm-liveness check"
siterm-liveness
if [ $? -ne 0 ]; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` siterm-liveness check failed"
  exit 1
fi
echo "`date -u +"%Y-%m-%d %H:%M:%S"` Running siterm-readiness check"
siterm-readiness
if [ $? -ne 0 ]; then
  echo "`date -u +"%Y-%m-%d %H:%M:%S"` siterm-readiness check failed"
  exit 1
fi
echo "`date -u +"%Y-%m-%d %H:%M:%S"` All checks passed"
exit 0

