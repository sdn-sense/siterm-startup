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


for id in `docker ps -a | grep sdnsense/site-agent-sense | awk '{print $1}'`;
do
  docker stop $id;
  docker rm $id;
done

for id in `docker image ls | grep sdnsense/site-agent-sense | awk '{print $3}'`;
do
  docker image rm $id --force
done

./run.sh $VERSION
