#!/bin/bash

echo "Running siterm-liveness check"
siterm-liveness
if [ $? -ne 0 ]; then
  echo "siterm-liveness check failed"
  exit 1
fi
echo "Running siterm-readiness check"
siterm-readiness
if [ $? -ne 0 ]; then
  echo "siterm-readiness check failed"
  exit 1
fi
echo "All checks passed"
exit 0

