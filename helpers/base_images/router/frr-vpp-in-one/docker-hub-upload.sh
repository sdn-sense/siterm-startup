#!/bin/bash
set -x
TAG=dev
if [ $# -eq 1 ]
  then
    echo "Argument specified. Will use $1 to tag docker image"
    TAG=$1
fi

# Precheck that image is present (built recently
count=`docker images | grep vppfrr | grep latest | awk '{print $3}' | wc -l`
if [ "$count" -ne "1" ]; then
  echo "Count of docker images != 1. Which docker image you want to tag?"
  echo "Here is full list of docker images locally:"
  docker images | grep -i 'vppfrr\|REPOSITORY'
  echo "Please enter IMAGE ID:"
  read dockerimageid
else
  dockerimageid=`docker images | grep vppfrr | grep latest | awk '{print $3}'`
fi

docker login

docker tag $dockerimageid sdnsense/vppfrr:$TAG-$today
docker push sdnsense/vppfrr:$TAG-$today
docker tag $dockerimageid sdnsense/vppfrr:$TAG
docker push sdnsense/vppfrr:$TAG

