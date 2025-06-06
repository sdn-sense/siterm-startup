#!/bin/bash

TAG=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    TAG=$1
fi

# Precheck that image is present (built recently
count=`docker images | grep sitermagentbasebuild | grep latest | awk '{print $3}' | wc -l`
if [ "$count" -ne "1" ]; then
  echo "Count of docker images != 1. Which docker image you want to tag?"
  echo "Here is full list of docker images locally:"
  docker images | grep -i 'sitermagentbasebuild\|REPOSITORY'
  echo "Please enter IMAGE ID:"
  read dockerimageid
else
  dockerimageid=`docker images | grep sitermagentbasebuild | grep latest | awk '{print $3}'`
fi

docker login

ARCH=`arch`
today=`date +%Y%m%d`
if [ $ARCH = "x86_64" ]; then
  docker tag $dockerimageid sdnsense/sitermagentbase:$TAG-$today
  docker push sdnsense/sitermagentbase:$TAG-$today
  docker tag $dockerimageid sdnsense/sitermagentbase:$TAG
  docker push sdnsense/sitermagentbase:$TAG
fi
