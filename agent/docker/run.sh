#!/bin/bash

# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
    echo "  -i imagetag (MANDATORY)"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    exit 1
fi

while getopts i: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
  esac
done

# Do not use json-file logging if it is podman
ISPODMAN=`docker --version | grep podman | wc -l`
LOGOPTIONS=""
if [ $ISPODMAN -eq 0 ]; then
  LOGOPTIONS="--log-driver=json-file --log-opt max-size=10m --log-opt max-file=10"
fi

# If lldpd daemon running on the host, we pass socket to container.
# SiteRM Agent will try to get lldpd information (lldpcli show neighbors)
# So that it can know automatically how things are connected.
# lldp must be enabled at the site level (host and network)
LLDPMOUNT=""
if `test -S /run/lldpd/lldpd.socket`; then
  LLDPMOUNT="-v /run/lldpd/lldpd.socket:/run/lldpd/lldpd.socket:ro"
fi

docker run \
  -dit --name siteagent \
  -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml:ro \
  -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem:ro \
  -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem:ro \
  -v $(pwd)/../conf/opt/siterm/config/:/opt/siterm/config/ \
  -v /etc/iproute2/rt_tables:/etc/iproute2/rt_tables:ro $LLDPMOUNT \
  --cap-add=NET_ADMIN \
  --net=host \
  $LOGOPTIONS docker.io/sdnsense/site-agent-sense:$VERSION
# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
