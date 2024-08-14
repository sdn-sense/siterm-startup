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
    echo "     port means it will use -p 8080:80 -p 8443:<l port> in docker startup. Docker will open port on system firewall. Default parameter"
    echo "  -l Instruct httpd to listen on a specific port. Default inside docker is 443. (Mainly for docker + nftables mode (no iptables) - where it is mandatory to use -n host)"
    exit 1
fi

while getopts i:n:l: flag
do
  case "${flag}" in
    i) VERSION=${OPTARG};;
    l) LISTEN_HTTPS=${OPTARG};;
    n) NETMODE=${OPTARG}
       if [ "x$NETMODE" != "xhost" ] && [ "x$NETMODE" != "xport" ]; then
         echo "Parameter -n $NETMODE is not one of: host,port."
         exit 1
       fi;;
  esac
done

for id in `docker ps -a | grep sdnsense/site-rm-sense | awk '{print $1}'`
do
  docker stop $id
  docker rm $id
done

for id in `docker image ls | grep sdnsense/site-rm-sense | awk '{print $3}'`
do
  docker image rm $id --force
done
./run.sh -i $VERSION -n $NETMODE -l $LISTEN_HTTPS
