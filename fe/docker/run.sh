#!/bin/bash
# VERSION:
#  dev - development branch, often updated, might not be working version
#  latest - stable working version

# Check if parameters are defined. If not, print usage and exit 1.
if [ $# == 0 ]; then
    echo "Usage: `basename $0` [-i imagetag] [-n networkmode]"
    echo "  -i imagetag (MANDATORY)"
    echo "     specify image tag, e.g. latest, dev, v1.3.0... For production deplyoment use latest, unless instructed otherwise by SENSE team"
    echo "  -n networkmode (OPTIONAL). Default port mode"
    echo "     specify network mode. One of: host,port."
    echo "     host means it will use --net host for docker startup. Please make sure to open port 80, 443 in firewall. Use this option only if any of your hosts, network devices are IPv6 only (no IPv4 address)."
    echo "     port means it will use -p 8080:80 -p 8443:443 in docker startup. Docker will open port on system firewall. Default parameter"
    exit 1
fi

DOCKERNET="-p 8080:80 -p 8443:443"
while getopts i:n: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
    n) NETMODE=${OPTARG}
       if [ "x$NETMODE" != "xhost" ] && [ "x$NETMODE" != "xport" ]; then
         echo "Parameter -n $NETMODE is not one of: host,port."
         exit 1
       elif [ "x$NETMODE" == "host" ]; then
         DOCKERNET="--net host"
       else
         DOCKERNET="-p 8080:80 -p 8443:443"
       fi;;
  esac
done

# Do not use json-file logging if it is podman
ISPODMAN=`docker --version | grep podman | wc -l`
LOGOPTIONS=""
if [ $ISPODMAN -eq 0 ]; then
  LOGOPTIONS="--log-driver=json-file --log-opt max-size=10m --log-opt max-file=10"
fi

docker run \
       -dit --name site-fe-sense \
       -v $(pwd)/../conf/etc/siterm.yaml:/etc/siterm.yaml \
       -v $(pwd)/../conf/etc/ansible-conf.yaml:/etc/ansible-conf.yaml \
       -v $(pwd)/../conf/etc/httpd/certs/cert.pem:/etc/httpd/certs/cert.pem \
       -v $(pwd)/../conf/etc/httpd/certs/privkey.pem:/etc/httpd/certs/privkey.pem \
       -v $(pwd)/../conf/etc/httpd/certs/fullchain.pem:/etc/httpd/certs/fullchain.pem \
       -v $(pwd)/../conf/etc/grid-security/hostcert.pem:/etc/grid-security/hostcert.pem \
       -v $(pwd)/../conf/etc/grid-security/hostkey.pem:/etc/grid-security/hostkey.pem \
       -v $(pwd)/../conf/opt/siterm/config/mysql/:/opt/siterm/config/mysql/ \
       -v $(pwd)/../conf/opt/siterm/config/ssh-keys:/opt/siterm/config/ssh-keys \
       $DOCKERNET \
       --env-file $(pwd)/../conf/environment \
       $LOGOPTIONS docker.io/sdnsense/site-rm-sense:$VERSION

# For development, add -v /home/jbalcas/siterm/:/opt/siterm/sitermcode/siterm/ \
