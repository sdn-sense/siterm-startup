#!/bin/bash
# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
    echo "  -i imagetag (Optional). Default latest"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    echo "  -n networkmode (OPTIONAL). Default port mode"
    echo "     specify network mode. One of: host,port."
    echo "     host means it will use --net host for docker startup. Please make sure to open port 80, 443 in firewall. Use this option only if any of your hosts, network devices are IPv6 only (no IPv4 address)."
    echo "     port means it will use -p 8080:80 -p 8443:<l port> in docker startup. Docker will open port on system firewall. Default parameter"
    echo "  -p Overwrite default ports for docker. Default is 8080:80 and 8443:443. Specify in quotes, like -p \"10080:80 10443:443\""
    echo "  -u (Optional) Unique volume for docker mysql database (any string)/docker container name. If specified, will use it for docker volume creation and container name"
    exit 1
fi

DOCKVOL="siterm-mysql"
DOCKERNAME="site-fe-sense"
DOCKERNET=""
UFLAG=""
VERSION="latest"
NETMODE="port"

while getopts i:n:l:p:u: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
    n) NETMODE=${OPTARG}
       if [ "x$NETMODE" != "xhost" ] && [ "x$NETMODE" != "xport" ]; then
         echo "Parameter -n $NETMODE is not one of: host,port."
         exit 1
       fi;;
    p) PORTS=${OPTARG}
       if [ "x$NETMODE" = "xhost" ]; then
         echo "Mistmatch. Cant use -p with -n host"
         exit 1
       fi
       DOCKERNET=$PORTS;;
    u) DOCKVOL="siterm-mysql-${OPTARG}"
       DOCKERNAME="site-fe-sense-${OPTARG}"
       UFLAG=${OPTARG};;
  esac
done

# Set default ports if not specified;
if [ "x$NETMODE" = "xport" ]; then
  if [ -z "$DOCKERNET" ]; then
    DOCKERNET="9443:1443 8443:443"
  fi
fi

# Validate that all required parameters are set
if [ -z "$VERSION" ]; then
  echo "Error: Missing required parameter of -i version of image to use."
  exit 1
fi

echo "================================================"
echo "Finding and stopping existing docker containers for ${DOCKERNAME}"
for id in `docker ps -a | grep ${DOCKERNAME} | awk '{print $1}'`
do
  docker stop $id
  docker rm $id
done
echo "================================================"
echo "Finding and removing existing docker images for sdnsense/site-rm-sense"
for id in `docker image ls | grep sdnsense/site-rm-sense | awk '{print $3}'`
do
  docker image rm $id --force
done
echo "================================================"
./run.sh -i $VERSION -n $NETMODE -p "$DOCKERNET" -u $UFLAG
