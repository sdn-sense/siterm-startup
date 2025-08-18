#!/bin/bash
if [ -x /usr/sbin/crond ]; then
    # RHEL Runtime
    exec /usr/sbin/crond -n
elif [ -x /usr/sbin/cron ]; then
    # Ubuntu Runtime
    exec /usr/sbin/cron -f
else
    echo "Error: neither /usr/sbin/crond nor /usr/sbin/cron found!" >&2
    exit 1
fi
