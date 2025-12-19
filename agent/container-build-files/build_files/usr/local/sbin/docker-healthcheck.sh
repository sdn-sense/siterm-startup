#!/bin/bash

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

