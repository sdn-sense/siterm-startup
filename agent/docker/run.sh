#!/bin/bash

# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

VERSION=latest
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 version from docker hub"
    VERSION=$1
fi

# If lldpd daemon running on the host, we pass socket to container.
# SiteRM Agent will try to get lldpd information (lldpcli show neighbors)
# So that it can know automatically how things are connected.
# lldp must be enabled at the site level (host and network)
if `test -S /run/lldpd/lldpd.socket`; then
  docker run \
       -dit --name siteagent \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml:ro \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem:ro \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem:ro \
       -v $(pwd)/../conf/opt/siterm/config/:/opt/siterm/config/ \
       -v /etc/iproute2/rt_tables:/etc/iproute2/rt_tables:ro \
       -v /run/lldpd/lldpd.socket:/run/lldpd/lldpd.socket:ro \
       --cap-add=NET_ADMIN \
       --net=host \
       --log-driver="json-file" --log-opt max-size=10m --log-opt max-file=10 \
       docker.io/sdnsense/site-agent-sense:$VERSION
else
  docker run \
       -dit --name siteagent \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml:ro \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem:ro \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem:ro \
       -v $(pwd)/../conf/opt/siterm/config/:/opt/siterm/config/ \
       -v /etc/iproute2/rt_tables:/etc/iproute2/rt_tables:ro \
       --cap-add=NET_ADMIN \
       --net=host \
       --log-driver="json-file" --log-opt max-size=10m --log-opt max-file=10 \
       docker.io/sdnsense/site-agent-sense:$VERSION
fi
# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
