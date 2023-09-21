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


for id in `docker ps -a | grep sdnsense/site-agent-sense | awk '{print $1}'`;
do
  docker stop $id;
  docker rm $id;
done

for id in `docker image ls | grep sdnsense/site-agent-sense | awk '{print $3}'`;
do
  docker image rm $id --force
done

./run.sh -i $VERSION
